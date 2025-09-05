# Candle install scripts


THIS IS FOR DEVELOPERS ONLY. IF YOU WANT TO USE CANDLE, SIMPLY DOWNLOAD THE LATEST DISK IMAGE:

https://www.candlesmarthome.com/download


.


.


## Creating the Candle Raspberry Pi disk image
For this you will need:
- A Raspberry pi with at least 2Gb of memory
- An internet router with a free network cable
- A micro SD card of at least 16Gb
- An internet connected computer that can read/write the SD card

1. Install Raspberry Pi Imager software on a computer with an SD card reader.

https://www.raspberrypi.com/software/

2. Open Raspberry Pi Imager, insert the SD card. Select Raspberry Pi OS Bullseye Lite (32 Bit) as the OS to install. Also select your SD card as the drive to flash it to.

3. Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.

4. Click "write". Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt” using a text editor. From it, delete the part that starts with “init=”, and save. Saving might seem to fail, but it probably saved anyway. Open the cmdline.txt file again to confirm.

5. Make sure there is no other "candle.local" device on the network already, since after a reboot the Raspberry Pi's hostname will change to `candle.local` (if it isn't called that already). You must also plug a network cable into the Raspberry Pi to avoid download issues.

6. Now insert the SD card into the Raspberry Pi, power it up, wait a minute.

7. log into it via ssh using the username and hostname you entered earlier. E.g.:
```
ssh pi@candle.local
```

8. Once logged in via SSH, you can download and run the script to create the disk image.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle.sh | sudo bash
```

NOTE: If the script detects that a bootloader or kernel update is available (which is very likely), then it will install these first and reboot the system. You can then log back in and run the install command again.

9. The script will easily take more than an hour to run on a Raspberry Pi 3b. When it is complete it will shut down the Raspberry Pi (assuming there are no errors).

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
curl -H 'Cache-Control: no-cache' -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh -o create_latest_candle_dev.sh; sudo chmod +x create_latest_candle_dev.sh; sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes bash ./create_latest_candle_dev.sh
```
This variation uses nohup so that the installation process will continue even if SSH disconnects.
```
curl -H 'Cache-Control: no-cache' -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh -o create_latest_candle_dev.sh; sudo chmod +x create_latest_candle_dev.sh; sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes nohup bash ./create_latest_candle_dev.sh > /boot/firmware/candle_build_log.txt 2>&1 & tail -f /boot/firmware/candle_build_log.txt
```

Or the tiny partition version, which is used to create downloadable system updates only:
```
curl -H 'Cache-Control: no-cache' -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh -o create_latest_candle_dev.sh; sudo chmod +x create_latest_candle_dev.sh; sudo CUTTING_EDGE=yes TINY_PARTITIONS=yes CREATE_DISK_IMAGE=yes bash ./create_latest_candle_dev.sh
```
(It's the command we really use to create the Candle disk images. Once done, do `touch /boot/candle_rw_once.txt` and then reboot the controller. Log in, wait for Zigbee2MQTT to be fully installed, and only then run the `prepare_for_disk_image.sh` script)


Many parts of the script can be turned off, details can be found in the create_latest_candle.sh script. This command turns off most parts:
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh | sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes SKIP_REBOOT=yes SKIP_PYTHON=yes SKIP_APT_INSTALL=yes SKIP_APT_UPGRADE=yes SKIP_RESPEAKER=yes SKIP_BLUEALSA=yes SKIP_CONTROLLER_INSTALL=yes SKIP_DEBUG=yes bash
```


A 32 bit version can be created. This has a limitation, in that Matter can only run on 64 bit.
```
curl -H 'Cache-Control: no-cache' -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh -o create_latest_candle_dev.sh; sudo chmod +x create_latest_candle_dev.sh; sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes TINY_PARTITIONS=yes BIT32=yes bash ./create_latest_candle_dev.sh
```





.

.

.

.

.

### Installing the controller software only (advanced)
It's technically also possible to install only the Candle Controller software on an existing system (and skip the entire disk image around it). This is done by running the `install_candle_controller.sh` script on its own. For example:

```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh | bash
```
To then start the controller, start `run-app.sh` in the `webthings/gateway` folder. Then you should be able to open the controller on port 8080, e.g. by visiting `http://[your_local_name_here]:8080`

Note:
- This does not install all the systemd services, so it won't auto-start at boot. You'll have to add that manually. An example file can be found here:
https://github.com/createcandle/configuration-files/blob/main/etc/systemd/system/webthings-gateway.service
- This does not install iptables redirects, so by default the controller will be available on port `8080` only. An example of how to add these rules can be found here:
https://github.com/createcandle/configuration-files/blob/a11fcef2a77c59a2d38a5b8d59b8488e7c29710a/home/pi/candle/early.sh#L14

.

.

.

.

### Live update script (deprecated)
With the latest versions of Candle it's now possible to fully update the controller even when read-only protection is enabled, with out needing a reboot first. This is experimental, so use at your own risk. It automatically detects if your controller is compatible. We prefer to just disable read-only first through a reboot.

```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/live_system_update.sh | sudo bash
```

### Old version of install script:
```
curl -H 'Cache-Control: no-cache' -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh | sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes bash
```





