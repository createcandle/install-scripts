#!/bin/bash
set +e # continue on errors


# CANDLE INSTALL AND UPDATE SCRIPT

# This script will turn a Raspberry Pi OS Lite installation into a Candle controller
# It can also update a Candle controller to the latest available version (with some limitations)

# If you want to avoid the shutdown at the end you can skip the finalization step by first setting an environment variable:
# export STOP_EARLY=yes

# If STOP_EARLY is set, then you also have the option to ask the script to reboot when done. This is useful if it's acting as an update script.
# export REBOOT_WHEN_DONE=yes

# Other parts of the script that can be skipped:
# export SKIP_PARTITIONS=yes
# export SKIP_APT_INSTALL=yes
# export SKIP_APT_UPGRADE=yes
# export SKIP_PYTHON=yes
# export SKIP_RESPEAKER=yes
# export SKIP_BLUEALSA=yes
# export SKIP_CONTROLLER_INSTALL=yes
# export SKIP_DEBUG=yes

# The script can add the re-install option to every Apt install command.
# export APT_REINSTALL=yes

# To skip the creation of the read-only mode:
# export SKIP_RO=yes

# If you also want this script to download all the installed packages' as .deb files, then set this environment variable:
# export DOWNLOAD_DEB=yes

# An indicator that the script is inside chroot. Now used less i favour of more finegrained control over turning of parts of the script.
# export CHROOTED=yes


# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

if [ -f /proc/mounts ]; 
then
    # Detect is read-only mode is active
    if [ ! -z "$(grep "[[:space:]]ro[[:space:],]" /proc/mounts | grep ' /ro ')" ]; then
      echo 
      echo "Detected read-only mode. Create /boot/candle_rw_once.txt, reboot, and then try again."
      echo "Candle: detected read-only mode. Aborting." >> /dev/kmsg
  
      # Show error image
      if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
        /bin/ply-image /boot/error.png
        sleep 7200
      fi
  
      exit 1
    fi
fi


# Detect if old overlay system is active

if [ -f /boot/cmdline.txt ]; then
    if grep -q "boot=overlay" /boot/cmdline.txt; then
        echo 
        echo "Detected the OLD raspi-config read-only overlay. Disable it under raspi-config -> performance (and then reboot)"
        echo "Candle: detected OLD read-only mode. Aborting." >> /dev/kmsg

        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
            /bin/ply-image /boot/error.png
            sleep 7200
        fi

        exit 1
    fi
fi
echo

# Detect if a kernel or bootloader update has just occured. If so, the system must be rebooted first.

if [ -f /usr/sbin/iptables ];then
    if [ -z "$(iptables -L -v -n)" ]; then
        echo "ERROR, IP tables gave no output, suggesting that a bootloader or kernel update has taken place. Please reboot first."
        echo "ERROR, IP tables gave no output, suggesting that a bootloader or kernel update has taken place. Please reboot first." >> /dev/kmsg
        echo "$(date) - it seems a bootloader or kernel update has taken place. Please reboot first." >> /dev/kmsg
    
        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
            /bin/ply-image /boot/error.png
            sleep 7200
        fi
    
        exit 1
    else
        echo "No recent kernel update detected"
    fi
fi

if [ ! -f /boot/cmdline.txt ]; then
    echo "ERROR, missing cmdline.txt??" >> /dev/kmsg
    exit 1
fi




# OUTPUT SOME INFORMATION

cd /home/pi

echo
echo "CREATING CANDLE"
echo
echo "DATE         : $(date)"
echo "IP ADDRESS   : $(hostname -I)"
echo "PATH         : $PATH"
echo "USER         : $(whoami)"

scriptname=$(basename "$0")
echo "NAME         : $scriptname"

if [ -f /boot/candle_cutting_edge.txt ]; then
echo "CUTTING EDGE : yes"
else
echo "CUTTING EDGE : no"
fi

if [[ -z "${APT_REINSTALL}" ]] || [ "$APT_REINSTALL" = no ] ; then
    echo "APT REINST  : no"
else
    reinstall="--reinstall"
    echo "APT REINST  : yes"
fi

if [ "$CHROOTED" = no ] || [[ -z "${CHROOTED}" ]]; then
echo "CHROOT     : Not in chroot"
else
echo "CHROOT     : INSIDE CHROOT (boot partition is not mounted)"
fi

echo
echo "reinstall flag: $reinstall"



# ADDITIONAL SANITY CHECKS

if [ ! -s /etc/resolv.conf ]; then
    # no nameserver
    echo "no nameserver, aborting"
    echo "Candle: no nameserver, aborting" >> /dev/kmsg
    exit 1
fi




# CREATE PARTITIONS

if [ ! -d /home/pi/.webthings/addons ] && [[ -z "${SKIP_PARTITIONS}" ]]; 
then
    
    #if [ -f /dev/mmcblk0p4 ]; then
    if lsblk | grep -q 'mmcblk0p3'; then
        echo
        echo "partitions already created:"
    else
        #if ls /dev/mmcblk0p2; then
        #if [ -f /dev/mmcblk0p2 ]; then
        if lsblk | grep -q 'mmcblk0p2'; then
            
            echo
            echo "CREATING PARTITIONS"
            echo "Candle: creating partitions" >> /dev/kmsg
            echo

            printf "resizepart 2 7000\nmkpart\np\next4\n7001MB\n7500MB\nmkpart\np\next4\n7502MB\n14000MB\nquit" | parted
            resize2fs /dev/mmcblk0p2
            #printf "y" | mkfs.ext4 /dev/mmcblk0p3
            printf "y" | mkfs.ext4 /dev/mmcblk0p4
            mkdir -p /home/pi/.webthings
            chown pi:pi /home/pi/.webthings
            touch /boot/candle_has_4th_partition.txt
        else
            echo
            echo "Partition 2 was missing. Inside chroot?"
            echo
        fi
    fi
    
    sleep 5
    
    if ls /dev/mmcblk0p4; then
        echo "Mounting /dev/mmcblk0p4 to /home/pi/.webthings"
        mount /dev/mmcblk0p4 /home/pi/.webthings
        chown pi:pi /home/pi/.webthings
    else
        echo "Error, /dev/mmcblk0p4 was missing. Exiting."
        exit
    fi
    
    lsblk
    
else
    echo "Partitions seem to already exist (addons dir existed)"
    echo "Candle: Partitions seem to already exist (addons dir existed)" >> /dev/kmsg
fi

echo

if [ -f /zero.fill ]; then
  rm /zero.fill
  echo "removed /zero.fill"
fi
if [ -f /home/pi/.webthings/zero.fill ]; then
  rm /home/pi/.webthings/zero.fill
  echo "removed /home/pi/.webthings/zero.fill"
fi

sleep 3


# make sure there is a current time
if [ -f /boot/candle_hardware_clock.txt ]; then
    rm /boot/candle_hardware_clock.txt
    systemctl restart systemd-timesyncd.service
    timedatectl set-ntp true
    sleep 2
    /usr/sbin/fake-hwclock save
    echo "Candle: requested latest time. Date is now: $(date)" >> /dev/kmsg
fi




# Download error image first
if [ -f /boot/cmdline.txt ]; then
    wget https://www.candlesmarthome.com/tools/error.png -O /boot/error.png
    if [ ! -f /boot/error.png ]; then
        echo "ERROR, download of error.png failed." >> /dev/kmsg
        exit 1
    fi      
fi







