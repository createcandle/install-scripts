# Candle install scripts


## Creating the Candle Raspberry Pi disk image
1. Install Raspberry Pi Imager software on a computer with an SD card reader, and get a micro SD card of at least 16Gb.

https://www.raspberrypi.com/software/

2. Open Raspberry Pi Imager, insert the SD card. Select Raspberry Pi OS Bullseye Lite (32 Bit) as the OS to install. Also select your SD card.

3. Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.

4. Click "write". Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt” using a text editor. From it, delete “init=/usr/lib/raspi-config/init_resize.sh”, and save. Saving might seem to fail, but it probably saved anyway. Open the cmdline.txt file again to confirm.

5. Make sure there is no other "candle.local" device on the network already, since after a reboot the Raspberry Pi's hostname will change to `candle.local`. You must also plug a network cable into the Raspberry Pi.

6. Now insert the SD card into the Raspberry Pi, power it up, wait a minute.

7. log into it via ssh using the username and hostname you entered earlier. E.g.:
```
ssh pi@candle.local
```

8. Once logged in via SSH, you can download and run the script to create the disk image.
```
curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh | sudo bash
```

9. The script will easily take an hour to run on a Raspberry Pi 3b. When it is complete it will shut down the Raspberry Pi.

13. When you see the message that it is shutting down, wait 15 seconds until the shutdown is complete. Then take out the SD card and insert it back into your laptop again to turn it into a disk image file. On windows you can use the free version of Win32 Disk Imager for this. Make sure to check the box to only read the partitions. Name the file to be extracted something like `Candle_2.0.0.img` (depending on the intended version).

14. Once you have the .img file, zip that file to `Candle_2.0.0.img.zip` (again accounting for the desired version number). It should shrink down to less than 1.5Gb in size.

.

.

.

.

### Developer options
Note: There are some other options which are described in the create_candle_disk_image.sh file. For example, it's possible to inspect what the script has generated before it shuts down with this command:
```
STOP_EARLY=yes curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh | sudo bash
```
