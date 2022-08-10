#!/bin/bash

# This script can do a system update without needing to reboot first. 
# It's vital to reboot afterwards though.

# Disable read-only mode for the underlay
echo "setting to RW"
mount -o remount,rw /ro

# Trick apt to see /ro as /
chroot /ro sh -c "$(cat <<END
# Get apt to do a system update
echo "Starting live system update"
ls /
apt update
apt upgrade -y
apt clean
END
)"

# re-enable read-only mode
echo "setting back to RO"
mount -o remount,ro /ro
