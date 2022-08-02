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

9. The script will easily take an hour to run on a Raspberry Pi 3b. Once complete it's complete you can reboot the controller with the `sudo reboot` command.

10. You should be able to visit http://candle.local now. Once you created an account enable SSH under settings -> developer. Then Log into the Candle controller using SSH again. Make sure all the pre-installed addon are enabled and up-to-date.

The final step is to run the script that turns a working Candle controller into a disk image.
```
sudo /home/pi/prepare_for_disk_image.sh
```

Amongst other things this will remove cached data and logs. It will also enable the read-only system disk protection. Once this process is complete the Raspberry Pi will shut down. 

Wait 15 seconds until the shutdown is complete, and then take out the SD card and insert it back into your laptop again to turn it into a disk image file. On windows you can use the free version of Win32 Disk Imager for this. Make sure to check the box to only read the partitions. Name the file to be extracted something like `Candle_2.0.0.img`.

Once you have the .img file, zip that file. It should shrink down to less than 1.5Gb in size.

