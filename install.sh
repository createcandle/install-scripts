# Designed to turn a Webthings disk image into a Candle disk image
# This script assumess that all the files have already been copied into place from https://github.com/createcandle/configuration-scripts


# MANAGE INSTALLED APPLICATIONS

apt-get install fbi nbtscan openbox

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



# disable Openbox keyboard shortcuts to make the kiosk mode harder to escape
wget https://www.candlesmarthome.com/tools/rc.xml -P /etc/xdg/openbox/rc.xml

# CHROMIUM 

# Add policy file to disable things like file selection
mkdir -p /etc/chromium/policies/managed/
echo '{"AllowFileSelectionDialogs": false, "AudioCaptureAllowed": false}' > /etc/chromium/policies/managed/candle.json





# TODO:
# RASPI-CONFIG
# - Enabled SPI 
# - Enabled I2C

# Respeaker drivers?

# update python libraries except for 2 (schemajson and... )
# directory ownership and permissions
# install openbox. And disable its shortcuts. See original kiosk install script: https://www.candlesmarthome.com/tools/kiosk.txt

# LONG TERM TODO?
# Go 64 bit?
# Copy IP routes and other setup/settings from Webthings disk image creation? That way only one install script needs to be run instead of a waterfall model.