# INSTALL PROGRAMS AND UPDATE
if [ "$SKIP_APT_INSTALL" = no ] || [[ -z "${SKIP_APT_INSTALL}" ]];
then
    echo
    echo "INSTALLING APPLICATIONS AND LIBRARIES"
    echo "Candle: installing packages and libraries" >> /dev/kmsg
    echo

    set -e
    echo "calling apt update"
    apt update -y
    apt-get update -y
    apt --fix-broken install
    echo
    
    
    # Add option to download source code from RaspberryPi server
    
    echo "modifying /etc/apt/sources.list - allowing apt access to source code"
    sed -i 's/#deb-src/deb-src/' /etc/apt/sources.list
    
    
    if apt list --upgradable | grep raspberrypi-bootloader; then
        echo "WARNING, BOOTLOADER IS UPGRADEABLE"
        echo "WARNING, BOOTLOADER IS UPGRADEABLE" >> /dev/kmsg
    fi
    
    if apt list --upgradable | grep raspberrypi-kernel; then
        echo "WARNING, KERNEL IS UPGRADEABLE"
        echo "WARNING, KERNEL IS UPGRADEABLE" >> /dev/kmsg
    fi
    
    # Set kernel to not automatically upgrade, but only during disk image creation
    # Afterwards the power settings addon should handle this.
    if [ ! -f /boot/candle_first_run_complete.txt ]; then
        
        echo "/boot/candle_first_run_complete.txt does not exist yet"
        
        if [ ! -f /boot/candle_cutting_edge.txt ]; then
            echo "Settting kernel to not automatically upgrade."
            apt-mark hold raspberrypi-kernel
            apt-mark hold raspberrypi-bootloader
        else
            echo
            echo
            echo "candle_cutting_edge.txt detected. Updating kernel and bootloader, and then rebooting."
            echo
            if [ -n "$(apt list --upgradable | grep raspberrypi-kernel)"  ] || [ -n "$(apt list --upgradable | grep raspberrypi-bootloader)" ]; then
                
                wget https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle.sh -O /home/pi/create_latest_candle.sh
                chmod +x /home/pi/create_latest_candle.sh
                apt install -y raspberrypi-kernel
                apt install -y raspberrypi-bootloader
                echo
                echo "Rebooting in 10 seconds... ($(date))"
                echo "Hostname: $(cat /etc/hostname)"
                echo
                sleep 10
                reboot now
            fi
        fi
    fi
    
    echo
    if [ "$SKIP_APT_UPGRADE" = no ] || [[ -z "${SKIP_APT_UPGRADE}" ]]; 
    then
        echo "calling apt upgrade"
        echo "Candle: doing apt upgrade" >> /dev/kmsg
        #apt DEBIAN_FRONTEND=noninteractive upgrade -y
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y &
        wait
        echo
        echo "Upgrade complete"
    fi

    set +e

    # Install browser. Unfortunately its chromium, and not firefox, because its so much better at being a kiosk, and so much more customisable.
    # TODO: maybe use version 88?
    echo
    echo "installing chromium-browser"
    echo "Candle: installing chromium-browser" >> /dev/kmsg
    echo
    apt install chromium-browser -y --print-uris --allow-change-held-packages "$reinstall"

    if [ ! -f /bin/chromium-browser ]; then
        echo
        echo "browser install failed, retrying."
        apt purge chromium-browser -y
        apt install chromium-browser -y --allow-change-held-packages
    fi

    echo
    echo "installing vlc"
    apt -y install vlc --print-uris --no-install-recommends "$reinstall"

    #echo 'deb http://download.opensuse.org/repositories/home:/ungoogled_chromium/Debian_Bullseye/ /' | sudo tee /etc/apt/sources.list.d/home-ungoogled_chromium.list > /dev/null
    #curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Debian_Bullseye/Release.key' | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home-ungoogled_chromium.gpg > /dev/null
    #apt update
    #apt install ungoogled-chromium -y

    echo
    echo "installing git"
    echo "Candle: installing git" >> /dev/kmsg
    echo
    apt -y install git "$reinstall" 

    echo
    echo "installing build tools"
    for i in autoconf build-essential curl libbluetooth-dev libboost-python-dev libboost-thread-dev libffi-dev \
        libglib2.0-dev libpng-dev libcap2-bin libudev-dev libusb-1.0-0-dev pkg-config lsof python-six; do
        
        echo "$i"
        apt  -y install "$i"  --print-uris "$reinstall"
        echo
    done


    # remove the Candle conf file, just in case it exists from an earlier install attempt
    if [ -f /etc/mosquitto/mosquitto.conf ]; then
      rm /etc/mosquitto/mosquitto.conf
    fi

    echo
    echo "installing support packages like ffmpeg, arping, libolm, sqlite, mosquitto"
    echo "Candle: installing support packages" >> /dev/kmsg
    echo
    for i in arping autoconf ffmpeg libtool mosquitto policykit-1 sqlite3 libolm3 libffi6 nbtscan ufw iptables; do
        echo "$i"
        echo "Candle: installing $i" >> /dev/kmsg
        apt -y install "$i"  --print-uris "$reinstall" 
        echo
    done

    # Quick sanity check
    if [ ! -f /usr/sbin/mosquitto ]; then
        echo "ERROR, mosquitto failed to install the first time" >> /dev/kmsg
        apt -y --reinstall install mosquitto  
    fi
    

    # removed from above list:
    #  libnanomsg-dev \
    #  libnanomsg5 \

    # additional programs for Candle kiosk mode:
    echo
    echo "installing kiosk packages (x, openbox)"
    echo
    for i in xinput xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools; do
        echo "$i"
        echo "Candle: installing $i" >> /dev/kmsg
        apt-get -y --no-install-recommends install "$i" --print-uris "$reinstall" 
        echo
    done
    
    #apt-get install --no-install-recommends xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools nbtscan -y


    # OMPLAYER
    # This player is deprecated, but Internet Radio currently still uses it (and perhaps other addons too). So here's an attempts to get it working again.
    # The way forward is for all these addons to switch to VLC player

    # get OMXPlayer for Internet Radio
    # http://archive.raspberrypi.org/debian/pool/main/o/omxplayer/

    echo
    echo "installing omxplayer"
    for i in liblivemedia-dev libavcodec58 libavutil56 libswresample3 libavformat58; do
        echo "$i"
        echo "Candle: installing $i" >> /dev/kmsg
        apt-get -y install $i --print-uris "$reinstall"
        echo
    done
    #apt install liblivemedia-dev libavcodec58 libavutil56 libswresample3 libavformat58 -y

    apt --fix-broken install -y

    wget http://archive.raspberrypi.org/debian/pool/main/o/omxplayer/omxplayer_20190723+gitf543a0d-1+bullseye_armhf.deb -O ./omxplayer.deb
    if [ -f ./omxplayer.deb ]; then
        dpkg -i ./omxplayer.deb
        rm -rf ./omxplayer*

        #apt --fix-broken install -y

        mkdir -p /opt/vc/
        wget https://www.candlesmarthome.com/tools/lib.tar -O ./lib.tar # files from https://github.com/raspberrypi/firmware/tree/master/opt/vc/lib
        if [ -f ./lib.tar ]; then
            tar -xvf lib.tar -C /opt/vc/
            rm ./lib.tar
        else
            echo "ERROR DOWNLOAD OMXPLAYER LIB.TAR FROM CANDLE SERVER" >> /dev/kmsg
        fi
    else
        echo "ERROR, OMXPLAYER .DEB DOWNLOAD FAILED" >> /dev/kmsg
    fi

    # for BlueAlsa
    echo "installing bluealsa support packages"
    for i in libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev; do
        echo "$i"
        echo "Candle: installing $i" >> /dev/kmsg
        apt -y install "$i" --print-uris "$reinstall" 
        echo
    done
    #apt install libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev -y


    # Camera support
    for i in python3-libcamera python3-kms++ python3-prctl libatlas-base-dev libopenjp2-7; do
        echo "$i"
        echo "Candle: installing $i" >> /dev/kmsg
        apt -y install "$i"  --print-uris "$reinstall"
        echo
    done
    
    echo
    echo "INSTALLING HOSTAPD AND DNSMASQ"
    echo "Candle: installing hostapd and dnsmasq" >> /dev/kmsg

    apt -y install dnsmasq  --print-uris "$reinstall" 
    systemctl disable dnsmasq.service
    systemctl stop dnsmasq.service

    echo 
    apt -y install hostapd  --print-uris "$reinstall"
    systemctl disable hostapd.service
    systemctl stop hostapd.service
    

    # Try to fix anything that may have gone wrong
    apt update
    apt-get update --fix-missing -y
    apt-get install -f -y
    apt --fix-broken install -y
    apt autoremove -y
    
    
    for i in \
    chromium-browser git \
    autoconf build-essential curl libbluetooth-dev libboost-python-dev libboost-thread-dev libffi-dev \
        libglib2.0-dev libpng-dev libcap2-bin libudev-dev libusb-1.0-0-dev pkg-config lsof python-six \
    arping autoconf ffmpeg libtool mosquitto policykit-1 sqlite3 libolm3 libffi6 nbtscan ufw iptables \
    liblivemedia-dev libavcodec58 libavutil56 libswresample3 libavformat58 \
    libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev \
    python3-libcamera python3-kms++ python3-prctl libatlas-base-dev libopenjp2-7;
    do
        echo
        if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
            echo "$i installed OK"
        else
            echo
            echo "ERROR, $i did not install ok"
            dpkg -s "$i"
            
            echo
            echo "Trying to install it again..."
            apt -y purge"$i"
            sleep 2
            apt -y install "$i"
            
            echo
            if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
                echo "$i installed OK"
            else
                echo
                echo "ERROR, $i package still did not install. Aborting..." >> /dev/kmsg
                dpkg -s "$i"
                
                # Show error image
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
                    /bin/ply-image /boot/error.png
                    sleep 7200
                fi
    
                exit 1
            fi
        fi
    done
    
    
    # again, but this time with 'no-install-recommends'
    for i in \
    vlc \
    xinput xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools;
    do
        echo
        if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
            echo "$i installed OK"
        else
            echo
            echo "ERROR, $i did not install ok"
            dpkg -s "$i"
            
            echo
            echo "Trying to install it again..."
            apt -y purge "$i"
            sleep 2
            apt -y --no-install-recommends install "$i"
            
            echo
            if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
                echo "$i installed OK"
            else
                echo
                echo "ERROR, $i package still did not install. Aborting..." >> /dev/kmsg
                dpkg -s "$i"
                
                # Show error image
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
                    /bin/ply-image /boot/error.png
                    sleep 7200
                fi
    
                exit 1
            fi
        fi
    done
    
