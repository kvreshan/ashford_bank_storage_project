#!/bin/bash
###############################################################################
# Ashford National Bank --- Idempotent Storage & Access Provisioning Script
# Safe to re-run: every step checks current state before making changes.
#
# INDUSTRY-STANDARD REVISION:
# This script now runs entirely as root (sudo bash provision_bank_storage.sh).
# Per-command "sudo" prefixes have been removed --- redundant once the whole
# script is already root, and previously caused a permission failure writing
# to /var/log (a root-owned path) when the script itself was launched as a
# plain user. Single privilege boundary = clearer auditing, no partial-
# privilege confusion, and /var/log is where centralized log tools
# (logrotate, journald, ELK/Splunk agents) expect to find it.
###############################################################################
set -uo pipefail   # NOTE: no 'set -e' --- errors are handled explicitly so one
                    # already-done step never aborts the rest of the script.

# ---- Root check (safety net) ----
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use: sudo bash $0)" >&2
    exit 1
fi

LOGFILE="/var/log/bank_provision.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=============================================="
echo "Provisioning run started: $(date)"
echo "=============================================="

# ---------- Config ----------
LOANS_DISK="/dev/sdb"
TELLERS_DISK="/dev/sdc"
VG_NAME="bankvg"
LOANS_LV="loans_lv"
TELLERS_LV="tellers_lv"
LOANS_SIZE="10G"
LOANS_MOUNT="/data/loans"
TELLERS_MOUNT="/data/tellers"
LOANS_GROUP="loans_group"
TELLERS_GROUP="tellers_group"
LOANS_USER="david.okafor"
TELLERS_USER="susan.patel"
PASS_MAX_DAYS=30
###############################################################################
echo ""
echo "--- Step 1: Physical Volumes ---"
for disk in "$LOANS_DISK" "$TELLERS_DISK"; do
    if pvs "$disk" > /dev/null 2>&1; then
        echo "PV $disk already exists, skipping."
    else
        pvcreate "$disk" && echo "Created PV $disk"
    fi
done
###############################################################################
echo ""
echo "--- Step 2: Volume Group ---"
if vgs "$VG_NAME" > /dev/null 2>&1; then
    echo "VG $VG_NAME already exists, skipping."
else
    vgcreate "$VG_NAME" "$LOANS_DISK" "$TELLERS_DISK" && echo "Created VG $VG_NAME"
fi
###############################################################################
echo ""
echo "--- Step 3: Logical Volumes ---"
if lvs "$VG_NAME/$LOANS_LV" > /dev/null 2>&1; then
    echo "LV $LOANS_LV already exists, skipping."
else
    lvcreate -n "$LOANS_LV" -L "$LOANS_SIZE" "$VG_NAME" && echo "Created LV $LOANS_LV"
fi

if lvs "$VG_NAME/$TELLERS_LV" > /dev/null 2>&1; then
    echo "LV $TELLERS_LV already exists, skipping."
else
    lvcreate -n "$TELLERS_LV" -l 100%FREE "$VG_NAME" && echo "Created LV $TELLERS_LV"
fi
###############################################################################
echo ""
echo "--- Step 4: Filesystems ---"
for lv in "$LOANS_LV" "$TELLERS_LV"; do
    DEV="/dev/$VG_NAME/$lv"
    if blkid "$DEV" | grep -q 'TYPE="xfs"'; then
        echo "$DEV already formatted as XFS, skipping."
    else
        mkfs.xfs "$DEV" && echo "Formatted $DEV as XFS"
    fi
done
###############################################################################
echo ""
echo "--- Step 5: Mount Points ---"
for dir in "$LOANS_MOUNT" "$TELLERS_MOUNT"; do
    if [ -d "$dir" ]; then
        echo "$dir already exists, skipping."
    else
        mkdir -p "$dir" && echo "Created $dir"
    fi
done
###############################################################################
echo ""
echo "--- Step 6: fstab entries ---"
LOANS_UUID=$(blkid -s UUID -o value "/dev/$VG_NAME/$LOANS_LV")
TELLERS_UUID=$(blkid -s UUID -o value "/dev/$VG_NAME/$TELLERS_LV")

if grep -q "$LOANS_UUID" /etc/fstab; then
    echo "fstab entry for loans already present, skipping."
else
    echo "UUID=$LOANS_UUID $LOANS_MOUNT xfs defaults 0 2" | tee -a /etc/fstab > /dev/null
    echo "Added fstab entry for loans."
fi

if grep -q "$TELLERS_UUID" /etc/fstab; then
    echo "fstab entry for tellers already present, skipping."
else
    echo "UUID=$TELLERS_UUID $TELLERS_MOUNT xfs defaults 0 2" | tee -a /etc/fstab > /dev/null
    echo "Added fstab entry for tellers."
fi

echo "Applying fstab (mount -a)..."
mount -a && echo "mount -a completed successfully."
###############################################################################
echo ""
echo "--- Step 7: Department Groups ---"
for grp in "$LOANS_GROUP" "$TELLERS_GROUP"; do
    if getent group "$grp" > /dev/null 2>&1; then
        echo "Group $grp already exists, skipping."
    else
        groupadd "$grp" && echo "Created group $grp"
    fi
done
###############################################################################
echo ""
echo "--- Step 8: User Accounts ---"
if id "$LOANS_USER" > /dev/null 2>&1; then
    echo "User $LOANS_USER already exists, skipping."
else
    useradd -m -g "$LOANS_GROUP" -s /bin/bash "$LOANS_USER" && echo "Created user $LOANS_USER"
fi

if id "$TELLERS_USER" > /dev/null 2>&1; then
    echo "User $TELLERS_USER already exists, skipping."
else
    useradd -m -g "$TELLERS_GROUP" -s /bin/bash "$TELLERS_USER" && echo "Created user $TELLERS_USER"
fi
###############################################################################
echo ""
echo "--- Step 9: Ownership & Permissions (safe to always re-apply) ---"
chown root:"$LOANS_GROUP" "$LOANS_MOUNT"
chmod 2770 "$LOANS_MOUNT"
echo "Applied ownership + 2770 to $LOANS_MOUNT"

chown root:"$TELLERS_GROUP" "$TELLERS_MOUNT"
chmod 2770 "$TELLERS_MOUNT"
echo "Applied ownership + 2770 to $TELLERS_MOUNT"
###############################################################################
echo ""
echo "--- Step 10: Password Aging Policy (safe to always re-apply) ---"
chage -M "$PASS_MAX_DAYS" "$LOANS_USER"
chage -d 0 "$LOANS_USER"
echo "Applied password policy to $LOANS_USER"

chage -M "$PASS_MAX_DAYS" "$TELLERS_USER"
chage -d 0 "$TELLERS_USER"
echo "Applied password policy to $TELLERS_USER"
###############################################################################
echo ""
echo "=============================================="
echo "Provisioning run completed: $(date)"
echo "=============================================="
