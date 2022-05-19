


mkdir /home/pi/.webthings/etc/

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

cp -r /etc/ssh /home/pi/.webthings/etc/ssh
cp -r /etc/wpa_supplicant /home/pi/.webthings/etc/wpa_supplicant/


# SERVICES
systemd disable webthings-gateway.check-for-update.service
systemd disable webthings-gateway.check-for-update.timer
systemd disable webthings-gateway.update-rollback.service

# TODO:
# - enable systemd services
# - disable webthings 
