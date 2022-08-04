#!/bin/bash
set +e # continue on errors

# TODO: check if candlecam works on this disk image, as it may use the new camera interface

# This script will turn a Raspberry Pi OS Lite installation into a Candle controller

# PREPARATION
# Flash basic Raspberry Pi OS Lite Legacy image using Raspberry Pi Imager software. 
# https://www.raspberrypi.com/software/

# Use the gear icon to set everything up that you can: enable ssh, set username "pi" and password "smarthome", set the hostname to "candle", pre-fill your wifi credentials, etc.

# Once flashing is complete, unplug the SD card from your computer and re-insert it into your computer. A new disk called "boot" should appear. Edit the file called “cmdline.txt”. From it, remove “init=/usr/lib/raspi-config/init_resize.sh”, and save. Saving might seem to fail, but it probably saved anyway.

# Make sure there is no other "candle.local" device on the network already.
# Now insert the SD card into the Raspberry Pi, power it up, wait a minute, and log into it via ssh:
# ssh pi@candle.local

# Once logged in via SSH, you can download and run this install script.
# curl -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_candle_disk_image.sh | sudo bash



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
date
echo "PATH: $PATH"


if ls /dev/mmcblk0p3; then
    echo " "
    echo "partitions already created:"
else
    echo " "
    echo "CREATING PARTITIONS"
    echo " "

    printf "resizepart 2 6500\nmkpart\np\next4\n6501MB\n14000MB\nquit" | parted
    resize2fs /dev/mmcblk0p2
    printf "y" | mkfs.ext4 /dev/mmcblk0p3
    mkdir /home/pi/.webthings
    chown pi:pi /home/pi/.webthings
fi


mount /dev/mmcblk0p3 /home/pi/.webthings
chown pi:pi /home/pi/.webthings

lsblk
echo " "


# INSTALL PROGRAMS AND UPDATE
echo " "
echo "INSTALLING APPLICATIONS AND LIBRARIES"
echo " "

set -e
echo " "
echo "calling apt update"
apt update -y
apt-get update -y
echo " "
echo "calling apt upgrade"
#apt DEBIAN_FRONTEND=noninteractive upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y &
wait
echo " "
echo "Upgrade complete"

set +e

# Install browser. Unfortunately its chromium, and not firefox, because its so much better at being a kiosk, and so much more customisable.
# TODO: maybe use version 88?
echo " "
echo "installing chromium-browser"
apt install chromium-browser -y

echo " "
echo "installing vlc"
apt install vlc --no-install-recommends -y

#echo 'deb http://download.opensuse.org/repositories/home:/ungoogled_chromium/Debian_Bullseye/ /' | sudo tee /etc/apt/sources.list.d/home-ungoogled_chromium.list > /dev/null
#curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Debian_Bullseye/Release.key' | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home-ungoogled_chromium.gpg > /dev/null
#apt update
#apt install ungoogled-chromium -y

echo " "
echo "installing git"
apt install git -y 

echo " "
echo "installing build tools"
for i in autoconf build-essential curl libbluetooth-dev libboost-python-dev libboost-thread-dev libffi-dev libglib2.0-dev libpng-dev libudev-dev libusb-1.0-0-dev pkg-config python-six; do
    echo "$i"
    apt install -y $i
    echo " "
done

echo " "
echo "installing pip3"
apt install -y python3-pip

rm /etc/mosquitto/mosquitto.conf

echo " "
echo "installing support programs like ffmpeg, arping, libolm, sqlite, mosquitto"
for i in arping autoconf ffmpeg libtool mosquitto policykit-1 sqlite3 libolm3 libffi6 nbtscan; do
    echo "$i"
    apt install -y $i
    echo " "
done

echo " "
echo "installing ip tables"
apt install -y iptables

# removed from above list:
#  libnanomsg-dev \
#  libnanomsg5 \

# additional programs for Candle kiosk mode:
echo " "
echo "installing kiosk packages (x, openbox)"
for i in xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools; do
    echo "$i"
    apt-get install --no-install-recommends -y $i
    echo " "
done
#apt-get install --no-install-recommends xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools nbtscan -y

