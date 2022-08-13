#!/bin/bash

# LIVE UPDATE
# If the Candle controller uses the new overlay system, then this script might be able to update it "live", without needing a reboot or fully disabling the overlay.

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi

if [ ! -d /ro ]; then
    echo "no overlay detected, aborting."
    exit 1
fi
    


echo
echo "Starting live controller upate"
echo "starting LIVE controller update" >> /dev/kmsg
echo



echo "preparations"
cd /ro/home/pi || exit


# make sure there is a current time
if [ -f /boot/candle_hardware_clock.txt ]; then
    rm /boot/candle_hardware_clock.txt
    systemctl restart systemd-timesyncd.service
    timedatectl set-ntp true
    sleep 2
    /usr/sbin/fake-hwclock save
    echo "Candle: requested latest time from internet. Date is now: $(date)" >> /dev/kmsg
fi



echo "Setting /ro to RW"

# This shouldn't even be possible really 

mount -o remount,rw /ro




availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
fileSize=$(du -k --max-depth=0 "/ro/home/pi/webthings" | awk '{print $1}')

if [ "$fileSize" -gt "$availMem" ]; then
    echo "WARNING: NOT ENOUGH DISK SPACE TO CREATE WEBTHINGS-OLD COPY"
    echo "Candle: WARNING: NOT ENOUGH DISK SPACE TO CREATE WEBTHINGS-OLD COPY" >> /dev/kmsg
else
    echo "Candle: creating backup copy to webthings-old" >> /dev/kmsg
    cp -r /ro/home/pi/webthings /ro/home/pi/webthings-old
fi



# sudo chroot /ro sh -c "ls /dev"
# sudo chroot /ro sh -c "ls /"
# sudo chroot /ro sh -c "apt update"

# mount -o bind /dir/outside/chroot /dir/inside/chroot

chroot /ro sh -c "$(cat <<END
cd /home/pi

echo "Downloading latest install script from Github" 
wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh -O ./create_candle_disk_image.sh
chmod +x ./create_candle_disk_image.sh
STOP_EARLY=yes ./create_candle_disk_image.sh
rm ./create_candle_disk_image.sh
fi

END
)"


echo "Finalising outside of chroot"
echo "Candle: Finalising update outside of chroot" >> /dev/kmsg

sleep 5

if [ -f /ro/home/pi/configuration-files ]; then
    rm -rf /ro/home/pi/configuration-files
fi
git clone --depth 1 https://github.com/createcandle/configuration-files /home/pi/configuration-files
if [ -d /home/pi/configuration-files/boot ]; then
    cp --verbose -r /home/pi/configuration-files/boot/* /boot/
else
    echo "ERROR: configuration files not downloaded?"
fi



# re-enable read-only mode
echo "setting back to RO"
mount -o remount,ro /ro

echo "LIVE controller update done" >> /dev/kmsg


exit 0