fi



if [ "$SKIP_APT_UPGRADE" = no ] || [[ -z "${SKIP_APT_UPGRADE}" ]]; 
then
    echo
    echo "RUNNING APT UPGRADE"
    echo
    #apt upgrade -y
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt upgrade -y &
    wait
    echo ""
    echo "calling autoremove"
    apt autoremove -y
fi





# SANITY CHECKS

# Check if GIT installed succesfully
dpkg -s git &> /dev/null
if [ $? -eq 0 ]; then
    echo "git installed succesfully"
else
    echo
    echo "ERROR"
    echo
    echo "Error detected in the packages install phase (git is missing). Try running the Candle install script again."
    echo ""
    echo "Candle: error GIT failed to install" >> /dev/kmsg
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
        /bin/ply-image /boot/error.png
        sleep 7200
    fi
    
    exit 1
fi


# Check if browser installed succesfully
dpkg -s chromium-browser &> /dev/null
if [ $? -eq 0 ]; then
    echo "browser installed succesfully"
else
    echo
    echo "ERROR"
    echo
    echo "Error detected in the packages install phase (browser is missing). Try running the Candle install script again."
    echo ""
    echo "Candle: error browser failed to install" >> /dev/kmsg
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
        /bin/ply-image /boot/error.png
        sleep 7200
    fi
    
    exit 1
fi




# PYTHON
if [ "$SKIP_PYTHON" = no ] || [[ -z "${SKIP_PYTHON}" ]];
then
    echo
    echo "INSTALLING AND UPDATING PYTHON PACKAGES"
    echo

    echo
    echo "installing pip3"
    echo
    apt install -y python3-pip

    # update pip
    #sudo -u pi /usr/bin/python3 -m pip install --upgrade pip

    # upgrade pip first
    sudo -u pi python3 -m pip install --upgrade pip

    sudo -u pi pip3 uninstall -y adapt-parser || true
    sudo -u pi pip3 install dbus-python pybluez pillow pycryptodomex numpy

    if [ -d "/home/pi/.local/bin" ] ; then
        echo "adding /home/pi/.local/bin to path"
        PATH="/home/pi/.local/bin:$PATH"
    else
        echo "ERROR, /home/pi/.local/bin does not exist"
    fi

    echo "Updating existing python packages"
    sudo -u pi pip install --upgrade certifi chardet colorzero dbus-python distro requests RPi.GPIO ssh-import-id urllib3 wheel libevdev

    echo "Installing Python gateway_addon"
    sudo -u pi python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon
fi




# RASPI CONFIG
echo "Set Raspi-config I2C, SPI, Camera"

if [ -d /sys/kernel/config/device-tree ];
then
    # enable i2c, needed for clock module support
    raspi-config nonint do_i2c 0

    # enable SPI
    raspi-config nonint do_spi 0

    # enable Camera.
    raspi-config nonint do_camera 0 # This does nothing on Bullseye, but is needed for older versions of Raspberry Pi OS

    # enable old Camera.
    #raspi-config nonint do_legacy 0
else
    echo "Raspi-config setting skipped: missing device tree. In chroot?"
fi






# RESPEAKER HAT
if [ "$SKIP_RESPEAKER" = no ] || [[ -z "${SKIP_RESPEAKER}" ]];
then
    echo
    echo "INSTALLING RESPEAKER HAT DRIVERS"
    echo
    
    apt-get update
    cd /home/pi
    git clone --depth 1 https://github.com/HinTak/seeed-voicecard.git
    
    if [ -d seeed-voicecard ]; then
        cd seeed-voicecard
    
        if [ ! -f /home/pi/candle/installed_respeaker_version.txt ]; then
            touch /home/pi/candle/installed_respeaker_version.txt
        fi
    
        if [ -d "/etc/voicecard" ] && [ -f /bin/seeed-voicecard ];
        then
            echo "ReSpeaker was already installed"
        
            if ! diff -q ./dkms.conf /home/pi/candle/installed_respeaker_version.txt &>/dev/null; then
                ./uninstall.sh
                echo -e 'N\n' | ./install.sh
            fi
        
            cp ./dkms.conf /home/pi/candle/installed_respeaker_version.txt
        
        else
            echo "Doing initial ReSpeaker install"
            echo -e 'N\n' | ./install.sh
        fi
        
        cd /home/pi
        rm -rf seeed-voicecard
        
    else
        echo "Error, failed to download respeaker source"
    fi
    
    
    
