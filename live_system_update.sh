#!/bin/bash

# LIVE UPDATE
# If the Candle controller uses the new overlay system, then this script might be able to update it "live", without needing a reboot or fully disabling the overlay.

echo
echo "CANDLE LIVE UPDATE"

# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (use sudo)"
  exit
else
  echo "running as user $(whoami)"
fi

if [ ! -d /ro ]; then
    echo
    echo "no overlay detected, aborting."
    exit 1
fi
    

cd /ro/home/pi || exit


echo
echo "Starting live controller upate"
echo "starting LIVE controller update" >> /dev/kmsg
echo



# make sure there is a current time
if [ -f /boot/candle_hardware_clock.txt ]; 
then
    echo "Trying to get time update from NTP server"
    rm /boot/candle_hardware_clock.txt
    systemctl restart systemd-timesyncd.service
    timedatectl set-ntp true
    sleep 2
    /usr/sbin/fake-hwclock save
    echo "Candle: requested latest time from internet. Date is now: $(date)" >> /dev/kmsg
else
    echo "no hardware clock detected, assuming time is current"
fi



echo "Setting /ro to RW"

# This shouldn't even be possible really 

mount -o remount,rw /ro
echo "remount done"

#echo "juggling /etc/resolv.conf"
#cp /etc/resolve.conf /ro/etc/resolve.conf.jump
#rm /rw/upper/etc/resolve.conf
#rm /etc/resolve.conf
#cp /ro/etc/resolve.conf.jump /ro/etc/resolve.conf


if [ -d /ro/home/pi/webthings ]; then
    echo "calculating free space"
    availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
    echo "calculating size of webthings folder"
    fileSize=$(du -k --max-depth=0 "/ro/home/pi/webthings" | awk '{print $1}')

    if [ "$fileSize" -gt "$availMem" ]; 
    then
        echo "WARNING: NOT ENOUGH DISK SPACE TO CREATE WEBTHINGS BACKUP. SKIPPING."
        echo "Candle: WARNING: LOW DISK SPACE, NOT CREATING BACKUP FIRST" >> /dev/kmsg
    else
        echo "Creating fresh backup tar of webthings folder"
        echo "Candle: creating fresh backup copy" >> /dev/kmsg
        # cp -r /ro/home/pi/webthings /ro/home/pi/webthings-old
        tar -czf /ro/home/pi//controller_backup_fresh.tar /ro/home/pi/webthings
        chown pi:pi /ro/home/pi//controller_backup_fresh.tar
    fi
else
    echo "ERROR: /ro/home/pi/webthings does not exist??"
fi

mkdir -p /ro/home/pi/tmp/boot
cp -r --verbose /boot/* /ro/home/pi/tmp/boot

mkdir -p /ro/home/pi/tmp/root
cp -r --verbose /root/* /ro/home/pi/tmp/root

cp -r --verbose /proc/device-tree /ro/home/pi/tmp/proc/device-tree
cp -r --verbose /proc/mounts /ro/home/pi/tmp/proc/mounts


mkdir -p /ro/home/pi/tmp/etc
cp -r --verbose /ro/home/pi/.webthings/etc/hostname /ro/home/pi/tmp/etc/hostname
cp -r --verbose /ro/home/pi/.webthings/etc/hosts /ro/home/pi/tmp/etc/hosts

echo "Downloading latest install script from Github" 

wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh -O /ro/home/pi/create_candle_disk_image.sh
if [ -f /ro/home/pi/create_candle_disk_image.sh ]; then
    echo "Download succesful"
    chmod +x /ro/home/pi/create_candle_disk_image.sh
else
    echo "ERROR: DOWNLOADING LATEST SCRIPT FAILED"
    exit 1
fi


# sudo chroot /ro sh -c "ls /dev"
# sudo chroot /ro sh -c "ls /mnt"
# sudo chroot /ro sh -c "apt update"
# sudo chroot /ro sh -c "cat /proc/mounts"
# sudo chroot /ro sh -c "wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh"
# sudo chroot /ro sh -c "ls /home/pi/alfred"

# sudo chroot /ro sh -c "mount -t procfs && ls /proc"

#sudo chroot /ro ln -s /proc/mounts /etc/mtab

# mount -o bind /dir/outside/chroot /dir/inside/chroot
echo "starting chroot"
echo "Candle: starting chroot" >> /dev/kmsg

chroot /ro sh -c "$(cat <<END
echo "in chroot"
export CHROOTED=yes
echo "/etc/resolv.conf: $(cat /etc/resolv.conf)"
echo "cat /mnt/etc/resolv.conf: $(cat /mnt/etc/resolv.conf)"
cd /home/pi
export STOP_EARLY=yes
if [ -d /home/pi/tmp/boot ]; then
echo "creating bind mount over /boot"
mount --bind /home/pi/tmp/boot /boot
else
echo "/home/pi/tmp/boot was missing"
fi
mount -t procfs
mount -t sysfs
if [ -f /home/pi/create_candle_disk_image.sh ]; then
echo "Install script found, starting it"
/home/pi/create_candle_disk_image.sh > /home/pi/update_report.txt
else
echo "Error in chroot: create_candle_disk_image.sh not found"
fi
touch /home/pi/TEST_FILE.txt
END
)"


echo "Finalising outside of chroot"
echo "Candle: Finalising update outside of chroot" >> /dev/kmsg

sleep 5

echo "setting fkms driver"
sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/' /boot/config.txt


# delete the temporary directory
rm -rf /ro/home/pi/tmp


if [ -f /ro/home/pi/create_candle_disk_image.sh ]; then
    rm /ro/home/pi/create_candle_disk_image.sh
else
    echo "strange, the install script is gone"
fi


if [ -d /ro/home/pi/configuration-files ]; then
    echo "removing /ro/home/pi/configuration-files"
else
    echo "/ro/home/pi/configuration-files did not exist, so is not being deleted"
    git clone --depth 1 https://github.com/createcandle/configuration-files /ro/home/pi/configuration-files
fi


if [ -d /home/pi/configuration-files/boot ]; then
    cp --verbose -r /ro/home/pi/configuration-files/boot/* /boot/
    rm -rf /ro/home/pi/configuration-files
else
    echo "ERROR: configuration files not downloaded?"
    echo "Candle: ERROR: could not update files in /boot" >> /dev/kmsg
fi



# re-enable read-only mode
echo "Setting /ro back to RO"
mount -l -o remount,ro /ro

echo "LIVE controller update done" >> /dev/kmsg


exit 0

