# Designed to turn a Webthings disk image into a Candle disk image
# This script assumess that all the files have already been copied into place


# MANAGE INSTALLED APPLICATIONS

apt-get install fbi nbtscan openbox



# Just to be safe, although it should already be installed:
apt-get install omxplayer


# MAKE DIRECTORIES
mkdir /home/pi/.webthings/etc
mkdir /home/pi/.webthings/var/lib
mkdir /home/pi/.webthings/tmp

mkdir /home/pi/.webthings/arduino/.arduino15
mkdir /home/pi/.webthings/arduino/Arduino


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
systemd disable webthings-gateway.check-for-update.service
systemd disable webthings-gateway.check-for-update.timer
systemd disable webthings-gateway.update-rollback.service

systemd enable candle_first_run.service
systemd enable candle_reset.service
systemd enable candle_start_swap.service



# TODO:
# build and install BlueAlsa with legaly safe codes and built-in audio mixing
# directory ownership and permissions
# install openbox. And disable its shorcuts.

# LONG TERM TODO?
# copy IP routes and other setup/settings from Webthings disk image creation? That way only one install script needs to be run instead of a waterfall model.