fi




# BLUEALSA
if [ "$SKIP_BLUEALSA" = no ] || [[ -z "${SKIP_BLUEALSA}" ]];
then
    
    echo
    echo "INSTALLING BLUEALSA BLUETOOTH SPEAKER DRIVERS"
    echo
    
    adduser --system --group --no-create-home bluealsa
    adduser --system --group --no-create-home bluealsa-aplay
    adduser bluealsa audio
    adduser bluealsa bluetooth
    adduser bluealsa-aplay audio

    #usermod -a -G bluetooth bluealsa 
    #usermod -a -G audio bluealsa 
    #usermod -a -G audio bluealsa-aplay
    
    # compile and install BlueAlsa with legaly safe codes and built-in audio mixing
    git clone --depth 1 https://github.com/createcandle/bluez-alsa.git
    
    if [ -d bluez-alsa ]; then
        echo "generating bluealsa from source"
        cd bluez-alsa
        autoreconf --install --force
        mkdir build
        cd build 
        ../configure --enable-msbc --enable-mp3lame --enable-faststream --enable-systemd
        make
        make install
    else
        echo "Error, Failed to download bluealsa source from github"
    fi

else
    echo "Skipping BlueAlsa build"
fi

cd /home/pi
rm -rf bluez-alsa




# PLYMOUTH LITE
if [ ! -f /bin/ply-image ]; 
then
    echo
    echo "creating Plymouth lite"
    echo
    git clone --depth 1 https://github.com/T4d3o/Plymouth-lite.git
    cd Plymouth-lite
    ./configure
    make
    cp ply-image /usr/bin

    cd /home/pi
    rm -rf Plymouth-lite
fi

# sudo update-rc.d gateway-iptables defaults

# TODO: also need to look closer at this: https://github.com/WebThingsIO/gateway/tree/37591f4be3542901255da3c901396f3e9b8a443b/image/etc




# INSTALL CANDLE CONTROLLER
if [[ -z "${SKIP_CONTROLLER_INSTALL}" ]] || [ "$SKIP_CONTROLLER_INSTALL" = no ]; 
then
    
    echo
    echo "INSTALLING CANDLE CONTROLLER"
    echo "Candle: starting installing of candle controller" >> /dev/kmsg
    echo

    cd /home/pi
    rm -rf /home/pi/webthings
    #rm -rf /home/pi/.webthings # too dangerous
    
    
    
    if [ -f /boot/candle_cutting_edge.txt ]; then
        wget https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh -O ./install_candle_controller.sh
    else
        curl -s https://api.github.com/repos/createcandle/install-scripts/releases/latest \
        | grep "tarball_url" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O install-scripts.tar

        tar -xf install-scripts.tar
        rm install-scripts.tar
        
        for directory in createcandle-install-scripts*; do
          [[ -d $directory ]] || continue
          echo "Directory: $directory"
          mv -- "$directory" ./install-scripts
        done
        
        mv ./install-scripts/install_candle_controller.sh ./install_candle_controller.sh
        rm -rf ./install-scripts
        #echo
        #echo "result:"
        #ls install_candle_controller.sh
    fi
    
    
    # Check if the install_candle_controller.sh file now exists
    if [ ! -f install_candle_controller.sh ]; then
        echo
        echo "ERROR, missing install_candle_controller.sh file"
        echo "$(date) - Failed to download install_candle_controller script" >> /boot/candle_log.txt
        echo
        
        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
            /bin/ply-image /boot/error.png
            sleep 7200
        fi
        
        exit 1
    fi
    
    chmod +x ./install_candle_controller.sh
    sudo -u pi ./install_candle_controller.sh
    wait
    rm ./install_candle_controller.sh

    cd /home/pi

    # This should work now, but setcap has been move to install_candle_controller script instead
    #NODE_PATH=$(sudo -i -u pi which node)
    #setcap cap_net_raw+eip $(eval readlink -f "$NODE_PATH")
    
    # Check if the installation of the controller succeeded
    
    if [ -d /ro ]; then
        if [ ! -f /ro/home/pi/webthings/gateway/.post_upgrade_complete ]; then
            echo 
            echo "ERROR, failed to (fully) install candle-controller (/ro)"
            echo "ERROR, failed to (fully) install candle-controller (/ro)" >> /dev/kmsg
            echo

            # Show error image
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
                /bin/ply-image /boot/error.png
                sleep 7200
            fi

            exit 1
        fi
    elif [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ]; then
    
        echo 
        echo "ERROR, failed to (fully) install candle-controller"
        echo "ERROR, failed to (fully) install candle-controller" >> /dev/kmsg
        echo

        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
            /bin/ply-image /boot/error.png
            sleep 7200
        fi

        exit 1
    fi
    
fi








echo
echo "INSTALLING OTHER FILES AND SERVICES"
echo


# Download splash images
if [ -f /boot/cmdline.txt ]; then
    wget https://www.candlesmarthome.com/tools/error.png -O /boot/error.png
    echo
    echo "Candle: downloading splash images and videos" >> /dev/kmsg
    echo
    wget https://www.candlesmarthome.com/tools/splash.png -O /boot/splash.png
    wget https://www.candlesmarthome.com/tools/splash180.png -O /boot/splash180.png
    wget https://www.candlesmarthome.com/tools/splashalt.png -O /boot/splashalt.png
    wget https://www.candlesmarthome.com/tools/splash180alt.png -O /boot/splash180alt.png
    wget https://www.candlesmarthome.com/tools/splash_updating.png -O /boot/splash_updating.png
    wget https://www.candlesmarthome.com/tools/splash_updating180.png -O /boot/splash_updating180.png
    
    wget https://www.candlesmarthome.com/tools/splash.mp4 -O /boot/splash.mp4
    wget https://www.candlesmarthome.com/tools/splash180.mp4 -O /boot/splash180.mp4    
fi


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

touch /home/pi/.webthings/candle.log
chown pi:pi /home/pi/.webthings/candle.log

if [ ! -d /home/pi/.webthings/etc ]; then
    mkdir -p /home/pi/.webthings/etc
    chown pi:pi /home/pi/.webthings/etc
fi

mkdir -p /home/pi/candle
chown pi:pi /home/pi/candle

mkdir -p /var/run/mosquitto/
chown mosquitto: /var/run/mosquitto
chmod 755 /var/run/mosquitto

# Make folders that should be owned by root
mkdir -p /home/pi/.webthings/var/lib/bluetooth
mkdir -p /home/pi/.webthings/etc/wpa_supplicant
mkdir -p /home/pi/.webthings/etc/ssh



#echo "Candle: moving and copying directories so fstab works" >> /dev/kmsg




