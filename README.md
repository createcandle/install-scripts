# Candle install scripts


THIS IS FOR DEVELOPERS ONLY. IF YOU WANT TO USE CANDLE, SIMPLY DOWNLOAD THE LATEST DISK IMAGE:

https://www.candlesmarthome.com/download


.


.


## Creating the Candle Raspberry Pi disk image
1. Install Raspberry Pi Imager software on a computer with an SD card reader, and get a micro SD card of at least 16Gb.

https://www.raspberrypi.com/software/

2. Open Raspberry Pi Imager, insert the SD card. Select Raspberry Pi OS Bullseye Lite (32 Bit) as the OS to install. Also select your SD card.

3. Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.

4. Click "write". Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt” using a text editor. From it, delete “init=/usr/lib/raspi-config/init_resize.sh”, and save. Saving might seem to fail, but it probably saved anyway. Open the cmdline.txt file again to confirm.

NOTE: If you want to get the "cutting edge" version of Candle, you will also have to create a file called `candle_cutting_edge.txt`

5. Make sure there is no other "candle.local" device on the network already, since after a reboot the Raspberry Pi's hostname will change to `candle.local`. You must also plug a network cable into the Raspberry Pi.

6. Now insert the SD card into the Raspberry Pi, power it up, wait a minute.

7. log into it via ssh using the username and hostname you entered earlier. E.g.:
```
ssh pi@candle.local
```

8. Once logged in via SSH, you can download and run the script to create the disk image.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle.sh | sudo bash
```

NOTE: If you enabled developer mode, and the script detects that a bootloader or kernel update is available, then it will install these first and reboot the system. You can then log back in and run the install command again.

9. The script will easily take an hour to run on a Raspberry Pi 3b. When it is complete it will shut down the Raspberry Pi (assuming there are no errors).

13. When you see the message that it is shutting down, wait 15 seconds until the shutdown is complete. Then take out the SD card and insert it back into your laptop again to turn it into a disk image file. On windows you can use the free version of Win32 Disk Imager for this. Make sure to check the box to only read the partitions. Name the file to be extracted something like `Candle_2.0.0.img` (depending on the intended version).

14. Once you have the .img file, zip that file to `Candle_2.0.0.img.zip` (again accounting for the desired version number). It should shrink down to less than 1.5Gb in size.

.

.

.

.

### Developer options
Note: To get the cutting edge release, use the `_dev.sh` version.
Note: There are some other options which are described in the create_latest_candle.sh file. 

For example, this command creates a disk image (though you likely have to run it twice). It creates the cutting-edge version of Candle.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh | sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes bash
```
(It's the command we really use to create the Candle disk images. Once done, do `touch /boot/candle_rw_once.txt` and then reboot the controller. Log in, wait for Zigbee2MQTT to be fully installed, and only then run the `prepare_for_disk_image.sh` script)


Many parts of the script can be turned off, details can be found in the create_latest_candle.sh script. This command turns off most parts:
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh | sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes SKIP_REBOOT=yes SKIP_PYTHON=yes SKIP_APT_INSTALL=yes SKIP_APT_UPGRADE=yes SKIP_RESPEAKER=yes SKIP_BLUEALSA=yes SKIP_CONTROLLER_INSTALL=yes SKIP_DEBUG=yes bash
```

.

.

.

.

### Live update script
With the latest versions of Candle it's now possible to fully update the controller even when read-only protection is enabled, with out needing a reboot first. This is experimental, so use at your own risk. It automatically detects if your controller is compatible. We prefer to just disable read-only first through a reboot.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/live_system_update.sh | sudo bash
```


