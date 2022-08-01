# install-scripts

## Installing the Candle Controller only
This script is part of the larger script that creates the Candle Disk Image, and can technically be run separately.
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh | bash

## Creating the Candle Raspberry Pi disk image
1. Flash basic Raspberry Pi OS Lite 64 image using Raspberry Pi Imager software. 
2. https://www.raspberrypi.com/software/

3. Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.

4. Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt”. From it, remove “init=/usr/lib/raspi-config/init_resize.sh”, and save. Saving might seem to fail, but it probably saved anyway.

5. Make sure there is no other "candle.local" device on the network already(if so you could reflash the card using a differente name on point 3).
6. Now insert the SD card into the Raspberry Pi, power it up, wait a minute, and log into it via ssh:
7. ssh pi@candle.local(or username@hostname.local that you set on point if different)

8. Once logged in via SSH, you can download and run this install script.
9. curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh | sudo bash
