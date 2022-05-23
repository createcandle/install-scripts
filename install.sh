# Designed to turn a Webthings disk image into a Candle disk image
# This script assumess that all the files have already been copied into place from https://github.com/createcandle/configuration-scripts


# MANAGE INSTALLED APPLICATIONS
apt-get install --no-install-recommends xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh omxplayer fbi unclutter lsb-release xfonts-base libinput-tools nbtscan -y



# TODO: chromium browser v88
 

# Just to be safe, although it should already be installed:
apt-get install omxplayer


# MAKE DIRECTORIES
mkdir -p /home/pi/.webthings/etc
mkdir -p /home/pi/.webthings/var/lib
mkdir -p /home/pi/.webthings/tmp

mkdir -p /home/pi/.webthings/arduino/.arduino15
mkdir -p /home/pi/.webthings/arduino/Arduino
mkdir -p /home/pi/candle

# COPY

cp /home/pi/.webthings/uploads/floorplan.svg /home/pi/.webthings/floorplan.svg





# SYMLINKS

# move hosts file to user partition
cp /etc/hosts /home/pi/.webthings/etc/hosts
rm /etc/hosts
ln -s /home/pi/.webthings/etc/hosts /etc/hosts

# move timezone file to user partition
cp /etc/timezone /home/pi/.webthings/etc/timezone
rm /etc/timezone 
ln -s /home/pi/.webthings/etc/timezone /etc/timezone 

# move fake hardware clock to user partition
rm /etc/fake-hwclock.data
ln -s /home/pi/.webthings/etc/fake-hwclock.data /etc/fake-hwclock.data


# BINDS

echo "candle" > /home/pi/.webthings/etc/hostname
cp -r /etc/ssh /home/pi/.webthings/etc/ssh
cp -r /etc/wpa_supplicant /home/pi/.webthings/etc/wpa_supplicant/
cp -r /var/lib/bluetooth /home/pi/.webthings/var/lib/bluetooth




# SERVICES
systemctl daemon-reload

systemctl disable webthings-gateway.check-for-update.service
systemctl disable webthings-gateway.check-for-update.timer
systemctl disable webthings-gateway.update-rollback.service

systemctl enable candle_first_run.service
systemctl enable candle_bootup_actions.service
systemctl enable candle_start_swap.service

systemctl enable splashscreen.service
systemctl enable splashscreen180.service

systemctl enable candle_hostname_fix.service # ugly solution, might not even be necessary anymore?



# BLUEALSA
# compile and install BlueAlsa with legaly safe codes and built-in audio mixing
git clone https://github.com/createcandle/bluez-alsa.git
cd bluez-alsa
autoreconf --install --force
mkdir build
cd build
../configure --enable-msbc --enable-mp3lame --enable-faststream
make
make install
cd ../..
rm -rf bluez-alsa


# RASPI CONFIG

# enable camera
raspi-config nonint do_camera 0





# KIOSK

# Download boot splash images and video
wget https://www.candlesmarthome.com/tools/splash.png -P /boot/
wget https://www.candlesmarthome.com/tools/splash180.png -P /boot/
wget https://www.candlesmarthome.com/tools/splash.mp4 -P /boot/
mkdir -p /usr/share/plymouth/themes/pix/
cp /boot/splash.png /usr/share/plymouth/themes/pix/splash.png

# Hides the Raspberry Pi logos shown at boot
isInFile2=$(cat /boot/config.txt | grep -c "disable_splash")
if [ $isInFile2 -eq 0 ]
then
	echo "- Adding disable_splash to config.txt"
	echo 'disable_splash=1' >> /boot/config.txt
else
    echo "- Splash was already disabled in config.txt"
fi

# Hide the text normally shown when linux boots up
isInFile=$(cat /boot/cmdline.txt | grep -c "tty3")
if [ $isInFile -eq 0 ]
then    
	echo "- Modifying cmdline.txt"
	# change text output to third console. press alt-shift-F3 during boot to see it again.
    sed -i 's/tty1/tty3/' /boot/cmdline.txt
	# hide all the small things normally shown at boot
	sed -i ' 1 s/.*/& quiet plymouth.ignore-serial-consoles splash logo.nologo vt.global_cursor_default=0/' /boot/cmdline.txt        
else
        echo "- The cmdline.txt file was already modified"
fi

# Hide the login text (it will still be available on tty3 - connect a keyboard to your pi and press CTRl-ALT-F3 to see it)
systemctl enable getty@tty3.service
systemctl disable getty@tty1.service



# Sets more power for USB ports
isInFile3=$(cat /boot/config.txt | grep -c "max_usb_current")
if [ $isInFile3 -eq 0 ]
then
	echo "- Setting USB to deliver more current in config.txt"
	echo 'max_usb_current=1' >> /boot/config.txt
else
    echo "- USB was already set to deliver more current in config.txt"
fi



# Disable Openbox keyboard shortcuts to make the kiosk mode harder to escape
wget https://www.candlesmarthome.com/tools/rc.xml -P /etc/xdg/openbox/rc.xml

# Modify the xinitrc file to automatically log in the pi user
echo "- Creating xinitrc file"
echo 'exec openbox-session' > /etc/X11/xinit/xinitrc

echo "- Creating xwrapper.config file"
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config






# CHROMIUM 

# Add policy file to disable things like file selection
mkdir -p /etc/chromium/policies/managed/
echo '{"AllowFileSelectionDialogs": false, "AudioCaptureAllowed": false}' > /etc/chromium/policies/managed/candle.json






# TODO:
# RASPI-CONFIG
# - Enabled SPI 
# - Enabled I2C

# ~/.config/configstore/update-notifier-npm.json <- set output to true

# Respeaker drivers?

# update python libraries except for 2 (schemajson and... )
# directory ownership and permissions
# install openbox. And disable its shortcuts. See original kiosk install script: https://www.candlesmarthome.com/tools/kiosk.txt

# LONG TERM TODO?
# Go 64 bit?
# Copy IP routes and other setup/settings from Webthings disk image creation? That way only one install script needs to be run instead of a waterfall model.
