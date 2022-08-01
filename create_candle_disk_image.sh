#!/bin/bash

# TODO: check if candlecam works on this disk image, as it may use the new camera interface

# This script will turn a Raspberry Pi OS Lite installation into a Candle controller

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



# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi



# CREATE PARTITIONS

cd /home/pi

echo " "
echo "CREATING CANDLE DISK IMAGE"
echo " "
echo "PATH: $PATH"


if [ ! -d "/dev/mmcblk0p3" ]
then
    echo " "
    echo "CREATING PARTITIONS"
    echo " "

    printf "resizepart 2 6500\nmkpart\np\next4\n6501MB\n14000MB\nquit" | parted
    resize2fs /dev/mmcblk0p2
    printf "y" | mkfs.ext4 /dev/mmcblk0p3
    mkdir /home/pi/.webthings
    chown pi:pi /home/pi/.webthings
    mount /dev/mmcblk0p3 /home/pi/.webthings
    

else
    echo "partitions already created:"
fi

lsblk
echo " "


# INSTALL PROGRAMS AND UPDATE
echo " "
echo "INSTALLING APPLICATIONS AND LIBRARIES"
echo " "

apt update
apt install autoconf build-essential curl git libbluetooth-dev libboost-python-dev libboost-thread-dev libffi-dev libglib2.0-dev libpng-dev libudev-dev libusb-1.0-0-dev pkg-config python-six python3-pip -y

apt install -y \
  arping \
  autoconf \
  ffmpeg \
  libboost-python-dev \
  libboost-thread-dev \
  libbluetooth-dev \
  libffi-dev \
  libglib2.0-dev \
  libtool \
  libudev-dev \
  libusb-1.0-0-dev \
  mosquitto \
  policykit-1 \
  sqlite3 \
  iptables


apt install -y \
  dnsmasq \
  hostapd

systemctl unmask hostapd.service
systemctl disable hostapd.service
systemctl disable dnsmasq.service


# removed from above list:
#  libnanomsg-dev \
#  libnanomsg5 \
#  python-pip \

# additional programs for Candle kiosk mode:
apt-get install --no-install-recommends xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh omxplayer fbi unclutter lsb-release xfonts-base libinput-tools nbtscan -y

# for BlueAlsa
apt-get install libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev -y


echo " "
echo "UPGRADING LINUX"
apt --fix-broken install -y
apt upgrade -y
apt autoremove -y

# Install browser. Unfortunately its chromium, and not firefox, because its so much better at being a kiosk, and so much more customisable.
# TODO: this should be version 88.
apt-get install chromium



# PYTHON
echo " "
echo "INSTALLING PYTHON PACKAGES"
sudo -u pi pip3 install dbus-python
sudo -u pi python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon



# BLUEALSA
if [ ! -d "/usr/bin/bluealsa" ]
then
    
    echo " "
    echo "Creating BlueAlsa"
    echo " "

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

else
    echo "BlueAlsa was already installed"
fi





# sudo update-rc.d gateway-iptables defaults

# TODO: also need to look closer at this: https://github.com/WebThingsIO/gateway/tree/37591f4be3542901255da3c901396f3e9b8a443b/image/etc



# INSTALL CANDLE CONTROLLER

echo " "
echo "INSTALLING CANDLE CONTROLLER"
echo " "

wget https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh
sudo -u pi ./install_candle_controller.sh
rm install_candle_controller.sh

setcap cap_net_raw+eip $(eval readlink -f `which node`)
setcap cap_net_raw+eip $(eval readlink -f `which python3`)






echo " "
echo "INSTALLING CANDLE STORE"
echo " "

cd /home/pi/.webthings/addons
wget https://github.com/createcandle/candleappstore/releases/download/0.4.17/candleappstore-0.4.17-linux-arm64-v3.9.tgz
tar -xf candleappstore-0.4.17-linux-arm64-v3.9.tgz
mv package candleappstore
chown pi:pi candleappstore
rm candleappstore-0.4.17-linux-arm64-v3.9.tgz
cd /home/pi




echo " "
echo "INSTALLING OTHER FILES AND SERVICES"
echo " "


# switch back to root of home folder
cd /home/pi


# Make folders that should be owned by Pi user
mkdir /home/pi/Arduino
chown pi:pi /home/pi/Arduino

mkdir /home/pi/.arduino
chown pi:pi /home/pi/.arduino

mkdir -p /home/pi/.webthings/arduino/.arduino15
chown pi:pi /home/pi/.webthings/arduino/.arduino15

mkdir -p /home/pi/.webthings/arduino/Arduino
chown pi:pi /home/pi/.webthings/arduino/Arduino

touch /home/pi/candle.log
chown pi:pi /home/pi/candle.log

mkdir -p /home/pi/.webthings/etc
chown pi:pi /home/pi/.webthings/etc

mkdir -p /home/pi/candle
chown pi:pi /home/pi/candle


# Make folders that should be owned by root
mkdir -p /home/pi/.webthings/var/lib/bluetooth
mkdir -p /home/pi/.webthings/etc/wpa_supplicant
mkdir -p /home/pi/.webthings/etc/ssh
mkdir -p /home/pi/.webthings/etc/hostname
mkdir -p /home/pi/.webthings/tmp


# all directories needed to keep fstab happy should now exist


# COPY FILES

cd /home/pi

# Used when doing factory reset to restore original floorplan image:
cp /home/pi/.webthings/uploads/floorplan.svg /home/pi/.webthings/floorplan.svg

# download tons of ready-made settings files from the Candle github
git clone --depth 1 https://github.com/createcandle/configuration-files
cp -R /home/pi/configuration-files/boot/* /boot/
cp -R /home/pi/configuration-files/etc/* /etc/
cp -R /home/pi/configuration-files/home/pi/* /home/pi/
cp -R /home/pi/configuration-files/lib/systemd/system/* /lib/systemd/system/ 


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

# disable triggerhappy (keyboard shortcuts)
systemctl disable triggerhappy.socket
systemctl disable triggerhappy.service

# enable Candle services
systemctl enable candle_first_run.service
systemctl enable candle_bootup_actions.service
systemctl enable candle_start_swap.service
systemctl enable splashscreen.service
systemctl enable splashscreen180.service
systemctl enable splashscreen_updating.service
systemctl enable splashscreen_updating180.service

systemctl enable candle_hostname_fix.service # ugly solution, might not even be necessary anymore? Nope, tested, still needed.




# KIOSK

# Download boot splash images and video
wget https://www.candlesmarthome.com/tools/splash.png -P /boot/
wget https://www.candlesmarthome.com/tools/splash180.png -P /boot/
wget https://www.candlesmarthome.com/tools/splash_updating.png -P /boot/
wget https://www.candlesmarthome.com/tools/splash_updating180.png -P /boot/
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





# ADD IP-TABLES

  echo "Redirecting :80 to :8080 and :443 to :4443"
  iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-mark 1
  iptables -t mangle -A PREROUTING -p tcp --dport 443 -j MARK --set-mark 1
  iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
  iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4443
  iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -m mark --mark 1 -j ACCEPT
  iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 4443 -m mark --mark 1 -j ACCEPT



# TODO:

# ~/.config/configstore/update-notifier-npm.json <- set output to true
# Respeaker drivers?
# update python libraries except for 2 (schemajson and... )



# RASPI CONFIG

# enable i2c, needed for clock module support
raspi-config nonint do_i2c 0

# enable SPI
raspi-config nonint do_spi 0

# enable Camera.
raspi-config nonint do_camera 0




# CLEANUP

# remove no longer needed applications?
# apt-get purge libtool

# disable swap file
dphys-swapfile swapoff