# get OMXPlayer for Internet Radio
# http://archive.raspberrypi.org/debian/pool/main/o/omxplayer/

echo " "
echo "installing omxplayer"
for i in liblivemedia-dev libavcodec58 libavutil56 libswresample3 libavformat58; do
    echo "$i"
    apt-get install -y $i
    echo " "
done
#apt install liblivemedia-dev libavcodec58 libavutil56 libswresample3 libavformat58 -y
apt --fix-broken install -y

wget http://archive.raspberrypi.org/debian/pool/main/o/omxplayer/omxplayer_20190723+gitf543a0d-1+bullseye_armhf.deb
dpkg -i omxplayer_20190723+gitf543a0d-1+bullseye_armhf.deb
rm omxplayer*

#apt --fix-broken install -y

mkdir -p /opt/vc/
wget https://www.candlesmarthome.com/tools/lib.tar
tar -xvf lib.tar -C /opt/vc/
rm lib.tar


# for BlueAlsa
echo "installing bluealsa support packages"
for i in libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev; do
    echo "$i"
    apt install -y $i
    echo " "
done
#apt install libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev -y


# Camera support

for i in python3-libcamera python3-kms++ python3-prctl libatlas-base-dev libopenjp2-7; do
    echo "$i"
    apt install -y $i
    echo " "
done

echo " "
echo "UPGRADING LINUX"
apt-get update --fix-missing -y
apt --fix-broken install -y
apt upgrade -y
echo ""
echo "calling autoremove"
apt autoremove -y


dpkg -s git &> /dev/null

if [ $? -eq 0 ]; then
    echo "git installed succesfully"
else
    echo " "
    echo "ERROR"
    echo " "
    echo "Error detected in the packages install phase (git is missing). Try running the Candle install script again."
    echo ""
    exit 1
fi



# PYTHON
echo " "
echo "INSTALLING AND UPDATING PYTHON PACKAGES"

# upgrade pip first
sudo -u pi python3 -m pip install --upgrade pip

sudo -u pi pip3 uninstall -y adapt-parser || true
sudo -u pi pip3 install dbus-python pybluez pillow pycryptodomex numpy

if [ -d "/home/pi/.local/bin" ] ; then
    echo "adding /home/pi/.local/bin to path"
    PATH="/home/pi/.local/bin:$PATH"
fi

sudo -u pi python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon

echo "Updating existing python packages"
sudo -u pi pip install --upgrade certifi chardet colorzero dbus-python distro requests RPi.GPIO ssh-import-id urllib3 wheel libevdev




# RESPEAKER HAT

if [ ! -d "/etc/voicecard" ]
then
    echo " "
    echo "INSTALLING RESPEAKER HAT DRIVERS"
    cd /home/pi
    git clone --depth 1 https://github.com/HinTak/seeed-voicecard.git
    cd seeed-voicecard
    ./install.sh
    
else
    echo "ReSpeaker was already installed"
fi

cd /home/pi
rm -rf seeed-voicecard


# BLUEALSA
if [ ! -d "/usr/bin/bluealsa" ]
then
    
    echo " "
    echo "INSTALLING BLUEALSA BLUETOOTH SPEAKER DRIVERS"
    echo " "

    # compile and install BlueAlsa with legaly safe codes and built-in audio mixing
    git clone --depth 1 https://github.com/createcandle/bluez-alsa.git
    cd bluez-alsa
    autoreconf --install --force
    mkdir build
    cd build
    ../configure --enable-msbc --enable-mp3lame --enable-faststream
    make
    make install

else
    echo "BlueAlsa was already installed"
fi

cd /home/pi
rm -rf bluez-alsa



# sudo update-rc.d gateway-iptables defaults

# TODO: also need to look closer at this: https://github.com/WebThingsIO/gateway/tree/37591f4be3542901255da3c901396f3e9b8a443b/image/etc



# INSTALL CANDLE CONTROLLER

echo " "
echo "INSTALLING CANDLE CONTROLLER"
echo " "

cd /home/pi
rm -rf /home/pi/webthings
#rm -rf /home/pi/.webthings # too dangerous

