# Executive Handoff Summary

Prepared by K.W.R. Dulakshana (KV), B.Tech in Network Technology, University of Vavuniya. July 2026.

## Purpose of this document

This is the final, single page style summary meant for whoever takes over managing this server next. It pulls together every requirement the client originally asked for, and states plainly where each one stands today.

## Client requirements and current status

1. Secure, separate storage for Loans and Tellers, with no cross team browsing. Status: complete and directly tested. Each department folder is owned by its own Linux group, set to permission mode 2770 with the SGID bit on, and a direct two way access test confirmed neither team can open the other's folder
2. Storage that can grow later without downtime. Status: complete and directly proven. A new disk was added live and used to grow the Loans volume from 10GB to roughly 15GB while the folder remained mounted and in use the entire time
3. Individual accounts for the two team leads, David Okafor (Loans) and Susan Patel (Tellers). Status: complete. Both accounts exist, each with its department group as its primary group
4. Forced password change on first login and automatic 30 day password expiry. Status: complete, applied to both accounts using chage
5. A safely reusable script that can rebuild the setup and will not break anything if run twice by accident. Status: complete and directly tested. provision_bank_storage.sh was run twice in a row both before and after a refactor to a cleaner, root only execution model, with identical, error free results both times
6. Full documentation with proof it works, ready for handoff. Status: this repository. Every stage of the build is documented in the docs folder with real screenshots and an honest record of every mistake made and how it was fixed

## What the next administrator needs to know

The server hostname is ashfordbank-server, corrected and consistent in both hostnamectl and /etc/hosts. Remote access is available over SSH using the loopback address and forwarded port 2222 from the management host. All storage lives under bankvg, with loans_lv mounted at /data/loans and tellers_lv mounted at /data/tellers, both persistent across reboots through UUID based /etc/fstab entries. To rebuild or reapply this entire configuration on a fresh server, run provision_bank_storage.sh as root. Every run is logged automatically at /var/log/bank_provision.log.

## Final note

Every requirement in the original brief has been met and, where possible, proven with a live test rather than left as an assumption. The honest troubleshooting record kept throughout this project is intentional: it shows the real process behind the finished result, not just the finished result on its own.
