# Ashford National Bank Linux Storage and Access Project

Note: This is a hands-on technical portfolio project based on a simulated enterprise scenario ("Ashford Bank"). The requirements and business constraints were designed using AI to mirror real-world financial industry storage challenges.

## About this project

This project is a full Linux server build for a fictional bank branch client called Ashford National Bank. The brief came from a branch IT officer who described a real problem: 25 staff members split between a Loans team and a Tellers team were storing files on whatever drive space was available, with no growth plan, no access control, and no automation.

I designed and built the full solution from scratch on a Linux virtual machine, covering scalable storage, department level access control, remote administration, and a single script that can rebuild the whole setup safely at any time. Every step below was actually performed and verified on a live virtual machine, not just written up as theory.

This repository is my way of proving that this project was really completed, with real screenshots, real commands, and real mistakes that came up along the way and were fixed. Nothing has been cleaned up to hide the learning process. If you are reviewing this for an internship or job application, the troubleshooting sections are honestly the most useful parts to read.

## What the client asked for

The branch IT officer's message asked for the following:

1. Secure, separate storage for the Loans team and the Tellers team, with nobody able to browse into a team's storage from outside that team
2. Storage that can grow later, especially for Loans, without taking anything offline during business hours
3. Individual accounts for the two team leads, David Okafor (Loans) and Susan Patel (Tellers)
4. Passwords that are forced to change on first login and expire automatically every 30 days
5. A script or set of scripts that can safely be run again later to rebuild the setup, without breaking anything if run twice by accident
6. Full documentation of what was done and why, along with proof that it actually works, so the setup can be handed off to whoever manages IT next

## What I actually built

* A Linux Logical Volume Manager (LVM) storage layout, using two virtual disks pooled into one Volume Group, with a separate Logical Volume for each department
* The XFS filesystem, chosen specifically because it can be grown live while still mounted and in use, with zero downtime
* Persistent mounts configured through UUID based entries in /etc/fstab, tested with a real reboot rather than just a dry run
* Two Linux groups (loans_group and tellers_group) and two named user accounts, each restricted to their own department folder using ownership, the 2770 permission mode, and the SGID bit
* A 30 day password expiry policy with a forced password change on first login, applied using chage
* Working remote SSH access from a Windows management machine into the virtual machine, including diagnosing a service that silently failed to start
* A single idempotent bash script, provision_bank_storage.sh, that checks the current state of the system before making any change, so it is always safe to run again
* A live proof that storage really can grow without downtime: a new virtual disk was added, absorbed into the storage pool, and used to grow the Loans volume from 10GB to about 15GB while the folder stayed mounted and in use

## Folder structure

```
ashford_bank_storage_project/
  README.md
  scripts/
    provision_bank_storage.sh
  docs/
    01_initial_build_log.md
    02_lvm_storage_deployment.md
    03_users_groups_permissions.md
    04_ssh_access_and_idempotent_script.md
    05_hostname_fix_and_live_growth.md
    06_password_policy.md
    07_executive_handoff_summary.md
  screenshots/
    (numbered screenshots showing each stage of the build)
```

Each file inside docs explains one stage of the project in plain English, in the order the work actually happened. The screenshots folder holds real terminal and VirtualBox screenshots taken during the build, numbered so they match the order they are mentioned in the docs.

## The storage design, explained simply

Think of a Volume Group as a water tank, fed by one or more pipes coming in (the Physical Volumes, which are just raw disks). The Logical Volumes are the outgoing pipes, each carrying a chosen amount of that water to one house (one department). Because both departments draw from the same shared tank, free space can be redirected to whichever department needs it next, and a new pipe (a new disk) can be added to the tank at any time without rebuilding anything.

Two disks were combined into one Volume Group named bankvg. Loans was given 10GB and Tellers was given 5GB to start, based on the fact that Loans stores large scanned documents while Tellers stores smaller day to day transaction records. Later, a third disk was added and used to grow the Loans volume live, proving that the whole design actually works the way it was planned.

## Access control, explained simply

Each department folder belongs to its own Linux group, is set to permission mode 2770, and has the SGID bit switched on. In plain terms: the owning group can fully use the folder, nobody outside that group can even look inside it, and any new file created inside will automatically belong to the correct department group forever, not just today. Think of each department group as a separate key. The Loans key opens the Loans room. The Tellers key opens a completely different room. Neither key ever opens the other room.

This was not just assumed to work. A direct test was run where the Loans user tried to open the Tellers folder, and the Tellers user tried to open the Loans folder. Both attempts correctly failed with a permission denied error, which is proof the isolation genuinely works.

## Honest mistakes along the way

Real system administration involves typos and misconfigurations, and this project keeps them documented rather than hidden. A few examples covered in detail inside the docs folder:

* A logical volume name typed with a space instead of an underscore, which LVM correctly rejected
* A group name that was accidentally misspelled, which was caught using getent and corrected
* An SSH service that accepted network connections but silently failed to let anyone log in, traced back to Ubuntu's socket activation behaviour
* A script file that was saved with a shortened filename because a terminal window cut off the visible file name in the save prompt
* A log file permission error that led to redesigning the script to run entirely as root, matching how real provisioning tools such as Ansible and cloud init are normally run

Each of these is described in full in the relevant document inside the docs folder, together with the exact cause and the exact fix.

## How the script works

provision_bank_storage.sh automates every step covered in this project: physical volumes, the volume group, logical volumes, filesystems, mount points, fstab entries, department groups, user accounts, folder permissions, and the password aging policy. Every step checks whether something already exists before creating it, so running the script a second time simply reports "already exists, skipping" for everything that is already in place, instead of causing an error or duplicating anything.

To run it on a fresh Ubuntu server:

```
sudo bash provision_bank_storage.sh
```

The script must be run as root, since almost every action inside it (disk, LVM, user, and permission changes) requires root access anyway. It also keeps a full log of every run at /var/log/bank_provision.log.

## Tools and technologies used

Ubuntu Server, VirtualBox, LVM (pvcreate, vgcreate, lvcreate, lvextend), the XFS filesystem, bash scripting, Linux user and group management, SSH, and standard Linux permission and access control tools.

## Why I built this

I built this project to practice and demonstrate real Linux server administration skills: storage design that can grow safely, access control between departments, remote administration, and writing automation that is genuinely safe to reuse. I am sharing it publicly as part of my portfolio while I look for an internship in this area.