if [ ! -d /home/pi/.webthings/tmp ]; then
    mkdir -p /home/pi/.webthings/tmp
    rm -rf /tmp/*
    echo "cleared /tmp contents:"
    ls -l -a /tmp
    cp -r /tmp/* /home/pi/.webthings/tmp
fi
chmod 1777 /home/pi/.webthings/tmp
find /home/pi/.webthings/tmp \
     -mindepth 1 \
     -name '.*-unix' -exec chmod 1777 {} + -prune -o \
     -exec chmod go-rwx {} +




# COPY FILES

cd /home/pi

if [ -e /home/pi/webthings/gateway/static/images/floorplan.svg ];
then
    cp /home/pi/webthings/gateway/static/images/floorplan.svg /home/pi/.webthings/floorplan.svg
    chown pi:pi /home/pi/.webthings/floorplan.svg
else
    echo ""
    echo "ERROR: missing floorplan"
    echo ""
fi

# SYMLINKS

# move hosts file to user partition
#if [ ! -f /boot/candle_first_run_complete.txt ]; then
#    cp --verbose /etc/hosts /home/pi/.webthings/etc/hosts
#    sed -i -E "s|127.0.1.1\s+candle|127.0.1.1        $(cat /home/pi/.webthings/etc/hostname)|g" /home/pi/.webthings/etc/hosts
#fi


# move timezone file to user partition
if [ ! -f /home/pi/.webthings/etc/timezone ]; then
    echo "copying /etc/timezone to /home/pi/.webthings/etc/timezone"
    cp --verbose /etc/timezone /home/pi/.webthings/etc/timezone
fi

#creating symlink for timezone
if [ ! -L /etc/timezone ]; then
    echo "removing /etc/timezone file and creating a symlink to /home/pi/.webthings/etc/timezone instead"
    rm /etc/timezone
    ln -s /home/pi/.webthings/etc/timezone /etc/timezone
fi

# create fake-hwclock file
if [ ! -f /home/pi/.webthings/etc/fake-hwclock.data ]; then
    echo "copying /etc/fake-hwclock.data to /home/pi/.webthings/etc/fake-hwclock.data"
    cp --verbose /etc/fake-hwclock.data /home/pi/.webthings/etc/fake-hwclock.data
fi

# create symlink for fake-hwclock
if [ ! -L /etc/fake-hwclock.data ]; then
    echo "removing /etc/fake-hwclock.data file and creating a symlink to /home/pi/.webthings/etc/fake-hwclock.data instead"
    rm /etc/fake-hwclock.data
    ln -s /home/pi/.webthings/etc/fake-hwclock.data /etc/fake-hwclock.data
fi

# PREPARE FOR BINDS IN FSTAB
echo "generating ssh, wpa_supplicant and bluetooth folders on user partition"

#cp --verbose -r /etc/ssh /home/pi/.webthings/etc/
if [ ! -f /home/pi/.webthings/etc/ssh/ssh_config ]; then
    cp --verbose /etc/ssh/ssh_config /home/pi/.webthings/etc/ssh/ssh_config
    cp --verbose /etc/ssh/sshd_config /home/pi/.webthings/etc/ssh/sshd_config
fi
#cp --verbose -r /etc/ssh/ssh_config.d /home/pi/.webthings/etc/ssh/
#cp --verbose -r /etc/ssh/sshd_config.d /home/pi/.webthings/etc/ssh/
mkdir -p /home/pi/.webthings/etc/ssh/ssh_config.d
mkdir -p /home/pi/.webthings/etc/ssh/sshd_config.d 


# Create "empty" wpa_supplicant config file if it doesn't exist yet
if [ ! -f /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf ]; then
    echo "Creating redirected wpa_supplicant file"
    mkdir -p /home/pi/.webthings/etc/wpa_supplicant
    cp --verbose -r /etc/wpa_supplicant/* /home/pi/.webthings/etc/wpa_supplicant
    #echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' | tee /etc/wpa_supplicant/wpa_supplicant.conf
    #echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' | tee /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
    echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' > /etc/wpa_supplicant/wpa_supplicant.conf
    echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' > /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
fi










# COPY SETTINGS

echo
echo "DOWNLOADING AND COPYING CONFIGURATION FILES FROM GITHUB"
echo "Candle: downloading configuration files from Github" >> /dev/kmsg
echo

if [ -d /home/pi/configuration-files ]; then
    echo "Warning, found a left over configuration-files directory"
    rm -rf /home/pi/configuration-files
fi

# Download ready-made settings files from the Candle github
git clone --depth 1 https://github.com/createcandle/configuration-files /home/pi/configuration-files


# Check if download succeeded
if [ ! -d /home/pi/configuration-files ]; then
    echo 
    echo "ERROR, failed to download latest configuration files"
    echo "ERROR, failed to download latest configuration files" >> /dev/kmsg
    echo "$(date) - failed to download latest configuration files" >> /boot/candle_log.txt
    echo
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
        /bin/ply-image /boot/error.png
        sleep 7200
    fi
    
    exit 1
else
    echo "Configuration files download succeeded"
    echo "Configuration files download succeeded" >> /dev/kmsg
fi

echo "Copying configuration files into place"
echo "Copying configuration files into place" >> /dev/kmsg
rsync -vr /home/pi/configuration-files/* /


#if [ ! -f /boot/candle_config_version.txt ]; then
#    touch /boot/candle_config_version.txt
#fi
#if ! diff -q /home/pi/configuration-files/boot/candle_config_version.txt /boot/candle_config_version.txt &>/dev/null; 
#then
#    echo "Different config version, intiating Rsync"
#    echo "Candle: Different config version, intiating Rsync" >> /dev/kmsg
#    rsync -vr /home/pi/configuration-files/* /
#else
#    echo "No new config version detected"
#fi

#chmod +x /home/pi/candle_first_run.sh



# CHMOD THE NEW FILES
chmod +x /home/pi/candle/early.sh
chmod +x /etc/rc.local
chmod +x /home/pi/candle/debug.sh
chmod +x /home/pi/candle/files_check.sh

# CHOWN THE NEW FILES
chown pi:pi /home/pi/*
chown -R pi:pi /home/pi/candle
chown -R pi:pi /home/pi/.config

chown pi:pi /home/pi/.webthings/etc/webthings_settings_backup.js
chown pi:pi /home/pi/.webthings/etc/webthings_settings.js
chown pi:pi /home/pi/.webthings/etc/webthings_tunnel_default.js

# ADD LINKS
if [ ! -L /home/pi/.asoundrc ]; then
    if [ -f /home/pi/.webthings/etc/asoundrc ]; then
        echo "Creating symlink from /home/pi/.asoundrc to /home/pi/.webthings/etc/asoundrc"
        rm /home/pi/.asoundrc
        ln -s /home/pi/.webthings/etc/asoundrc /home/pi/.asoundrc
    fi
fi
#chown mosquitto: /home/pi/.webthings/etc/mosquitto/zcandle.conf
#chown mosquitto: /home/pi/.webthings/etc/mosquitto/mosquitto.conf



# ENABLE SERVICES
echo
echo "ENABLING AND DISABLING SERVICES"
echo "Candle: enabling services" >> /dev/kmsg
echo
#systemctl daemon-reload

# disable triggerhappy. Wait, is this used to switch to the tty output?
#systemctl disable triggerhappy.socket
#systemctl disable triggerhappy.service

# enable Candle services
systemctl enable candle_first_run.service
#systemctl enable candle_bootup_actions.service
#systemctl enable candle_start_swap.service
systemctl enable candle_early.service
systemctl enable candle_late.service
systemctl enable candle_splashscreen.service
systemctl enable candle_splashscreen180.service
systemctl enable candle_reboot.service
systemctl enable candle_reboot180.service
systemctl enable candle_splashscreen_updating.service
systemctl enable candle_splashscreen_updating180.service
systemctl enable candle_hostname_fix.service # ugly solution, might not even be necessary anymore? Nope, tested, still needed.
# TODO: the candle_early script also seems to apply the hostname fix (and restart avahi-daemon). Then again, can't hurt to have redundancy.

# enable BlueAlsa services
systemctl enable bluealsa.service 
systemctl enable bluealsa-aplay.service 

# Webthings Gateway
systemctl enable webthings-gateway.service
systemctl disable webthings-gateway.check-for-update.service
systemctl disable webthings-gateway.check-for-update.timer
systemctl disable webthings-gateway.update-rollback.service

# disable apt services
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable apt-daily-upgrade.service

# disable man-db timer
systemctl disable man-db.timer

# enable half-hourly save of time
systemctl enable fake-hwclock-save.service

# Hide the login text (it will still be available on tty3 - connect a keyboard to your pi and press CTRl-ALT-F3 to see it)
systemctl enable getty@tty3.service
systemctl disable getty@tty1.service



# KIOSK

if [ -f /boot/config.txt ]; then

    # Hides the Raspberry Pi logos normally shown at boot

    if [ $(cat /boot/config.txt | grep -c "disable_splash") -eq 0 ];
    then
    	echo "- Adding disable_splash to config.txt"
    	echo 'disable_splash=1' >> /boot/config.txt
    else
        echo "- Splash was already disabled in config.txt"
    fi

    # add HDMI always on
    if [ $(cat /boot/config.txt | grep -c "hdmi_force_hotplug") -eq 0 ];
    then
    	echo "- Adding hdmi_force_hotplug=1 to config.txt"
    	echo 'hdmi_force_hotplug=1' >> /boot/config.txt
    else
        echo "- hdmi_force_hotplug was already in config.txt"
        if [ $(cat /boot/config.txt | grep -c "#hdmi_force_hotplug=1") -eq 0 ];
        then
            sed -i 's|#hdmi_force_hotplug=1|hdmi_force_hotplug=1|g' /boot/config.txt
            
        fi
    fi


    # Hide the text normally shown when linux boots up
    isInFile=$(cat /boot/cmdline.txt | grep -c "tty3")
    if [ $isInFile -eq 0 ]
    then    
    	echo "- Modifying cmdline.txt"
        echo "Candle: adding kiosk parameters to cmdline.txt" >> /dev/kmsg
    	# change text output to third console. press alt-shift-F3 during boot to see it again.
        sed -i 's/tty1/tty3/' /boot/cmdline.txt
    	# hide all the small things normally shown at boot
    	sed -i ' 1 s/.*/& quiet plymouth.ignore-serial-consoles splash logo.nologo vt.global_cursor_default=0/' /boot/cmdline.txt        
    else
        echo "- The cmdline.txt file was already modified"
        echo "Candle: cmdline.txt kiosk parameters were already present" >> /dev/kmsg
    fi
    
    # Use the older display driver for now, as this solves many audio headaches.
    # https://github.com/raspberrypi/linux/issues/4543
    echo "setting fkms display driver"
    sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/' /boot/config.txt


    # Set more power for USB ports
    isInFile3=$(cat /boot/config.txt | grep -c "max_usb_current")
    if [ $isInFile3 -eq 0 ]
    then
    	echo "- Setting USB to deliver more current in config.txt"
    	echo 'max_usb_current=1' >> /boot/config.txt
    else
        echo "- USB was already set to deliver more current in config.txt"
    fi

