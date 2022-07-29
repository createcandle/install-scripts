# install-scripts

# PREPARATION
# Flash basic Raspberry Pi OS Lite 64 image using Raspberry Pi Imager software. 
# https://www.raspberrypi.com/software/

# Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.


# Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt”. From it, remove “init=/usr/lib/raspi-config/init_resize.sh”, and save. Saving might seem to fail, but it probably saved anyway.

# Make sure there is no other "candle.local" device on the network already.
# Now insert the SD card into the Raspberry Pi, power it up, wait a minute, and log into it via ssh:
# ssh pi@candle.local

# Once logged in via SSH, you can download and run this install script.
# curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/install.sh | sudo bash
