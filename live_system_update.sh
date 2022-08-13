#!/bin/bash

# LIVE UPDATE
# If the Candle controller uses the new overlay system, then this script might be able to update it "live", without needing a reboot or fully disabling the overlay.

echo
echo "CANDLE LIVE UPDATE"


# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
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
if [ -f /boot/candle_hardware_clock.txt ]; then
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

if [ -d /ro/home/pi/webthings ]; then

    availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
    fileSize=$(du -k --max-depth=0 "/ro/home/pi/webthings" | awk '{print $1}')

    if [ "$fileSize" -gt "$availMem" ]; then
        echo "WARNING: NOT ENOUGH DISK SPACE TO CREATE WEBTHINGS-OLD COPY"
        echo "Candle: WARNING: NOT ENOUGH DISK SPACE TO CREATE WEBTHINGS-OLD COPY" >> /dev/kmsg
    else
        echo "Creating backup copy op webthings folder"
        echo "Candle: creating backup copy to webthings-old" >> /dev/kmsg
        cp -r /ro/home/pi/webthings /ro/home/pi/webthings-old
    fi
fi


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
# sudo chroot /ro sh -c "ls /"
# sudo chroot /ro sh -c "apt update"

# mount -o bind /dir/outside/chroot /dir/inside/chroot
echo "starting chroot"
echo "Candle: starting chroot" >> /dev/kmsg

chroot /ro sh -c "$(cat <<END
echo "in chroot"
cd /home/pi
STOP_EARLY=yes /home/pi/create_candle_disk_image.sh
END
)"


echo "Finalising outside of chroot"
echo "Candle: Finalising update outside of chroot" >> /dev/kmsg

sleep 5

rm /ro/home/pi/create_candle_disk_image.sh

if [ -d /ro/home/pi/configuration-files ]; then
    rm -rf /ro/home/pi/configuration-files
fi
git clone --depth 1 https://github.com/createcandle/configuration-files /home/pi/configuration-files
if [ -d /home/pi/configuration-files/boot ]; then
    cp --verbose -r /home/pi/configuration-files/boot/* /boot/
else
    echo "ERROR: configuration files not downloaded?"
fi



# re-enable read-only mode
echo "Setting /ro back to RO"
mount -o remount,ro /ro

echo "LIVE controller update done" >> /dev/kmsg


exit 0