fi




#mkdir -p /etc/X11/xinit
#mkdir -p /etc/xdg/openbox

if [ ! -d "/etc/xdg/openbox" ];
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






# ADD CHROMIUM POLICY

# Add policy file to disable things like file selection
mkdir -p /etc/chromium/policies/managed/
echo '{"AllowFileSelectionDialogs": false, "AudioCaptureAllowed": false, "AutoFillEnabled": false, "PasswordManagerEnabled": false}' > /etc/chromium/policies/managed/candle.json





# ADD IP-TABLES
echo
echo "ADDING IPTABLES"
echo
#echo "before:"
#iptables -t nat --list
#echo
#echo "Redirecting :80 to :8080 and :443 to :4443"
#echo
if iptables --list | grep 4443; then
    echo "IPTABLES ALREADY ADDED"
    echo "Candle: ip tables already added" >> /dev/kmsg
else
    echo "Candle: adding ip tables" >> /dev/kmsg
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-mark 1
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j MARK --set-mark 1
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4443
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -m mark --mark 1 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 4443 -m mark --mark 1 -j ACCEPT
fi
#iptables -L -v -n
#echo "after"
#iptables -t nat --list

#echo "\n\n" | apt install iptables-persistent -y
#apt install iptables-persistent -y

echo




# TODO:

# ~/.config/configstore/update-notifier-npm.json <- set output to true
# Respeaker drivers?

# update python libraries except for 2 (schemajson and... )
# pip3 list --outdated
# not to be updated:
# - websocket-client
# - jsonschema (if memory serves)




# INSTALL/UPDATE READ_ONLY MODE SCRIPT

echo
echo "Downloading read only script"
echo

if [ -f /boot/candle_cutting_edge.txt ]; then
    wget https://raw.githubusercontent.com/createcandle/ro-overlay/main/bin/ro-root.sh -O ./ro-root.sh
    
else
    curl -s https://api.github.com/repos/createcandle/ro-overlay/releases/latest \
    | grep "tarball_url" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | sed 's/,*$//' \
    | wget -qi - -O ro-overlay.tar

    if [ -f ro-overlay.tar ]; then
        tar -xf ro-overlay.tar
        rm ./ro-overlay.tar
    
        for directory in createcandle-ro-overlay*; do
          [[ -d $directory ]] || continue
          echo "Directory: $directory"
          mv -- "$directory" ./ro-overlay
        done

        if [ -d ./ro-overlay ]; then
            cp ./ro-overlay/ro-root.sh ./ro-root.sh
            rm -rf ./ro-overlay
        else
            echo "ERROR, ro-overlay folder missing"
        fi
    else
        echo "Download of read-only overlay script failed" >> /dev/kmsg
        echo "$(date) - download of read-only overlay script failed" >> /boot/candle_log.txt
        
        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
            /bin/ply-image /boot/error.png
            sleep 7200
        fi

        exit 1
    fi
fi


# If the file exists, make it executable and move it into place
if [ -f ./ro-root.sh ]; then
    chmod +x ./ro-root.sh
    
    # Avoid risky move if possible
    if ! diff -q ./ro-root.sh /bin/ro-root.sh &>/dev/null; then
        echo "ro-root.sh file is different, moving it into place"
        mv ./ro-root.sh /bin/ro-root.sh
        chmod +x /bin/ro-root.sh
    else
        echo "new ro-root.sh file is same as the old one, not moving it"
    fi
else
    echo "ERROR: failed to download ro-root.sh"
    echo "ERROR: failed to download ro-root.sh" >> /dev/kmsg
    echo "$(date) - failed to download ro-root.sh" >> /boot/candle_log.txt
    exit 1
fi








# ENABLE READ_ONLY MODE

