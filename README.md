# Candle install scripts



## Creating the Candle Raspberry Pi disk image
1. Flash basic Raspberry Pi OS Lite 32 Bit image using Raspberry Pi Imager software. 
2. https://www.raspberrypi.com/software/

3. Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.

4. Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt”. From it, remove “init=/usr/lib/raspi-config/init_resize.sh”, and save. Saving might seem to fail, but it probably saved anyway. Open the cmdline.txt file again to confirm.

5. Make sure there is no other "candle.local" device on the network already, since after a reboot the Raspberry Pi's hostname will change to `candle.local`. It's also highly recommended to plug a network cable into the Raspberry Pi.

6. Now insert the SD card into the Raspberry Pi, power it up, wait a minute, and log into it via ssh using the username and hostname you entered earlier. E.g.:
```
ssh pi@candle.local
```

8. Once logged in via SSH, you can download and run the script to create the disk image.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh | sudo bash
```

The script, once done, will reboot the Raspberry Pi. You should now have a Candle controller with only one addon, the Candle store. Use the Candle store to at least install the following addons:
- Power settings
- Candle theme
- Zigbee2MQTT

Also, enable SSH under settings -> developer. Then Log into the Candle controller using SSH again.

The final step is to run the script that turns a controller into a disk image.
```
sudo /home/pi/prepare_for_disk_image.sh
```

Once the process is complete the Raspberry Pi will shut down. You can then insert the SD card back into your laptop again to turn it into a disk image file. On windows you can use the free version of Win32 Disk Imager for this. Make sure to check the box to only read the partitions. Name the file to be extracted something like `Candle_2.0.0.img`.

Once you have the .img file, zip that file. It should shrink down to less than 1.5Gb in size.


## Installing the Candle Controller only
This script is part of the larger script that creates the Candle Disk Image, and can technically be run separately. It assumes a Raspberry Pi OS with username pi.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh | bash
```
