#!/bin/bash

# LIVE UPDATE
# If the Candle controller uses the new overlay system, then this script might be able to update it "live", without needing a reboot or fully disabling the overlay.

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi


echo
echo "Starting live controller upate"
echo "starting LIVE controller update" >> /dev/kmsg
echo
echo "Setting /ro to RW"

# This shouldn't even be possible really 

mount -o remount,rw /ro
      
chroot /ro sh -c "$(cat <<END
cd /home/pi

cp ./webthings ./webthings-old

wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh
chmod +x ./create_candle_disk_image.sh
./create_candle_disk_image.sh
rm ./create_candle_disk_image.sh
fi

END
)"

# re-enable read-only mode
echo "setting back to RO"
mount -o remount,ro /ro

echo "LIVE controller update done" >> /dev/kmsg


exit 0