if [ "$SKIP_RO" = no ] || [[ -z "${SKIP_RO}" ]]; then
    

    
    #isInFile4=$(cat /boot/config.txt | grep -c "ramfsaddr")
    if [ $(cat /boot/config.txt | grep -c "ramfsaddr") -eq 0 ];
    then
        echo
        echo "ADDING READ-ONLY MODE"
        echo
        echo "Candle: adding read-only mode" >> /dev/kmsg
        
        
        
        mkinitramfs -o /boot/initrd
    
        
    
    	echo "- Adding read only mode to config.txt"
        echo >> /boot/config.txt
        echo '# Read only mode' >> /boot/config.txt
        echo 'initramfs initrd followkernel' >> /boot/config.txt
        echo 'ramfsfile=initrd' >> /boot/config.txt
        echo 'ramfsaddr=-1' >> /boot/config.txt
    
    else
        echo "- Read only file system mode was already in config.txt"
        echo "Candle: read-only mode already existed" >> /dev/kmsg
    fi


    if [ -f /bin/ro-root.sh ] && [ -f /boot/initrd ] && [ ! $(cat /boot/config.txt | grep -c "ramfsaddr") -eq 0 ];
    then
        
        #isInFile5=$(cat /boot/cmdline.txt | grep -c "init=/bin/ro-root.sh")
        if [ $(cat /boot/cmdline.txt | grep -c "init=/bin/ro-root.sh") -eq 0 ]
        then
        	echo "- Modifying cmdline.txt for read-only file system"
            sed -i ' 1 s|.*|& init=/bin/ro-root.sh|' /boot/cmdline.txt
            echo "Candle: read-only mode is now enabled" >> /dev/kmsg
        else
            echo "- The cmdline.txt file was already modified with the read-only filesystem init command"
            echo "Candle: read-only mode was already enabled" >> /dev/kmsg
        fi
        
    fi
    
    
fi





# Add RW and RO alias shortcuts to .profile
if [ -f /home/pi/.profile ]; then
    if [ $(cat /home/pi/.profile | grep -c "alias rw=") -eq 0 ];
    then
        echo "adding ro and rw aliases to /home/pi/.profile"
        echo "" >> /home/pi/.profile
        echo "alias ro='sudo mount -o remount,ro /ro'" >> /home/pi/.profile
        echo "alias rw='sudo mount -o remount,rw /ro'" >> /home/pi/.profile
    fi
fi

# Allow the disk to remain RW on the next boot
#touch /boot/candle_rw.txt







# CREATE BACKUPS

cd /home/pi

# Create tar backup up controller
if [ ! -f /home/pi/controller_backup.tar ];
then
    if [ -f /home/pi/webthings/gateway/build/app.js ] \
    && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
    && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
    && [ -d /home/pi/webthings/gateway/node_modules ] \
    && [ -d /home/pi/webthings/gateway/build/static/bundle ]; 
    then
        echo "Creating initial backup of webthings folder"
        echo "Candle: creating initial backup of webthings folder" >> /dev/kmsg
        tar -czf ./controller_backup.tar ./webthings
    else
        echo
        echo "ERROR, NOT MAKING BACKUP, MISSING WEBTHINGS DIRECTORY OR PARTS MISSING"
        echo "Candle: ERROR, missing (parts of) webthings directory" >> /dev/kmsg
        echo
    fi
fi

# important boot files backup
if [ ! -f /etc/rc.local.bak ]; then
    cp /etc/rc.local /etc/rc.local.bak
fi
if [ ! -f /home/pi/candle/early.sh.bak ]; then
    cp /home/pi/candle/early.sh /home/pi/candle/early.sh.bak
fi
if [ ! -f /etc/xdg/openbox/autostart.bak ]; then
    cp /etc/xdg/openbox/autostart /etc/xdg/openbox/autostart.bak
fi



# SAVE STATE

# Generate file that can be used to re-install this exact combination of Python packages's versions
pip3 list --format=freeze > /home/pi/candle/candle_requirements.txt

# Create file that simply lists the installec packages and their versions
apt list --installed 2>/dev/null | grep -v -e "Listing..." | sed 's/\// /' | awk '{print $1 "=" $3}' > /home/pi/candle/candle_packages.txt

# Create a script that could re-install all those packages if the sources were available. 
# However, the Raspberry servers only serve the very latest versions, so this is moot.
apt list --installed 2>/dev/null | grep -v -e "apt/" -e "apt-listchanges/" -e "apt-utils/" -e "libapt-" -e "Listing..." | sed 's/\// /' | awk '{print "apt -y --reinstall install " $1 "=" $3}' > /home/pi/candle/candle_packages_installer.sh

# Prepare for potential download of all current versions of the packages
mkdir -p /home/pi/.webthings/deb_packages
chown pi:pi /home/pi/.webthings/deb_packages
apt list --installed 2>/dev/null | grep -v -e "Listing..." | sed 's/\// /' | awk '{print "echo '" $1 "' | sudo tee -a /dev/kmsg && apt download " $1 "=" $3}' > /home/pi/.webthings/deb_packages/candle_packages_downloader.sh

#if [ -f /home/pi/.webthings/deb_packages/candle_packages_downloader.sh ]; then
#sed -i '' '1i\
#apt update
#' /home/pi/.webthings/deb_packages/candle_packages_downloader.sh
#fi





echo
echo "Enabling NVM in create_latest_candle.sh for cleanup"
export NVM_DIR="/home/pi/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"




# CLEANUP

echo
echo "CLEANING UP"
echo
echo "Candle: cleaning up" >> /dev/kmsg

#npm cache clean --force # already done in install_candle_controller script
#nvm cache clear

