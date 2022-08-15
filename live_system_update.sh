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
echo "Starting live controller update"
echo "starting LIVE controller update" >> /dev/kmsg
echo



# make sure there is a current time
if [ -f /boot/candle_hardware_clock.txt ]; 
then
    echo "Detected hardware clock indicator. Trying to get latest time update from NTP server"
    rm /boot/candle_hardware_clock.txt
    systemctl restart systemd-timesyncd.service
    timedatectl set-ntp true
    sleep 2
    /usr/sbin/fake-hwclock save
    echo "Candle: attempted requested of latest time from internet." >> /dev/kmsg
else
    echo "no hardware clock detected, assuming time is current"
fi

timedatectl set-ntp true
sleep 2
/usr/sbin/fake-hwclock save

echo "current date: $(date)"
echo

echo "Setting /ro to RW"

# This shouldn't even be possible really 

mount -o remount,rw /ro
echo "remount done"

#echo "juggling /etc/resolv.conf"
#cp /etc/resolve.conf /ro/etc/resolve.conf.jump
#rm /rw/upper/etc/resolve.conf
#rm /etc/resolve.conf
#cp /ro/etc/resolve.conf.jump /ro/etc/resolve.conf

timedatectl set-ntp true


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

#mkdir -p /ro/home/pi/tmp/boot
#cp -r --verbose /boot/* /ro/home/pi/tmp/boot

#mkdir -p /ro/home/pi/tmp/root
#cp -r --verbose /root/* /ro/home/pi/tmp/root

#cp -r --verbose /proc/device-tree /ro/home/pi/tmp/proc/device-tree
#cp -r --verbose /proc/mounts /ro/home/pi/tmp/proc/mounts


#mkdir -p /ro/home/pi/tmp/etc
#cp -r --verbose /ro/home/pi/.webthings/etc/hostname /ro/home/pi/tmp/etc/hostname
#cp -r --verbose /ro/home/pi/.webthings/etc/hosts /ro/home/pi/tmp/etc/hosts

echo "Downloading latest install script from Github" 

wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle.sh -O /ro/home/pi/create_latest_candle.sh
if [ -f /ro/home/pi/create_latest_candle.sh ]; then
    echo "Download succesful"
    chmod +x /ro/home/pi/create_latest_candle.sh
else
    echo "ERROR: DOWNLOADING LATEST SCRIPT FAILED"
    exit 1
fi

# enable internet use inside the chroot
cp /etc/resolv.conf /ro/etc/resolv.conf

# sudo chroot /ro sh -c "whoami"
# sudo chroot /ro sh -c "ls /dev"
# sudo chroot /ro sh -c "ls /mnt"
# sudo chroot /ro sh -c "apt update"
# sudo chroot /ro sh -c "cat /proc/mounts"
# sudo chroot /ro sh -c "wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle.sh"
# sudo chroot /ro sh -c "ls /home/pi/alfred"

# sudo chroot /ro sh -c "mount -t proc proc /proc && mount -t sysfs && ls /proc"
# sudo chroot /ro sh -c "mount -t procfs && mount -t sysfs && ls /proc"



#sudo chroot /ro ln -s /proc/mounts /etc/mtab

# mount -o bind /dir/outside/chroot /dir/inside/chroot


# sudo chroot /ro sh -c "ls /home/pi/alfred"

echo "bind-mounting /boot into chroot"
#if [ ! -f /boot/cmdline.txt ]; then
if ! findmnt | grep -q '/ro/boot'; then
mount /boot /ro/boot -o bind
fi

if ! findmnt | grep -q '/ro/home/pi/.webthings'; then
mkdir -p /ro/home/pi/.webthings
mount /home/pi/.webthings /ro/home/pi/.webthings -o bind
fi

echo "starting chroot"
echo "Candle: starting chroot" >> /dev/kmsg

chroot /ro sh -c "$(cat <<END
echo "in chroot"
whoami
export CHROOTED=yes
echo "/etc/resolv.conf: $(cat /etc/resolv.conf)"
echo "cat /mnt/etc/resolv.conf: $(cat /mnt/etc/resolv.conf)"
cd /home/pi
export STOP_EARLY=yes

#if [ -d /home/pi/tmp/boot ]; then
#echo "creating bind mount over /boot"
#mount --bind /home/pi/tmp/boot /boot
#else
#echo "/home/pi/tmp/boot was missing"
#fi

#mount -t procfs
if [ ! -f /proc/partitions ]; then
mount -t proc proc /proc
fi

if [ ! -d /sys/kernel ]; then
mount -t sysfs sysfs /sys
fi

if [ ! -d /dev/pts ]; then
mount --rbind /dev dev/
mount -o remount,rw /dev
fi

if [ ! -d /run/mount ]; then
mount --rbind /run run/
fi




if [ -f /home/pi/create_latest_candle.sh ]; then
echo "Install script found, starting it"
/home/pi/create_latest_candle.sh > /home/pi/update_report.txt
else
echo "Error in chroot: create_latest_candle.sh not found"
fi
touch /home/pi/TEST_FILE_CREATED_IN_CHROOT.txt

umount /run
umount /dev
umount /sys
umount /proc
umount /boot
END
)"


echo "Finalising outside of chroot"
echo "Candle: Finalising update outside of chroot" >> /dev/kmsg

sleep 5

echo "setting fkms driver"
sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/' /boot/config.txt


# delete the temporary directory
rm -rf /ro/home/pi/tmp


if [ -f /ro/home/pi/create_latest_candle.sh ]; then
    rm /ro/home/pi/create_latest_candle.sh
else
    echo "strange, the install script is gone"
fi


# does not make sense:
#if [ -d /ro/home/pi/configuration-files ]; then
#    echo "removing /ro/home/pi/configuration-files"
#else
#    echo "/ro/home/pi/configuration-files did not exist, so is not being deleted"
#    git clone --depth 1 https://github.com/createcandle/configuration-files /ro/home/pi/configuration-files
#fi


#if [ -d /home/pi/configuration-files/boot ]; then
#    cp --verbose -r /ro/home/pi/configuration-files/boot/* /boot/
#    rm -rf /ro/home/pi/configuration-files
#else
#    echo "ERROR: configuration files not downloaded?"
#    echo "Candle: ERROR: could not update files in /boot" >> /dev/kmsg
#fi



umount /ro/run
umount /ro/dev
umount /ro/sys
umount /ro/proc
umount /ro/boot

# re-enable read-only mode
echo "Setting /ro back to RO"
mount -l -o remount,ro /ro

echo "LIVE controller update done" >> /dev/kmsg


exit 0