wget https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh
chmod +x ./install_candle_controller.sh
sudo -u pi ./install_candle_controller.sh
rm install_candle_controller.sh

cd /home/pi

setcap cap_net_raw+eip $(eval readlink -f `which node`)
setcap cap_net_raw+eip $(eval readlink -f `which python3`)


echo " "
echo "INSTALLING HOSTAPD AND DNSMASQ"
echo " "

apt install -y dnsmasq 
systemctl disable dnsmasq.service

apt install -y hostapd
systemctl unmask hostapd.service
systemctl disable hostapd.service






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

mkdir -p /var/run/mosquitto/
chown mosquitto: /var/run/mosquitto
chmod 755 /var/run/mosquitto

# Make folders that should be owned by root
mkdir -p /home/pi/.webthings/var/lib/bluetooth
mkdir -p /home/pi/.webthings/etc/wpa_supplicant
mkdir -p /home/pi/.webthings/etc/ssh

# Create files that are linked to using binding in fstab
cp /etc/hostname /home/pi/.webthings/etc/hostname


rm -rf /tmp/*
echo "/tmp contents:"
ls -l -a /tmp
#mkdir -p /home/pi/.webthings/tmp
cp -r /tmp /home/pi/.webthings/tmp
chmod 1777 /home/pi/.webthings/tmp
find /home/pi/.webthings/tmp \
     -mindepth 1 \
     -name '.*-unix' -exec chmod 1777 {} + -prune -o \
     -exec chmod go-rwx {} +

# all directories needed to keep fstab happy should now exist


# COPY FILES

cd /home/pi

cp /home/pi/webthings/gateway/static/images/floorplan.svg /home/pi/.webthings/floorplan.svg
chown pi:pi /home/pi/.webthings/floorplan.svg


# SYMLINKS

# move hosts file to user partition
cp --verbose /etc/hosts /home/pi/.webthings/etc/hosts
rm /etc/hosts
ln -s /home/pi/.webthings/etc/hosts /etc/hosts

# move timezone file to user partition
cp --verbose /etc/timezone /home/pi/.webthings/etc/timezone
rm /etc/timezone 
ln -s /home/pi/.webthings/etc/timezone /etc/timezone 

# move fake hardware clock to user partition
rm /etc/fake-hwclock.data
ln -s /home/pi/.webthings/etc/fake-hwclock.data /etc/fake-hwclock.data


# BINDS
echo "copying ssh, wpa_supplicant and bluetooth folder data to user partition"
echo "candle" > /home/pi/.webthings/etc/hostname
cp --verbose -r /etc/ssh /home/pi/.webthings/etc/
cp --verbose -r /etc/wpa_supplicant /home/pi/.webthings/etc/
cp --verbose -r /var/lib/bluetooth /home/pi/.webthings/var/lib/



# Download tons of ready-made settings files from the Candle github
echo " "
echo "DOWNLOADING AND COPYING CONFIGURATION FILES FROM GITHUB"
echo " "
rm -rf /home/pi/configuration-files
git clone --depth 1 https://github.com/createcandle/configuration-files /home/pi/configuration-files
cp --verbose -r /home/pi/configuration-files/boot/* /boot/
cp --verbose -r /home/pi/configuration-files/etc/* /etc/
cp --verbose /home/pi/configuration-files/home/pi/* /home/pi/
cp --verbose -r /home/pi/configuration-files/home/pi/candle/* /home/pi/candle
cp --verbose -r /home/pi/configuration-files/home/pi/.webthings/etc/* /home/pi/.webthings/etc/
cp --verbose -r /home/pi/configuration-files/lib/systemd/system/* /lib/systemd/system/ 
rm -rf /home/pi/configuration-files

#chmod +x /home/pi/candle_first_run.sh

chown pi:pi /home/pi/.webthings/etc/webthings_settings_backup.js
chown pi:pi /home/pi/.webthings/etc/webthings_settings.js
chown pi:pi /home/pi/.webthings/etc/webthings_tunnel_default.js

ln -s /home/pi/.webthings/etc/asound.rc /home/pi/.asound.rc
#chown mosquitto: /home/pi/.webthings/etc/mosquitto/zcandle.conf
#chown mosquitto: /home/pi/.webthings/etc/mosquitto/mosquitto.conf

# SERVICES
echo " "
echo "ENABLING AND DISABLING SERVICES"
echo " "
#systemctl daemon-reload


# disable triggerhappy
systemctl disable triggerhappy.socket
systemctl disable triggerhappy.service


# enable Candle services
systemctl enable candle_first_run.service
systemctl enable candle_bootup_actions.service
systemctl enable candle_start_swap.service
systemctl enable candle_early.service
systemctl enable splashscreen.service
systemctl enable splashscreen180.service
systemctl enable splashscreen_updating.service
systemctl enable splashscreen_updating180.service

systemctl enable candle_hostname_fix.service # ugly solution, might not even be necessary anymore? Nope, tested, still needed.

# enable BlueAlsa services
systemctl enable bluealsa.service 
systemctl enable bluealsa-aplay.service 

# Webthings Gateway
systemctl enable webthings-gateway.service
systemctl disable webthings-gateway.check-for-update.service
systemctl disable webthings-gateway.check-for-update.timer
systemctl disable webthings-gateway.update-rollback.service



# KIOSK

# Download boot splash images and video
echo " "
echo "DOWNLOADING CANDLE SPLASH IMAGES AND VIDEO"
echo " "
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



#mkdir -p /etc/X11/xinit
#mkdir -p /etc/xdg/openbox

if [ ! -d "/etc/xdg/openbox" ]
then
    echo "missing dir: /etc/xdg/openbox"
    mkdir -p /etc/xdg/openbox
fi

# Disable Openbox keyboard shortcuts to make the kiosk mode harder to escape
#rm /etc/xdg/openbox/rc.xml
#wget https://www.candlesmarthome.com/tools/rc.xml /etc/xdg/openbox/rc.xml

# Modify the xinitrc file to automatically log in the pi user
echo "- Creating xinitrc file"
echo 'exec openbox-session' > /etc/X11/xinit/xinitrc

echo "- Creating xwrapper.config file"
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config






# CHROMIUM 

# Add policy file to disable things like file selection
mkdir -p /etc/chromium/policies/managed/
echo '{"AllowFileSelectionDialogs": false, "AudioCaptureAllowed": false, "AutoFillEnabled": false, "PasswordManagerEnabled": false}' > /etc/chromium/policies/managed/candle.json





# ADD IP-TABLES
echo " "
echo "ADDING IPTABLES"
echo "before:"
iptables -t nat --list
echo " "
echo "Redirecting :80 to :8080 and :443 to :4443"
echo " "

if iptables --list | grep 4443; then
    echo "IPTABLES ALREADY ADDED"
else
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-mark 1
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j MARK --set-mark 1
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4443
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -m mark --mark 1 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 4443 -m mark --mark 1 -j ACCEPT
fi

#iptables -L -v -n
echo "after"
iptables -t nat --list

#echo "\n\n" | apt install iptables-persistent -y
#apt install iptables-persistent -y


# TODO:

# ~/.config/configstore/update-notifier-npm.json <- set output to true
# Respeaker drivers?

# update python libraries except for 2 (schemajson and... )
# pip3 list --outdated
# not to be updated:
# - websocket-client
# - jsonschema (if memory serves)

# RASPI CONFIG

# enable i2c, needed for clock module support
raspi-config nonint do_i2c 0

# enable SPI
raspi-config nonint do_spi 0

# enable Camera.
raspi-config nonint do_camera 0

# enable old Camera.
#raspi-config nonint do_legacy 0




# CLEANUP

# remove no longer needed applications?
# apt-get purge libtool

# disable swap file
dphys-swapfile swapoff

apt clean
apt autoremove
rm -rf /tmp/*
rm /home/pi/install.sh

echo "candle" > /etc/hostname
echo "candle" > /home/pi/.webthings/etc/hostname



cd /home/pi/webthings/gateway
sudo -u pi /home/pi/webthings/gateway/run-app.sh &




echo " "
echo "ALMOST DONE!"
echo "Starting controller for testing"
echo "In a few seconds you should be able to open http://candle.local in your browser."
echo " "