echo "Clearing Apt leftovers"
apt clean
apt-get clean
apt remove --purge
apt autoremove
rm -rf /var/lib/apt/lists/*

echo "removing swap"
echo "Candle: removing swap" >> /dev/kmsg
dphys-swapfile swapoff
dphys-swapfile uninstall
update-rc.d dphys-swapfile remove
if [ -f /home/pi/.webthings/swap ]; then
    swapoff /home/pi/.webthings/swap
    rm /home/pi/.webthings/swap
fi
if [ -f /var/swap ]; then
    swapoff /var/swap
    rm /var/swap
fi


echo "Clearing /tmp"
rm -rf /tmp/*

rm /home/pi.wget-hsts
rm -rf /home/pi/.config/chromium
echo '{"optOut": true,"lastUpdateCheck": 0}' > /home/pi/.config/configstore/update-notifier-npm.json 
chown pi:pi s/home/pi/.config/configstore/update-notifier-npm.json 

# Remove files left over by Windows or MacOS
rm -rf /boot/.Spotlight*
if [ -f /boot/._cmdline.txt ]; then
    rm /boot/._cmdline.txt
fi

if [ -f /home/pi/create_latest_candle.sh ]; then
    echo "Removing left-over /home/pi/create_latest_candle.sh"
    rm /home/pi/create_latest_candle.sh
fi



# Set Candle as the hostname
if [ ! -e /home/pi/.webthings/etc/hostname ]
then
    echo "candle" > /etc/hostname
    echo "candle" > /home/pi/.webthings/etc/hostname
    echo "Candle: creating /home/pi/.webthings/etc/hostname" >> /dev/kmsg
else
    echo "/home/pi/.webthings/etc/hostname already existed"
    echo "Candle: /home/pi/.webthings/etc/hostname already existed" >> /dev/kmsg
fi


# Create hosts file and its symlink
if [ ! -f /home/pi/.webthings/etc/hosts ]; then
    echo "/home/pi/.webthings/etc/hosts did not exist, generating it now"
    echo -e '127.0.0.1	localhost\n::1		localhost ip6-localhost ip6-loopback\nff02::1		ip6-allnodes\nff02::2		ip6-allrouters\n\n127.0.1.1	candle\n' > /home/pi/.webthings/etc/hosts
fi
if [ ! -L /etc/hosts ]; then
    echo "removing /etc/hosts and creating a symlink to /home/pi/.webthings/etc/hosts instead"
    rm /etc/hosts
    ln -s /home/pi/.webthings/etc/hosts /etc/hosts
fi


# Set to boot from partition2
sed -i 's|root=PARTUUID=.* |root=/dev/mmcblk0p2 |g' /boot/cmdline.txt

# Copying the fstab file is the last thing to do since it could render the system inaccessible if the mountpoints it needs are not available

if [ -f /home/pi/configuration-files/boot/fstab3.bak ] \
&& [ -f /home/pi/configuration-files/boot/fstab4.bak ] \
&& [ -d /home/pi/.webthings/etc/wpa_supplicant ] \
&& [ -d /home/pi/.webthings/var/lib/bluetooth ] \
&& [ -d /home/pi/.webthings/etc/ssh ] \
&& [ -f /home/pi/.webthings/etc/hostname ] \
&& [ -d /home/pi/.webthings/tmp ] \
&& [ -d /home/pi/.webthings/arduino/.arduino15 ] \
&& [ -d /home/pi/.webthings/arduino/Arduino ];
then
    echo
    echo "COPYING FSTAB FILE"
    echo

    if lsblk | grep -q 'mmcblk0p4'; 
    then
        echo "copying 4 partition version of fstab"
        echo "Candle: copying 4 partition version of fstab" >> /dev/kmsg
        
        if ! diff -q /home/pi/configuration-files/boot/fstab4.bak /etc/fstab &>/dev/null; then
            echo "fstab file is different, copying it"
            cp --verbose /home/pi/configuration-files/boot/fstab4.bak /etc/fstab
        else
            echo "new fstab file is same as the old one, not copying it."
        fi
        
    else
        echo "copying 3 partition version of fstab"
        echo "Candle: copying 3 partition version of fstab" >> /dev/kmsg
        
        if ! diff -q /home/pi/configuration-files/boot/fstab3.bak /etc/fstab &>/dev/null; then
            echo "fstab file is different, copying it"
            cp --verbose /home/pi/configuration-files/boot/fstab3.bak /etc/fstab
        else
            echo "new fstab file is same as the old one, not copying it."
        fi
        
    fi
else
    echo
    echo "ERROR, SOME VITAL FSTAB MOUNTPOINTS DO NOT EXIST"
    echo "ERROR, SOME VITAL FSTAB MOUNTPOINTS DO NOT EXIST" >> /dev/kmsg
    echo
fi


echo "Clearing /home/pi/configuration-files"
rm -rf /home/pi/configuration-files



# Some final insurance
chown pi:pi /home/pi/*
chown pi:pi /home/pi/candle/*
#echo "setting internet time to true"
#timedatectl set-ntp true
#sleep 2
#fake-hwclock save

# delete bootup_actions, just in case this script is being run as a bootup_actions script.
if [ -f /boot/bootup_actions.sh ]; then
    echo "removed /boot/bootup_actions.sh"
    rm /boot/bootup_actions.sh
fi





# OTHER

# Create fix for missing audio firmware
if [ ! -e /usr/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.bin ]; then
  ln -s /usr/lib/firmware/brcm/brcmfmac43455-sdio.bin /usr/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.bin  
  echo
  echo "Candle: added symlink for missing audio firmware"
  echo
  echo "Candle: added symlink for missing audio firmware" >> /dev/kmsg
fi



# cp /home/pi/.webthings/etc/webthings_settings_backup.js /home/pi/.webthings/etc/webthings_settings.js




# RUN DEBUG SCRIPT

if [ "$SKIP_DEBUG" = no ] || [[ -z "${SKIP_DEBUG}" ]]; 
then
    echo
    echo
    echo 
    echo "ALMOST DONE, RUNNING DEBUG SCRIPT"
    echo

    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ];
    then
        rm /boot/bootup_actions.sh
        rm /boot/bootup_actions_failed.sh
        /home/pi/candle/debug.sh > /boot/debug.txt
    
        echo "" >> /boot/debug.txt
        echo "THIS OUTPUT WAS CREATED BY THE SYSTEM UPGRADE PROCESS" >> /boot/debug.txt
        cat /boot/debug.txt
    
        echo "Candle: DONE. Debug output placed in /boot/debug.txt" >> /dev/kmsg
        echo "Candle: Rebooting in 5 seconds..." >> /dev/kmsg
        sleep 5
        reboot
        exit 0
    else
        /home/pi/candle/debug.sh > /home/pi/candle/debug.txt
        cat /home/pi/candle/debug.txt
        rm /home/pi/candle/debug.txt
    fi

    echo
    echo
    
else
    echo
    echo
    echo "boot partition not mounted, so DONE"
    echo
    echo
    echo "boot partition not mounted, so DONE" >> /dev/kmsg
    exit 0
fi

echo



if [[ -z "${STOP_EARLY}" ]] || [ "$STOP_EARLY" = no ]; 
then
    echo "STARTING FINAL PHASE"
    echo "Candle: calling prepare_for_disk_image.sh" >> /dev/kmsg
    chmod +x /home/pi/candle/prepare_for_disk_image.sh 
    /home/pi/candle/prepare_for_disk_image.sh 
    exit 0
  
else
    echo "NOT RUNNING PREPARE_FOR_DISK_IMAGE SCRIPT YET. Stopping early."
    
    # To be safe, start SSH on the first run
    #touch /boot/ssh.txt
    
    # Optional download of .deb files
    if [[ -z "${DOWNLOAD_DEB}" ]] || [ "$DOWNLOAD_DEB" = no ]; then
        echo "Skipping download of .deb files"
        echo "Candle: skipping download of .deb files" >> /dev/kmsg
    else
        #printf 'Do you want to download all the .deb files? (y/n)'
        #read answer
        #if [ "$answer" != "${answer#[Yy]}" ] ;then
        
        echo 
        echo "DOWNLOADING ALL INSTALLED PACKAGES AS .DEB FILES"
        echo "Candle: downloading all .deb files" >> /dev/kmsg
        

        cd /home/pi/.webthings/deb_packages
        chmod +x ./candle_packages_downloader.sh
        sudo -u pi ./candle_packages_downloader.sh
        
        # fix the filenames. Replaces "%3a" with ":".
        # for f in *; do mv "$f" "${f//%3a/:}"; done
  
        echo
        echo "Downloaded packages in /home/pi/.webthings/deb_packages:"
        ls -l
        du /home/pi/.webthings/deb_packages -h
        
    fi
    
  
  
    cd /home/pi/
  
    # On the next boot allow the system partition to be writeable
    # touch /boot/candle_rw_once.txt
    
    #MY_SCRIPT_VARIABLE="${CANDLE_DEV}"
    echo
    echo "MOSTLY DONE"
    echo
    echo "To finalise the process, delete the deb folder:"
    echo "sudo rm -rf /home/pi/.webthings/deb_packages"
    echo
    echo "then enter this command:"
    echo "sudo /home/pi/prepare_for_disk_image.sh"
    echo
    echo "Once that script is done the pi will shut down and can be imaged."
    echo
    echo "Note that if you reboot, the read-only mode will become active."
    echo "If you want to delay this once, then use this command:"
    echo "touch /boot/candle_rw_once.txt"
    echo "...or if you want skip read-only mode permanently:"
    echo "touch /boot/candle_rw_keep.txt"
    echo ""
    
fi


# If STOP_EARLY is enabled, then here it's possible to also ask the script to reboot. This is useful for upgrading the system.
if [[ -z "${REBOOT_WHEN_DONE}" ]] || [ "$REBOOT_WHEN_DONE" = no ]; then
    echo "(not rebooting)"
else
    echo "rebooting in 10 seconds"
    sleep 10
    reboot
fi

exit 0