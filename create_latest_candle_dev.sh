#!/bin/bash
set +e # continue on errors

#CUTTING_EDGE=yes 
#CREATE_DISK_IMAGE=yes


# CANDLE INSTALL AND UPDATE SCRIPT

# This script will turn a Raspberry Pi OS Lite installation into a Candle controller
# It can also update a Candle controller to the latest available version (with some limitations)

# By default it acts as an upgrade script (not doing a factory reset at the end, rebooting the system when done)

# If you want to use this script to directly create disk imagesrecovery, then you can use:
# export CREATE_DISK_IMAGE=yes

# Set the script to download the very latest available version. Risky. Enabling this creates the $BOOT_DIR/candle_cutting_edge.txt file
# export CUTTING_EDGE=yes

# Other parts of the script that can be skipped:
# export SKIP_PARTITIONS=yes
# export TINY_PARTITIONS=yes
# export SKIP_APT_INSTALL=yes
# export SKIP_APT_UPGRADE=yes
# export SKIP_PYTHON=yes
# export SKIP_RESPEAKER=yes
# export SKIP_BLUEALSA=yes
# export SKIP_CONTROLLER=yes
# export SKIP_DEBUG=yes
# export SKIP_REBOOT=yes
# export SKIP_SPLASH=yes
# export SKIP_SPLASH=yes
# export SKIP_BROWSER=yes

#SKIP_PARTITIONS=yes
#TINY_PARTITIONS=yes # used to create smaller partition images, which are used in the new system update process
#SKIP_APT_INSTALL=yes
#SKIP_APT_UPGRADE=yes
#SKIP_PYTHON=yes
#SKIP_RESPEAKER=yes
#SKIP_BLUEALSA=yes
#SKIP_CONTROLLER=yes
#SKIP_DEBUG=yes
#SKIP_REBOOT=yes
#SKIP_SPLASH=yes
#SKIP_BROWSER=yes
 
# SKIP_PARTITIONS=yes SKIP_APT_INSTALL=yes SKIP_APT_UPGRADE=yes SKIP_PYTHON=yes SKIP_RESPEAKER=yes SKIP_BLUEALSA=yes SKIP_CONTROLLER=yes SKIP_DEBUG=yes SKIP_REBOOT=yes

# The script can add the re-install option to every Apt install command. This feature may be removed in the future.
# export APT_REINSTALL=yes

# To skip the creation of the read-only mode:
# export SKIP_RO=yes

# If you also want this script to download all the installed packages' as .deb files, then set this environment variable:
# export DOWNLOAD_DEB=yes

# An indicator that the script is inside chroot. It doesn't do anything at the moment.
# export CHROOTED=yes




# Note to self
# Upgrade conflicts with:
# - installing ReSpeaker drivers
# - installing the new read only mode



# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run candle update script as root (use sudo)"
  exit
fi

scriptname=$(basename "$0")

# Not used in this script yet, currently /home/pi is still hardcoded
if [ -d /home/pi ]; then
    CANDLE_BASE="/home/pi"
else
    CANDLE_BASE="$(pwd)"
fi


BOOKWORM=0
CHROMIUM_PACKAGE_NAME="chromium-browser"
BOOT_DIR="/boot"
if lsblk | grep /boot/firmware; then
    echo "firmware partition is mounted at /boot/firmware"
    BOOT_DIR="/boot/firmware"
    #CHROMIUM_PACKAGE_NAME="chromium"
    BOOKWORM=1
fi




echo "" >> $BOOT_DIR/candle_log.txt
echo "Candle: starting update - $(date) - $scriptname" >> /dev/kmsg
echo "starting update - $(date) - $scriptname" >> $BOOT_DIR/candle_log.txt

if [ -f /proc/mounts ]; 
then
    # Detect is read-only mode is active
    if [ -n "$(grep "[[:space:]]ro[[:space:],]" /proc/mounts | grep ' /ro ')" ]; then
        echo 
        echo "Detected read-only mode. Create $BOOT_DIR/candle_rw_once.txt, reboot, and then try again."
        echo "Candle: detected read-only mode. Aborting." >> /dev/kmsg
        echo "Candle: detected read-only mode. Aborting." >> $BOOT_DIR/candle_log.txt
      
        # Show error image
        if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
        then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                /bin/ply-image $BOOT_DIR/error.png
                #sleep 7200
            fi
        fi
  
        exit 1
    fi
fi


# Detect if old overlay system is active

if [ -f $BOOT_DIR/cmdline.txt ]; then
    if grep -q "boot=overlay" $BOOT_DIR/cmdline.txt; then
        echo 
        echo "Detected the OLD raspi-config read-only overlay. Disable it under raspi-config -> performance (and then reboot)"
        echo "Candle: detected OLD read-only mode. Aborting." >> /dev/kmsg
        echo "Candle: detected OLD read-only mode. Aborting." >> $BOOT_DIR/candle_log.txt

        # Show error image
        if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
        then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                /bin/ply-image $BOOT_DIR/error.png
                #sleep 7200
            fi
        fi

        exit 1
    fi
fi


echo



# Check if /boot is available
if [ ! -f $BOOT_DIR/cmdline.txt ]; then
    echo "Candle: ERROR, missing cmdline.txt??" >> /dev/kmsg
    echo "Candle: ERROR, missing cmdline.txt??" >> $BOOT_DIR/candle_log.txt
    
    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
    then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
            /bin/ply-image $BOOT_DIR/error.png
            #sleep 7200
        fi
    fi
    
    exit 1
fi



if [ "$CUTTING_EDGE" = no ] || [[ -z "${CUTTING_EDGE}" ]]
then
    
    if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
       echo "$BOOT_DIR/candle_cutting_edge.txt exists"
    else
       echo "no environment indication to go cutting edge"
    fi
else
    echo "going cutting edge"
    touch $BOOT_DIR/candle_cutting_edge.txt
fi


# OUTPUT SOME INFORMATION
BIT_TYPE=$(getconf LONG_BIT)

cd $CANDLE_BASE

echo
echo "CREATING CANDLE"
echo

echo "DATE         : $(date)"
echo "IP ADDRESS   : $(hostname -I)"
echo "MODEL        : $(tr -d '\0' < /proc/device-tree/model)"
echo "BITS         : $BIT_TYPE"
echo "PATH         : $PATH"
echo "USER         : $(whoami)"

echo "SCRIPT NAME  : $scriptname"

if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    echo "CUTTING EDGE : yes"
    echo "CUTTING EDGE : yes" >> /dev/kmsg
    echo "CUTTING EDGE : yes" >> $BOOT_DIR/candle_log.txt
else
    echo "CUTTING EDGE : no"
    echo "CUTTING EDGE : no" >> /dev/kmsg
    echo "CUTTING EDGE : no" >> $BOOT_DIR/candle_log.txt
fi


if [ "$CHROOTED" = no ] || [[ -z "${CHROOTED}" ]]
then
	echo "CHROOT       : Not in chroot"
	echo "CHROOT       : Not in chroot" >> $BOOT_DIR/candle_log.txt
else
	echo "CHROOT       : Inside chroot"
fi


if [[ -z "${APT_REINSTALL}" ]] || [ "$APT_REINSTALL" = no ] ; then
    echo "APT REINSTALL: no"
    echo "APT REINSTALL: no" >> /dev/kmsg
else
    reinstall="--reinstall"
    echo "APT REINSTALL: yes"
    echo "APT REINSTALL: yes" >> /dev/kmsg
    echo "APT REINSTALL: yes" >> $BOOT_DIR/candle_log.txt
    echo
    echo "reinstall flag: $reinstall"
fi




echo
echo
echo "Current version of Raspbery Pi OS:"
cat /etc/os-release
echo
echo

echo "$BOOT_DIR/cmdline.txt before:"
cat $BOOT_DIR/cmdline.txt
echo

# Wait for IP address for at most 30 seconds
echo "Waiting for IP address..." >> /dev/kmsg
for i in {1..30}
do
  #echo "current IP: $(hostname -I)"
  if [ "$(hostname -I)" = "" ]
  then
    echo "Candle: no network yet $i"
    echo "no network yet $i"
    sleep 1    
  else
    echo "Candle: IP address detected: $(hostname -I)" >> /dev/kmsg
    echo "Candle: IP address detected: $(hostname -I)" >> $BOOT_DIR/candle_log.txt
    break
  fi
done



# ADDITIONAL SANITY CHECKS

if [ ! -s /etc/resolv.conf ]; then
    # no nameserver
    echo "no nameserver, aborting"
    echo "Candle: no nameserver, aborting" >> /dev/kmsg
    echo "Candle: no nameserver, aborting" >> $BOOT_DIR/candle_log.txt
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
            echo "Candle: creating partitions" >> $BOOT_DIR/candle_log.txt
            echo
            if [[ -z "${TINY_PARTITIONS}" ]]; then
                echo "normal partition size"
                echo yes | parted /dev/mmcblk0 ---pretend-input-tty resizepart 2 7000MB
                printf "mkpart\np\next4\n7001MB\n7500MB\nmkpart\np\next4\n7502MB\n14000MB\nquit" | parted
                #resizepart /dev/mmcblk0 2 12600000
            else
                echo "creating smaller partitions for update image"
                echo yes | parted /dev/mmcblk0 ---pretend-input-tty resizepart 2 5000MB
                printf "mkpart\np\next4\n5001MB\n7500MB\nmkpart\np\next4\n7502MB\n9500MB\nquit" | parted
            fi

            # Tell OS to rescan
            #echo 1 > /sys/block/mmcblk0/device/rescan
            
            echo ""
            echo "after partitioning:"
            echo "fdisk:"
            fdisk -l
            echo ""

            echo "lsblk:"
            lsblk
            
            echo ""
            resize2fs /dev/mmcblk0p2
            
            printf "y" | mkfs.ext4 /dev/mmcblk0p3
            printf "y" | mkfs.ext4 /dev/mmcblk0p4
            mkdir -p /home/pi/.webthings
            chown pi:pi /home/pi/.webthings
            touch $BOOT_DIR/candle_has_4th_partition.txt
            
            e2label /dev/mmcblk0p2 system
            e2label /dev/mmcblk0p3 recovery
            e2label /dev/mmcblk0p4 user

            systemctl daemon-reload
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
    
    #lsblk
    
else
    echo "Partitions seem to already exist (addons dir existed)"
    echo "Candle: partitions seem to already exist" >> /dev/kmsg
    echo "$(date) - starting create_latest_candle" >> /home/pi/.webthings/candle.log
    echo "$(date) - starting create_latest_candle" >> $BOOT_DIR/candle_log.txt
fi


echo

# Clean up any files that may be left over to make sure there is enough space
if [ -f /zero.fill ]; then
  rm /zero.fill
  echo "Warning, removed /zero.fill"
fi
if [ -f /home/pi/.webthings/zero.fill ]; then
  rm /home/pi/.webthings/zero.fill
  echo "Warning, removed /home/pi/.webthings/zero.fill"
fi

if [ -d /home/pi/webthings/gateway2 ]; then
    rm -rf /home/pi/webthings/gateway2
    echo "Warning, removed /home/pi/webthings/gateway2"
fi
if [ -f /home/pi/latest_stable_controller.tar ]; then
    rm /home/pi/latest_stable_controller.tar
    echo "Warning, removed /home/pi/latest_stable_controller.tar"
fi
if [ -f /home/pi/latest_stable_controller.tar.txt ]; then
    rm /home/pi/latest_stable_controller.tar.txt
    echo "Warning, removed /home/pi/latest_stable_controller.tar.txt"
fi

# pre-made mountpoints for mounting user or recovery partition
#mkdir -p /mnt/userpart
#mkdir -p /mnt/recoverypart
#mkdir -p /mnt/ramdrive
# not compatible with /ro

sleep 3
cd $CANDLE_BASE



# Do initial apt update
echo
echo "doing apt update and allowing release info change"
apt-get --allow-releaseinfo-change-suite update 



echo
echo "checking/switching to old-school dhcpcd early"
if [ ! -f /usr/sbin/dhcpcd ]; then
    if [ "$SKIP_DHCPCD" = no ] || [[ -z "${SKIP_DHCPCD}" ]]; then
	    echo
	    echo "force-installing dhcpcd"
	    echo "switching to DHCPCD" >> $BOOT_DIR/candle_log.txt

	    rm dhcpcd.tar.*
   
	    # binary no longer seems available for bookworm...
	    wget https://www.candlesmarthome.com/tools/dhcpcd.tar.xz --retry-connrefused 
	
	    #cd /tmp
	    
	    #apt download dhcpcd
	    #ar x dhcp*.deb
	    if [ -f dhcpcd.tar.xz ]; then

		    tar xvhf dhcpcd.tar.xz -C /
		    #rm dhcp*.deb
		    #rm data.tar.xz
		    #rm control.tar.xz
		    #rm debian-binary
		    rm dhcpcd.tar.*
		    
		    if [ -f /usr/sbin/dhcpcd ]; then
		        chmod +x /usr/sbin/dhcpcd
				chown root:root /usr/sbin/dhcpcd
			
				chown root:netdev /etc/dhcpcd.conf
			
			 	echo "Switching to DHCPCD..."
			  
			    systemctl daemon-reload
	   			echo "Enabling dhcpcd.service..."
				systemctl enable dhcpcd.service
				echo "Starting dhcpcd.service..."
			 	systemctl start dhcpcd.service
	 			#echo "Both should now be active..."
	 			#systemctl status dhcpcd.service
	 			#echo "Stopping NetworkManager..."
				#systemctl stop NetworkManager.service
				echo "Disabling NetworkManager..."
			    systemctl disable NetworkManager.service
       			    echo "completely removing network manager"
	   		    apt purge --auto-remove network-manager
			    echo "Switched to DHCPCD"
			    
				#sysctl -w net.ipv6.neigh.wlan0.retrans_time_ms=1000
			fi

  		else
			echo "Error, failed to download DHCPCD from candlesmarthome.com/tools"
   			echo "Error, failed to download DHCPCD from candlesmarthome.com/tools" >> $BOOT_DIR/candle_log.txt
	  		exit 1
	    fi
	fi
else
	echo "DHCPCD seems to already be installed"
fi









# Save the bits of the initial kernel the boot partition to a file
if [ "$BIT_TYPE" == 64 ]; then
    echo "creating $BOOT_DIR/candle_64bits.txt"
    echo "creating $BOOT_DIR/candle_64bits.txt" >> /dev/kmsg
    touch $BOOT_DIR/candle_64bits.txt
fi


# Make sure there is a current time
if [ -f $BOOT_DIR/candle_hardware_clock.txt ]; then
    rm $BOOT_DIR/candle_hardware_clock.txt
    systemctl restart systemd-timesyncd.service
    timedatectl set-ntp true
    timedatectl
    sleep 2
    /usr/sbin/fake-hwclock save
    echo "Candle: requested latest time. Date is now: $(date)" >> /dev/kmsg
    echo "Candle: requested latest time. Date is now: $(date)" >> $BOOT_DIR/candle_log.txt
fi



# Download error image first
if [ -f $BOOT_DIR/cmdline.txt ]; then
    wget https://www.candlesmarthome.com/tools/error.png -O $BOOT_DIR/error.png
    if [ ! -f $BOOT_DIR/error.png ]; then
        echo "Candle: ERROR, download of error.png failed. How ironic." >> /dev/kmsg
        echo "Candle: ERROR, download of error.png failed. How ironic." >> $BOOT_DIR/candle_log.txt
        exit 1
    fi      
fi



# Quickly install Git if it hasn't been already
if [ -z "$(which git)" ]; then
    echo ""
    echo "installing git"
    echo "Candle: installing git" >> /dev/kmsg
    echo "Candle: installing git" >> $BOOT_DIR/candle_log.txt
    echo ""
    apt -y install git "$reinstall" 
    git config --global http.postBuffer 157286400
fi



# PLYMOUTH LITE
if [ ! -f /bin/ply-image ]; 
then
    echo ""
    echo "creating Plymouth lite (to show splash images)" >> /dev/kmsg
    echo "creating Plymouth lite (to show splash images)" >> $BOOT_DIR/candle_log.txt
    echo ""
    
    apt update
    apt install -y libpng-dev
    
    git clone --depth 1 https://github.com/createcandle/Plymouth-lite.git
    cd Plymouth-lite
    ./configure
    make
    cp ply-image /usr/bin

    cd $CANDLE_BASE
    rm -rf Plymouth-lite
fi


echo ""
echo "updating /usr/bin/candle_hostname_fix.sh"
echo -e '#!/bin/bash\nhostname -F /home/pi/.webthings/etc/hostname\nhostnamectl set-hostname $(cat /home/pi/.webthings/etc/hostname) --static\nhostnamectl set-hostname $(cat /home/pi/.webthings/etc/hostname) --transient\nhostnamectl set-hostname $(cat /home/pi/.webthings/etc/hostname) --pretty' > /usr/bin/candle_hostname_fix.sh
chmod +x /usr/bin/candle_hostname_fix.sh
echo ""

# BULLSEYE SOURCES

# Make sure Bullseye sources are used
if cat /etc/apt/sources.list.d/raspi.list | grep -q buster; then
    echo "changing /etc/apt/sources.list.d/raspi.list from buster to bookworm" >> /dev/kmsg
    echo "changing /etc/apt/sources.list.d/raspi.list from buster to bookworm" >> $BOOT_DIR/candle_log.txt
    sed -i 's/buster/bookworm/' /etc/apt/sources.list.d/raspi.list
fi

if cat /etc/apt/sources.list | grep -q buster; then
    echo "changing /etc/apt/sources.list from buster to bullseye" >> /dev/kmsg
    echo "changing /etc/apt/sources.list from buster to bullseye" >> $BOOT_DIR/candle_log.txt 
    sed -i 's/buster/bullseye/' /etc/apt/sources.list
fi




# Add option to download source code from RaspberryPi server
echo "modifying /etc/apt/sources.list - allowing apt access to source code"
sed -i 's/#deb-src/deb-src/' /etc/apt/sources.list

# Unhold browser
echo ""
apt-mark unhold $CHROMIUM_PACKAGE_NAME


# 64 BIT
# If this Raspbery Pi OS is 64 bit, then install support for 32 bit as well.



echo
echo "doing apt-get update"
if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    apt-get update --allow-releaseinfo-change
else
    apt-get update
fi

echo

if [ "$BIT_TYPE" -eq 64 ]; then
    echo "Adding support for 32 bit architecture"
    dpkg --add-architecture armhf
    apt update -y && apt install -y screen:armhf
fi







echo
echo "Downloading read only script"
echo

if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    echo "Candle: Downloading cutting edge read-only script" >> /dev/kmsg
    echo "Candle: Downloading cutting edge read-only script" >> $BOOT_DIR/candle_log.txt
    wget https://raw.githubusercontent.com/createcandle/ro-overlay/main/bin/ro-root.sh -O ./ro-root.sh --retry-connrefused 
    
else
    echo "Candle: Downloading stable read-only script" >> /dev/kmsg
    echo "Candle: Downloading stable read-only script" >> $BOOT_DIR/candle_log.txt
    curl -s https://api.github.com/repos/createcandle/ro-overlay/releases/latest \
    | grep "tarball_url" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | sed 's/,*$//' \
    | wget -qi - -O ro-overlay.tar --retry-connrefused 

    if [ -f ro-overlay.tar ]; then
        
        if [ -d ./ro-overlay ]; then
            echo "WARNING. Somehow detected old ro-overlay folder. Removing it first."
            rm -rf ./ro-overlay
        fi
        echo "unpacking ro-overlay.tar"
        tar -xf ro-overlay.tar
        rm ./ro-overlay.tar
    
        for directory in createcandle-ro-overlay*; do
          [[ -d $directory ]] || continue
          echo "Directory: $directory"
          mv -- "$directory" ./ro-overlay
        done

        if [ -d ./ro-overlay ]; then
            echo "ro-overlay folder exists, OK"
            cp ./ro-overlay/bin/ro-root.sh ./ro-root.sh
            rm -rf ./ro-overlay
        else
            echo "ERROR, ro-overlay folder missing"
            echo "Candle: WARNING, ro-overlay folder missing" >> /dev/kmsg
            echo "Candle: WARNING, ro-overlay folder missing" >> $BOOT_DIR/candle_log.txt
        fi
    else
        echo "Ro-root tar file missing, download failed"
        echo "Candle: ERROR, stable read-only tar download failed" >> /dev/kmsg
        echo "Candle: ERROR, stable read-only tar download failed" >> $BOOT_DIR/candle_log.txt
        
        # Show error image
        if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
        then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                /bin/ply-image $BOOT_DIR/error.png
                #sleep 7200
            fi
        fi

        exit 1
        
    fi
fi


sed -i 's|PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games"|PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/pi/.local/bin"|' /etc/profile


# If the file exists, make it executable and move it into place
if [ -f ./ro-root.sh ]; then
    if [ -n "$(lsblk | grep mmcblk0p3)" ] || [ -n "$(lsblk | grep mmcblk0p4)" ]; then
        echo "Candle: ro-root.sh file downloaded OK" >> /dev/kmsg
        echo "Candle: ro-root.sh file downloaded OK" >> $BOOT_DIR/candle_log.txt
        chmod +x ./ro-root.sh
    
        # Avoid risky move if possible
        if ! diff -q ./ro-root.sh /bin/ro-root.sh &>/dev/null; then
            echo "ro-root.sh file is different, moving it into place"
            echo "Candle: ro-root.sh file is different, moving it into place" >> /dev/kmsg
            echo "Candle: ro-root.sh file is different, moving it into place" >> $BOOT_DIR/candle_log.txt
            if [ -f /bin/ro-root.sh ]; then
                rm /bin/ro-root.sh
            fi
            mv -f ./ro-root.sh /bin/ro-root.sh
            chmod +x /bin/ro-root.sh
        
        else
            echo "new ro-root.sh file is same as the old one, not moving it"
            echo "Candle: downloaded ro-root.sh file is same as the old one, not moving it" >> /dev/kmsg
            echo "Candle: downloaded ro-root.sh file is same as the old one, not moving it" >> $BOOT_DIR/candle_log.txt
        fi
    fi
else
    echo "ERROR: failed to download ro-root.sh"
    echo "Candle: ERROR, download of read-only overlay script failed" >> /dev/kmsg
    echo "$(date) - download of read-only overlay script failed" >> /home/pi/.webthings/candle.log
    echo "$(date) - download of read-only overlay script failed" >> $BOOT_DIR/candle_log.txt
    
    # Show error image
    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
    then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
            /bin/ply-image $BOOT_DIR/error.png
            #sleep 7200
        fi
    fi

    exit 1
fi


# ENABLE READ_ONLY MODE

if [ "$SKIP_RO" = no ] || [[ -z "${SKIP_RO}" ]]; then

    if [ -n "$(lsblk | grep mmcblk0p3)" ] || [ -n "$(lsblk | grep mmcblk0p4)" ]; then
        if [ -f /bin/ro-root.sh ]; then
            #isInFile4=$(cat $BOOT_DIR/config.txt | grep -c "ramfsaddr")
            if [ $(cat $BOOT_DIR/config.txt | grep -c ramfsaddr) -eq 0 ];
            then
                echo
                echo "ADDING READ-ONLY MODE"
                echo
                echo "Candle: adding read-only mode" >> /dev/kmsg
                echo "Candle: adding read-only mode" >> $BOOT_DIR/candle_log.txt
        
                mkinitramfs -o $BOOT_DIR/initrd
    
            	echo "- Adding read only mode to config.txt"
                echo >> $BOOT_DIR/config.txt
                echo '# Read only mode' >> $BOOT_DIR/config.txt
                echo 'initramfs initrd followkernel' >> $BOOT_DIR/config.txt
                echo 'ramfsfile=initrd' >> $BOOT_DIR/config.txt
                echo 'ramfsaddr=-1' >> $BOOT_DIR/config.txt
    
            else
                echo "- Read only file system mode was already in config.txt"
                echo "Candle: read-only mode already existed" >> /dev/kmsg
                echo "Candle: read-only mode already existed" >> $BOOT_DIR/candle_log.txt
            fi


            if [ -f $BOOT_DIR/initrd ] && [ ! $(cat $BOOT_DIR/config.txt | grep -c "ramfsaddr") -eq 0 ];
            then
            
                #isInFile5=$(cat $BOOT_DIR/cmdline.txt | grep -c "init=/bin/ro-root.sh")
                if [ $(cat $BOOT_DIR/cmdline.txt | grep -c "init=/bin/ro-root.sh") -eq 0 ]
                then
                	echo "- Modifying cmdline.txt for read-only file system"
                    echo "- - before: $(cat $BOOT_DIR/cmdline.txt)"
                    sed -i ' 1 s|.*|& init=/bin/ro-root.sh|' $BOOT_DIR/cmdline.txt
                    echo "- - after : $(cat $BOOT_DIR/cmdline.txt)"
                    echo "Candle: read-only mode is now enabled" >> /dev/kmsg
                    echo "Candle: read-only mode is now enabled" >> $BOOT_DIR/candle_log.txt
                else
                    echo "- The cmdline.txt file was already modified with the read-only filesystem init command"
                    echo "Candle: read-only mode was already enabled" >> /dev/kmsg
                    echo "Candle: read-only mode was already enabled" >> $BOOT_DIR/candle_log.txt
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
        
        else
            echo "ERROR, /bin/ro-root.sh is missing, not even attempting to further install read-only mode"
        fi
    fi
fi







#cd $CANDLE_BASE




if [ "$SKIP_APT_UPGRADE" = no ] || [[ -z "${SKIP_APT_UPGRADE}" ]]; 
then
    echo
    echo "doing upgrade first"
    
    apt update -y
    apt-get update -y
    apt --fix-broken install -y
    
    # Check if kernel or bootloader can be updated
    if apt list --upgradable | grep raspberrypi-bootloader; then
        echo "WARNING, BOOTLOADER IS UPGRADEABLE"
        echo "WARNING, BOOTLOADER IS UPGRADEABLE" >> /dev/kmsg
        echo "WARNING, BOOTLOADER IS UPGRADEABLE" >> $BOOT_DIR/candle_log.txt
    fi
    if apt list --upgradable | grep raspberrypi-kernel; then
        echo "WARNING, KERNEL IS UPGRADEABLE"
        echo "WARNING, KERNEL IS UPGRADEABLE" >> /dev/kmsg
        echo "WARNING, KERNEL IS UPGRADEABLE" >> $BOOT_DIR/candle_log.txt
    fi

    #echo "quickly installing dhcpcd"
    #apt install dhcpcd5 resolvconf -y
    #systemctl disable dhcpcd.service

    if [ -n "$(apt list --upgradable | grep raspberrypi-kernel)" ] || [ -n "$(apt list --upgradable | grep raspberrypi-bootloader)" ]; then
    
        #apt install -y raspberrypi-kernel
        #apt install -y raspberrypi-bootloader
        echo "Candle: WARNING, DOING FULL UPGRADE. THIS WILL UPDATE THE KERNEL TOO. Takes a while!"
        echo "Candle: WARNING, DOING FULL UPGRADE. THIS WILL UPDATE THE KERNEL TOO. Takes a while!" >> /dev/kmsg
        echo "WARNING, DOING FULL UPGRADE. THIS WILL UPDATE THE KERNEL TOO." >> $BOOT_DIR/candle_log.txt
        
        echo "no $BOOT_DIR/candle_first_run_complete.txt file yet, probably creating disk image"
        # A little overkill:

        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt full-upgrade -y &
        wait
        apt-get --fix-missing
        apt --fix-broken install -y
        if [ -f /etc/systemd/system/dhcpcd.service.d/wait.conf ]; then
            sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf # Fix potential issue with dhcpdp on Bullseye
            echo ""
        fi

        if [ -d /opt/vc/lib ]; then
            echo "removing left over /opt/vc/lib"
            rm -rf /opt/vc/lib
        fi
        
        if [ -d /var/lib/dhcpcd5 ]; then
            echo "removing left over dhcpcd5"
            rm -rf /var/lib/dhcpcd5  
        fi
        
        
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt full-upgrade -y &
        wait
        apt-get --fix-missing
        apt --fix-broken install -y
        apt autoremove -y
	if [ -f /etc/systemd/system/dhcpcd.service.d/wait.conf ]; then
        	sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf # Fix potential issue with dhcpdp on Bullseye
	fi
        echo
        echo
        echo
        echo

        apt-get update -y
        apt-get update --fix-missing -y
        DEBIAN_FRONTEND=noninteractive apt upgrade -y &
        wait
	DEBIAN_FRONTEND=noninteractive apt upgrade -y &
        wait
        apt-get update --fix-missing -y
        apt --fix-broken install -y
	if [ -f /etc/systemd/system/dhcpcd.service.d/wait.conf ]; then
	    sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf # Fix potential issue with dhcpdp on Bullseye
        fi
	echo
        echo
        echo
        echo

        apt --fix-broken install -y
        apt autoremove -y
        #apt clean -y
        echo
        echo "Candle: Apt upgrade complete."
        echo "Candle: Apt upgrade complete." >> /dev/kmsg
        echo "Apt upgrade done" >> $BOOT_DIR/candle_log.txt
        echo


        if [ -f $BOOT_DIR/candle_original_version.txt ] || [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
            echo
            echo "rebooting"
            echo "$(date) - rebooting" >> $BOOT_DIR/candle_log.txt
            echo
        
            # make sure the system is read-write and accessible again after the reboot.
            touch $BOOT_DIR/candle_rw_once.txt
            #touch $BOOT_DIR/ssh.txt
        
            reboot
            sleep 60
            #echo "calling apt upgrade"
            #echo "Candle: doing apt upgrade" >> /dev/kmsg
            #echo "Candle: doing apt upgrade" >> $BOOT_DIR/candle_log.txt
            #DEBIAN_FRONTEND=noninteractive apt-get upgrade -y &
            #wait
            #echo
            #echo "Upgrade complete"
        fi
      
    fi
    
fi
apt update






# Download splash images
if [ "$SKIP_SPLASH" = no ] || [[ -z "${SKIP_SPLASH}" ]]; 
then
	if [ -f $BOOT_DIR/cmdline.txt ]; then
	    wget https://www.candlesmarthome.com/tools/error.png -O $BOOT_DIR/error.png --retry-connrefused 
	    echo
            echo "Candle: downloading splash images and videos"
	    echo "Candle: downloading splash images and videos" >> /dev/kmsg
	    echo "Candle: downloading splash images and videos" >> $BOOT_DIR/candle_log.txt
	    echo
	    
	    wget https://www.candlesmarthome.com/tools/splash_updating.png -O $BOOT_DIR/splash_updating.png --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash_updating180.png -O $BOOT_DIR/splash_updating180.png --retry-connrefused 
	    
	    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
	    then
	        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_updating.png" ]; then
	            echo "Candle: showing updating splash image" >> /dev/kmsg
	            echo "Candle: showing updating splash image" >> $BOOT_DIR/candle_log.txt
	            if [ -f $BOOT_DIR/rotate180.txt ]; then
	                /bin/ply-image $BOOT_DIR/splash_updating180.png
	                if ps aux | grep -q /usr/bin/startx; then
	                    DISPLAY=:0 feh --bg-fill $BOOT_DIR/splash_updating180.png
	                fi
	                    
	            else
	                /bin/ply-image $BOOT_DIR/splash_updating.png
	                if ps aux | grep -q /usr/bin/startx; then
	                    DISPLAY=:0 feh --bg-fill $BOOT_DIR/splash_updating.png
	                fi
	            fi
	        fi
	        
	        # Also start SSH
	        if [ -f $BOOT_DIR/developer.txt ] || [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
	            echo "Candle: starting ssh" >> /dev/kmsg
	            echo "Candle: starting ssh" >> $BOOT_DIR/candle_log.txt
	            systemctl start ssh.service
	        fi
	                
	    fi
	    
	    # Download the rest of the images
	    wget https://www.candlesmarthome.com/tools/splash.png -O $BOOT_DIR/splash.png --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash180.png -O $BOOT_DIR/splash180.png --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splashalt.png -O $BOOT_DIR/splashalt.png --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash180alt.png -O $BOOT_DIR/splash180alt.png --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash.mp4 -O $BOOT_DIR/splash.mp4 --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash180.mp4 -O $BOOT_DIR/splash180.mp4 --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash_preparing.png -O $BOOT_DIR/splash_preparing.png --retry-connrefused 
	    wget https://www.candlesmarthome.com/tools/splash_preparing180.png -O $BOOT_DIR/splash_preparing180.png --retry-connrefused 
	    
	fi
fi
















echo
echo "PRE-DOWNLOADING CONFIGURATION FILES FROM GITHUB"
echo


# Remove old left-over configuration files if they exist
if [ -d /home/pi/configuration-files ]; then
    echo "Warning, found a left over configuration-files directory"
    rm -rf /home/pi/configuration-files
fi

# Download ready-made settings files from the Candle github
if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    
    echo "Candle: Starting download of cutting edge configuration files"
    echo "Candle: Starting download of cutting edge configuration files" >> /dev/kmsg
    echo "Candle: Starting download of cutting edge configuration files" >> $BOOT_DIR/candle_log.txt
    git clone --depth 1 https://github.com/createcandle/configuration-files /home/pi/configuration-files
    if [ -d /home/pi/configuration-files ]; then
        rm /home/pi/configuration-files/LICENSE
        rm /home/pi/configuration-files/README.md
        rm -rf /home/pi/configuration-files/.git
    fi
    
else
    echo "Candle: Starting download of stable configuration files"
    echo "Candle: Starting download of stable configuration files" >> /dev/kmsg
    echo "Candle: Starting download of stable configuration files" >> $BOOT_DIR/candle_log.txt
    curl -s https://api.github.com/repos/createcandle/configuration-files/releases/latest \
    | grep "tarball_url" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | sed 's/,*$//' \
    | wget -qi - -O configuration-files.tar --retry-connrefused 

    tar -xf configuration-files.tar
    rm configuration-files.tar
    
    for directory in createcandle-configuration-files*; do
      [[ -d $directory ]] || continue
      echo "Directory: $directory"
      mv -- "$directory" ./configuration-files
    done
    
    rm ./configuration-files/LICENSE
    rm ./configuration-files/README.md
    rm -rf ./configuration-files/.git
    
fi


# Check if download succeeded
if [ ! -d /home/pi/configuration-files ]; then
    echo 
    echo "ERROR, failed to download latest configuration files"
    echo "Candle: ERROR, failed to download latest configuration files" >> /dev/kmsg
    echo "$(date) - failed to download latest configuration files" >> $BOOT_DIR/candle_log.txt
    echo "$(date) - failed to download latest configuration files" >> /home/pi/.webthings/candle.log
    echo "$(date) - failed to download latest configuration files" >> $BOOT_DIR/candle_log.txt
    echo
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
        /bin/ply-image $BOOT_DIR/error.png
        #sleep 7200
    fi
    
    exit 1
fi




mkdir -p /home/pi/.webthings/arduino
mkdir -p /home/pi/.webthings/arduino/.arduino15





# PRE-DOWNLOAD CANDLE CONTROLLER INSTALLER

if [[ -z "${SKIP_CONTROLLER}" ]] || [ "$SKIP_CONTROLLER" = no ]; 
then
    
    echo
    echo "PRE-DOWNLOADING CANDLE CONTROLLER"
    echo "Candle: starting download of Candle controller" >> /dev/kmsg
    echo "Candle: starting download of Candle controller" >> $BOOT_DIR/candle_log.txt
    echo

    cd $CANDLE_BASE
    #rm -rf /home/pi/webthings
    #rm -rf /home/pi/.webthings # too dangerous
    
    if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
        echo "Candle: Starting download of cutting edge controller install script"
        echo "Candle: Starting download of cutting edge controller install script" >> /dev/kmsg
        echo "Candle: Starting download of cutting edge controller install script" >> $BOOT_DIR/candle_log.txt
        echo
        wget https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh -O ./install_candle_controller.sh --retry-connrefused 
        
    else
        echo "Candle: Starting download of stable controller install script"
        echo "Candle: Starting download of stable controller install script" >> /dev/kmsg
        echo "Candle: Starting download of stable controller install script" >> $BOOT_DIR/candle_log.txt
        echo
        curl -s https://api.github.com/repos/createcandle/install-scripts/releases/latest \
        | grep "tarball_url" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O install-scripts.tar  --retry-connrefused 

        tar -xf install-scripts.tar
        rm install-scripts.tar
        
        for directory in createcandle-install-scripts*; do
          [[ -d $directory ]] || continue
          echo "Directory: $directory"
          mv -- "$directory" ./install-scripts
        done
        
        mv -f ./install-scripts/install_candle_controller.sh ./install_candle_controller.sh
        rm -rf ./install-scripts
        
        if [ -f /home/pi/latest_stable_controller.tar ]; then
            echo "warning, latest_stable_controller.tar already existed. Removing."
            rm /home/pi/latest_stable_controller.tar
        fi
        if [ -f /home/pi/latest_stable_controller.tar.txt ]; then
            echo "warning, latest_stable_controller.tar.txt already existed. Removing."
            rm /home/pi/latest_stable_controller.tar.txt
        fi
        
        echo "Candle: Starting download of stable controller tar"
        echo "Candle: Starting download of stable controller tar. Takes a while." >> /dev/kmsg
        echo "Candle: Starting download of stable controller tar" >> $BOOT_DIR/candle_log.txt
        wget -nv https://www.candlesmarthome.com/img/controller/latest_stable_controller.tar -O /home/pi/latest_stable_controller.tar --retry-connrefused 
        wget -nv https://www.candlesmarthome.com/img/controller/latest_stable_controller.tar.txt -O /home/pi/latest_stable_controller.tar.txt --retry-connrefused 
        
        if [ -f /home/pi/latest_stable_controller.tar ] && [ -f /home/pi/latest_stable_controller.tar.txt ]; then
            
            echo "controller tar & md5 downloaded OK"
            echo "Candle: controller tar & md5 downloaded OK" >> /dev/kmsg
            echo "Candle: controller tar & md5 downloaded OK" >> $BOOT_DIR/candle_log.txt
            
            if [ "$(md5sum latest_stable_controller.tar | awk '{print $1}')"  = "$(cat /home/pi/latest_stable_controller.tar.txt)" ]; then
                echo "MD5 checksum of latest_stable_controller.tar matched"
                
                chown pi:pi /home/pi/latest_stable_controller.tar
                
                if [ -f /home/pi/controller_backup_fresh.tar ]; then
                    rm /home/pi/controller_backup_fresh.tar
                fi
                
            else
                echo "Candle: Error, MD5 checksum of latest_stable_controller.tar did not match, bad download?"
                echo "Candle: Error, MD5 checksum of latest_stable_controller.tar did not match, bad download?" >> /dev/kmsg
                echo "Candle: Error, MD5 checksum of latest_stable_controller.tar did not match, bad download?" >> $BOOT_DIR/candle_log.txt
                
                if [ -f /home/pi/latest_stable_controller.tar ]; then
                    rm /home/pi/latest_stable_controller.tar
                fi
                if [ -f /home/pi/latest_stable_controller.tar.txt ]; then
                    rm /home/pi/latest_stable_controller.tar.txt
                fi
                
                # Show error image
                if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
                then
                    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                        /bin/ply-image $BOOT_DIR/error.png
                        #sleep 7200
                    fi
                fi
    
                #exit 1
            fi
            
        else
            echo "Candle: download of stable controller tar or md5 failed. Aborting."
            echo "Candle: Error, download of stable controller tar or md5 failed. Aborting." >> /dev/kmsg
            echo "$(date) - download of stable controller tar or md5 failed. Aborting." >> $BOOT_DIR/candle_log.txt
            
            if [ -f /home/pi/latest_stable_controller.tar ]; then
                rm /home/pi/latest_stable_controller.tar
            fi
            if [ -f /home/pi/latest_stable_controller.tar.txt ]; then
                rm /home/pi/latest_stable_controller.tar.txt
            fi
            
            # Show error image
            if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
            then
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                    /bin/ply-image $BOOT_DIR/error.png
                    #sleep 7200
                fi
            fi
    
            # exit 1
        fi
        
    fi
    
    
    # Check if the install_candle_controller.sh file now exists
    if [ ! -f install_candle_controller.sh ]; then
        echo
        echo "ERROR, missing install_candle_controller.sh file"
        echo "Candle: ERROR, missing install_candle_controller.sh file. Aborting." >> /dev/kmsg
        echo "$(date) - Failed to download install_candle_controller script" >> $BOOT_DIR/candle_log.txt
        echo "$(date) - Failed to download install_candle_controller script" >> /home/pi/.webthings/candle.log
        echo
    
        # Show error image
        if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
        then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                /bin/ply-image $BOOT_DIR/error.png
                #sleep 7200
            fi
        fi
    
        exit 1
        
    fi
    
fi




# APT UPGRADE

if [ "$SKIP_APT_UPGRADE" = no ] || [[ -z "${SKIP_APT_UPGRADE}" ]]; 
then
    echo
    echo "doing upgrade first"
    
    # Check if kernel or bootloader can be updated
    if apt list --upgradable | grep raspberrypi-bootloader; then
        echo "WARNING, BOOTLOADER IS STILL UPGRADEABLE"
        echo "WARNING, BOOTLOADER IS STILL UPGRADEABLE" >> /dev/kmsg
        echo "WARNING, BOOTLOADER IS STILL UPGRADEABLE" >> $BOOT_DIR/candle_log.txt
    fi
    if apt list --upgradable | grep raspberrypi-kernel; then
        echo "WARNING, KERNEL IS STILL UPGRADEABLE"
        echo "WARNING, KERNEL IS STILL UPGRADEABLE" >> /dev/kmsg
        echo "WARNING, KERNEL IS STILL UPGRADEABLE" >> $BOOT_DIR/candle_log.txt
    fi

    apt-get update -y
    apt --fix-broken install -y

    if [ -n "$(apt list --upgradable | grep raspberrypi-kernel)" ] || [ -n "$(apt list --upgradable | grep raspberrypi-bootloader)" ]; then
        echo "STRANGE ERROR, the kernel update should already be done at this point"
        echo "STRANGE ERROR, the kernel update should already be done at this point" >> /dev/kmsg
        echo "STRANGE ERROR, the kernel update should already be done at this point" >> $BOOT_DIR/candle_log.txt
        
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt upgrade -y &
        wait
        apt --fix-broken install -y
        sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf # Fix potential issue with dhcpdp on Bullseye
        echo ""
        
        
        if [ -f $BOOT_DIR/candle_original_version.txt ] || [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
            echo
            echo "rebooting"
            echo "$(date) - rebooting" >> $BOOT_DIR/candle_log.txt
            echo
        
            # make sure the system is read-write and accessible again after the reboot.
            touch $BOOT_DIR/candle_rw_once.txt
        
            reboot
            sleep 60
        fi
      
    else
    
        # TODO: it said "not allowing kernel updates", but then sets kernel to "unhold".. so...
        # Should kernel updates be held? Everything seems to update ok anyway.
    
        echo "doing system update, allowing kernel updates for now"
        echo "doing system update, allowing kernel updates for now" >> /dev/kmsg
        echo "doing system update, allowing kernel updates for now" >> $BOOT_DIR/candle_log.txt
        apt-mark unhold raspberrypi-kernel
        apt-mark unhold raspberrypi-kernel-headers 
        apt-mark unhold raspberrypi-bootloader
        
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt upgrade -y &
        wait
        apt --fix-broken install -y
        sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf # Fix potential issue with dhcpdp on Bullseye
        echo ""
        
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt upgrade -y &
        wait
        apt --fix-broken install -y
        sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf # Fix potential issue with dhcpdp on Bullseye
        echo ""

        apt autoremove
	
    fi
    
fi








# INSTALL PROGRAMS AND UPDATE
if [ "$SKIP_APT_INSTALL" = no ] || [[ -z "${SKIP_APT_INSTALL}" ]];
then
    echo
    echo "INSTALLING APPLICATIONS AND LIBRARIES"
    echo "Candle: installing packages and libraries" >> /dev/kmsg
    echo "Candle: installing packages and libraries" >> $BOOT_DIR/candle_log.txt
    echo


    # Update apt sources
    #set -e
    echo "calling apt update" >> /dev/kmsg
    echo "calling apt update" >> $BOOT_DIR/candle_log.txt 
    apt update -y
    apt-get update -y
    apt --fix-broken install -y
    echo

    
    # Just to be safe, try showing the splash images again
    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
    then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_updating.png" ]; then
            if [ -f $BOOT_DIR/rotate180.txt ]; then
                /bin/ply-image $BOOT_DIR/splash_updating180.png
                if ps aux | grep -q /usr/bin/startx; then
                    DISPLAY=:0 feh --bg-fill $BOOT_DIR/splash_updating180.png
                fi
                    
            else
                /bin/ply-image $BOOT_DIR/splash_updating.png
                if ps aux | grep -q /usr/bin/startx; then
                    DISPLAY=:0 feh --bg-fill $BOOT_DIR/splash_updating.png
                fi
            fi
        fi
    fi
    
    
    
    
    echo
    

#    set +e

    # Just to be safe, try showing the splash images again
    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
    then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_updating.png" ]; then
            if [ -f $BOOT_DIR/rotate180.txt ]; then
                /bin/ply-image $BOOT_DIR/splash_updating180.png
                if ps aux | grep -q /usr/bin/startx; then
                    DISPLAY=:0 feh --bg-fill $BOOT_DIR/splash_updating180.png
                fi
                    
            else
                /bin/ply-image $BOOT_DIR/splash_updating.png
                if ps aux | grep -q /usr/bin/startx; then
                    DISPLAY=:0 feh --bg-fill $BOOT_DIR/splash_updating.png
                fi
            fi
        fi
    fi
    
    
    echo
    #echo "installing Pipewire audio"
    #apt install pipewire-alsa pipewire-jack pipewire-pulse libspa-0.2-bluetooth pipewire-audio-client-libraries -y 

    # Install browser. Unfortunately its chromium, and not firefox, because its so much better at being a kiosk, and so much more customisable.
    # TODO: maybe use version 88?

    
    apt update

    # Install browser
	if [ "$SKIP_BROWSER" = no ] || [[ -z "${SKIP_BROWSER}" ]]; 
	then

		echo
    	echo "installing web browser"
    	echo "Candle: installing web browser" >> /dev/kmsg
    	echo "Candle: installing web browser" >> $BOOT_DIR/candle_log.txt
    	echo
 
		# from https://software.opensuse.org//download.html?project=home%3Aungoogled_chromium&package=ungoogled-chromium
  		wget https://ftp.gwdg.de/pub/opensuse/repositories/home%3A/ungoogled_chromium/Debian_Sid/arm64/ungoogled-chromium_112.0.5615.165-1_arm64.deb
		dpkg -i ungoogled-chromium_112.0.5615.165-1_arm64.deb
		rm ungoogled-chromium_112.0.5615.165-1_arm64.deb
		apt-get -f install --no-install-recommends

 		
	    #apt install $CHROMIUM_PACKAGE_NAME -y  --allow-change-held-packages --no-install-recommends
	    #if [ ! -f /bin/$CHROMIUM_PACKAGE_NAME ]; then
	    #    echo
	    #    echo "browser install failed, retrying."
	    #    apt purge $CHROMIUM_PACKAGE_NAME -y  --allow-change-held-packages
	    #    apt install $CHROMIUM_PACKAGE_NAME -y --allow-change-held-packages --no-install-recommends
	    #fi
    else
	    echo
	    echo "Skipping installation of browser"
	    echo
	fi

    echo
    echo "installing git"
    echo "Candle: installing git" >> /dev/kmsg
    echo "Candle: installing git" >> $BOOT_DIR/candle_log.txt
    echo
    apt -y install git "$reinstall" 


    echo
    echo "installing vlc"
    apt -y install vlc --no-install-recommends "$reinstall" #--print-uris

    #echo 'deb http://download.opensuse.org/repositories/home:/ungoogled_chromium/Debian_Bullseye/ /' | sudo tee /etc/apt/sources.list.d/home-ungoogled_chromium.list > /dev/null
    #curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Debian_Bullseye/Release.key' | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home-ungoogled_chromium.gpg > /dev/null
    #apt update
    #apt install ungoogled-chromium -y

    echo
    echo "installing build tools"
    for i in autoconf build-essential curl libbluetooth-dev libboost-python-dev libboost-thread-dev libffi-dev \
        libglib2.0-dev libpng-dev libcap2-bin libudev-dev libusb-1.0-0-dev pkg-config lsof python3-six; do
        
        echo "$i"
        apt  -y install "$i"  --print-uris "$reinstall"
        echo
    done


    # remove the Candle conf file, just in case it exists from an earlier install attempt
    #if [ -f /etc/mosquitto/mosquitto.conf ]; then
    #  rm /etc/mosquitto/mosquitto.conf
    #fi

    echo
    echo "installing support packages like ffmpeg, arping, libolm, sqlite, mosquitto"
    echo "Candle: installing support packages" >> /dev/kmsg
    echo "Candle: installing support packages" >> $BOOT_DIR/candle_log.txt
    echo

    # Debian Bookworm doesn't have libffi7 anymore
    for i in arping autoconf ffmpeg libswresample3 libtool mosquitto policykit-1 sqlite3 libolm3 libffi8 nbtscan ufw iptables liblivemedia-dev libcamera-apps libcamera-tools avahi-utils jq i2c-tools; do
            echo "$i"
            echo "Candle: installing $i" >> /dev/kmsg
            echo "Candle: installing $i" >> $BOOT_DIR/candle_log.txt
            apt -y install "$i" --no-install-recommends --print-uris "$reinstall" 
            echo
        done

    # Quick sanity check
    if [ ! -f /usr/sbin/mosquitto ]; then
        echo "Candle: WARNING, mosquitto failed to install the first time" >> /dev/kmsg
        echo "Candle: WARNING, mosquitto failed to install the first time" >> $BOOT_DIR/candle_log.txt
        apt -y --reinstall install mosquitto  
    fi


    # This essentially turns it into a desktop pi
    #apt install raspberrypi-ui-mods


    # additional programs for Candle kiosk mode:
    # not currently installing: Plymouth:  rpd-plym-splash
    echo
    echo "installing kiosk packages"
    echo

    apt install -y --no-install-recommends rtkit xsettingsd xinput xserver-xorg x11-xserver-utils xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base xfonts-75dpi xfonts-100dpi edid-decode libinput-tools libxcb-dpms0 xbacklight xserver-xorg-input-libinput xserver-xorg-input-mtrack

    # xserver-xorg-legacy
    #for i in lightdm xsettingsd rtkit xinput xserver-xorg x11-xserver-utils xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base xfonts-75dpi xfonts-100dpi edid-decode libinput-tools
    #do
    #    echo "$i"
    #    echo "Candle: installing $i" >> /dev/kmsg
    #    echo "Candle: installing $i" >> $BOOT_DIR/candle_log.txt
    #    apt-get -y --no-install-recommends install "$i"  "$reinstall" #--print-uris
    #    echo
    #done
    
    #apt-get install --no-install-recommends xserver-xorg x11-xserver-utils xserver-xorg-legacy xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools nbtscan -y

    # Camera support
    for i in python3-libcamera python3-picamera2 python3-kms++ python3-prctl libatlas-base-dev libopenjp2-7; do
        echo "$i"
        echo "Candle: installing $i" >> /dev/kmsg
        echo "Candle: installing $i" >> $BOOT_DIR/candle_log.txt
        apt install -y --no-install-recommends "$i"  "$reinstall" #--print-uris
        echo
    done
    
    echo
    echo "INSTALLING HOSTAPD AND DNSMASQ"
    echo "Candle: installing hostapd and dnsmasq" >> /dev/kmsg
    echo "Candle: installing hostapd and dnsmasq" >> $BOOT_DIR/candle_log.txt

    apt -y install dnsmasq  "$reinstall" #--print-uris
    systemctl disable dnsmasq.service
    systemctl stop dnsmasq.service
    

    echo 
    apt -y install hostapd "$reinstall" #--print-uris 
    systemctl unmask hostapd.service
    systemctl disable hostapd.service
    systemctl stop hostapd.service

    

    # Try to fix anything that may have gone wrong
    apt update
    apt-get update --fix-missing -y
    apt-get install -f -y
    apt --fix-broken install -y
    apt autoremove -y
    
    
    # Check if the binaries eactually exist
    for i in \
        hostapd \
        dnsmasq \
        openbox \
        xinit \
        mosquitto \
        wmctrl \
        ffmpeg \
        arping \
        ufw \
        sqlite3 \
        nbtscan \
        unclutter \
        xinput \
        jq \
        autoconf;
    do
        if [ -z "$(which $i)" ]; then
            echo "Candle: WARNING, $i binary not found. Reinstalling."  >> /dev/kmsg
            echo "Candle: WARNING, $i binary not found. Reinstalling."  >> $BOOT_DIR/candle_log.txt
            apt -y purge "$i"
            sleep 2
            apt install -y --no-install-recommends "$i"
        fi
    done


    # TODO: removed libffi7 / libffi8 check
    # removed libdbus-glib-1-dev (bluealsa now uses version 2 instead)
    # For bookworm libavcodec58 was changed to libavcodec59
    for i in \
    git autoconf build-essential curl libbluetooth-dev libboost-python-dev libboost-thread-dev libffi-dev \
    libglib2.0-dev libpng-dev libcap2-bin libudev-dev libusb-1.0-0-dev pkg-config lsof python3-six \
    arping autoconf ffmpeg libtool mosquitto policykit-1 sqlite3 libolm3 nbtscan ufw iptables \
    liblivemedia-dev libavcodec59 libswresample3 libffi8 libavformat59 \
    libasound2-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev \
    python3-kms++ python3-prctl libatlas-base-dev libopenjp2-7;
    do
        echo
        if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
            echo "$i installed OK"
        else
            echo
            echo "Candle: WARNING, $i did not install ok"
            dpkg -s "$i"
            
            echo
            echo "Candle: trying to install it again..."
            apt -y purge "$i"
            sleep 2
            apt install -y --no-install-recommends "$i"
            
            echo
            if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
                echo "$i installed OK"
            else
                echo
                echo "Candle: ERROR, $i package still did not install. Aborting..." >> /dev/kmsg
                #echo "Candle: ERROR, $i package still did not install. Aborting..." >> /home/pi/.webthings/candle.log
                echo "Candle: ERROR, $i package still did not install. Aborting..." >> $BOOT_DIR/candle_log.txt
                dpkg -s "$i"
                
                # Show error image
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/error.png" ]; then
                    /bin/ply-image $BOOT_DIR/error.png
                    #sleep 7200
                fi
    
                exit 1
            fi
        fi
    done
    
    
    # again, but this time with 'no-install-recommends'
    # removed xserver-xorg-legacy
    for i in \
    vlc \
    xinput xserver-xorg x11-xserver-utils xinit openbox wmctrl xdotool feh fbi unclutter lsb-release xfonts-base libinput-tools;
    do
        echo
        if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
            echo "$i installed OK"
        else
            echo
            echo "Candle: WARNING, $i did not install ok"
            dpkg -s "$i"
            
            echo
            echo "Candle: trying to install it again..."
            apt -y purge "$i"
            sleep 2
            apt -y --no-install-recommends install "$i"
            
            echo
            if [ -n "$(dpkg -s $i | grep 'install ok installed')" ]; then
                echo "$i installed OK"
            else
                echo
                echo "Candle: ERROR, $i package still did not install. Aborting..." >> /dev/kmsg
                #echo "Candle: ERROR, $i package still did not install. Aborting..." >> /home/pi/.webthings/candle.log
                echo "Candle: ERROR, $i package still did not install. Aborting..." >> $BOOT_DIR/candle_log.txt
                dpkg -s "$i"
                
                # Show error image
                if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
                then
                    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/error.png" ]; then
                        /bin/ply-image $BOOT_DIR/error.png
                        #sleep 7200
                    fi
                fi
    
                exit 1
            fi
        fi
    done
    
fi


# Superfluous?
if [ "$SKIP_APT_UPGRADE" = no ] || [[ -z "${SKIP_APT_UPGRADE}" ]]; 
then
    echo
    echo "RUNNING APT UPGRADE"
    echo "Candle: running apt upgrade command" >> /dev/kmsg
    echo "Candle: running apt upgrade command" >> $BOOT_DIR/candle_log.txt
    echo
    #apt upgrade -y
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt upgrade -y &
    wait
    echo ""
    
    # Fix potential issue with dhcpdp on Bullseye
    if [ -f /etc/systemd/system/dhcpcd.service.d/wait.conf ]; then
        sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /etc/systemd/system/dhcpcd.service.d/wait.conf
    fi
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
    echo "Candle: error GIT failed to install" >> $BOOT_DIR/candle_log.txt
    
    # Show error image
    if [ "$scriptname" = "bootup_actions.sh" ] || [ "$scriptname" = "bootup_actions_failed.sh" ] || [ "$scriptname" = "post_bootup_actions.sh" ] || [ "$scriptname" = "post_bootup_actions_failed.sh" ];
    then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/error.png" ]; then
            /bin/ply-image $BOOT_DIR/error.png
            #sleep 7200
        fi
    fi
    
    exit 1
fi


apt-get install -y --no-install-recommends --fix-missing



# PYTHON

echo "checking if $CANDLE_BASE/.local/bin exists"

#PATH=$PATH:/home/pi/.local/bin
if [ -d "$CANDLE_BASE/.local/bin" ]
then
    echo "could add to path here"
	#echo "Adding $CANDLE_BASE/.local/bin to path var"
    #[[ ":$PATH:" != *":$CANDLE_BASE/.local/bin:"* ]] && PATH="$CANDLE_BASE/.local/bin:${PATH}"
else
    echo "WARNING, /home/pi/.local/bin does not exist"
fi











echo
echo "INSTALLING AND UPDATING PYTHON PACKAGES"
echo

echo
echo "installing pip3"
echo

apt update
apt install -y python3-pip


# Allow python packages to be installed globally (since the disk will be read-only anyway)
if [ -f /etc/pip.conf ]
then
	if cat /etc/pip.conf | grep -q break-system-packages
	then
		echo "pip break-system-packages already set"
	else 
		echo "setting pip break-system-packages conf"
		echo "break-system-packages = true" >> /etc/pip.conf
	fi
else
    echo "adding break-system-packages to pip.conf"
	
	echo "[global]" > /etc/pip.conf
	echo "break-system-packages = true" >> /etc/pip.conf
	chown pi:pi /etc/pip.conf
fi
	



# update pip
#sudo -u pi /usr/bin/python3 -m pip install --upgrade pip

# upgrade pip first
sudo -u pi python3 -m pip install --upgrade pip

# python3-iffr doesn't exist? so removed, replaced by python3-cffi
apt install -y --no-install-recommends python3-dbus python3-cffi python3-gpiozero python3-pil python3-wheel python3-requests python3-distro python3-certifi python3-urllib3 python3-colorzero python3-chardet python3-libevdev python3-numpy python3-bluetooth
sudo -u pi pip3 uninstall -y adapt-parser || true
sudo -u pi pip3 install pycryptodomex --break-system-packages

#sudo -u pi pip3 install --break-system-packages git+https://github.com/pybluez/pybluez.git#egg=pybluez
sudo -u pi pip3 install --break-system-packages git+https://github.com/pybluez/pybluez.git#egg=pybluez 


echo "Updating existing python packages"
sudo -u pi pip3 install --upgrade ssh-import-id --break-system-packages

#echo "Installing Python gateway_addon"
#sudo -u pi python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon





# RASPI CONFIG
#echo "Set Raspi-config I2C, SPI, Camera"

if [ -d /sys/kernel/config/device-tree ]
then
    echo "Enabling I2C, SPI, Camera support"

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





echo "install seeed respeaker voicecard drivers?"

# RESPEAKER HAT
if [ "$SKIP_RESPEAKER" = no ] || [[ -z "${SKIP_RESPEAKER}" ]]
then
    
	echo
	echo "INSTALLING RESPEAKER HAT DRIVERS"
	echo
	
	apt-get update
	cd $CANDLE_BASE
	git clone --depth 1 https://github.com/HinTak/seeed-voicecard.git
	
	if [ -d seeed-voicecard ]; then
	    cd seeed-voicecard
	
	    if [ ! -f /home/pi/candle/installed_respeaker_version.txt ]; then
		mkdir -p /home/pi/candle
		#touch /home/pi/candle/installed_respeaker_version.txt
		cp ./dkms.conf /home/pi/candle/installed_respeaker_version.txt
	    fi
	
	    if [ -d "/etc/voicecard" ] && [ -f /bin/seeed-voicecard ];
	    then
		echo "ReSpeaker was already installed"
	
		if ! diff -q ./dkms.conf /home/pi/candle/installed_respeaker_version.txt &>/dev/null; then
		    echo "ReSpeaker has an updated version!"
		    echo "ReSpeaker has an updated version! Attempting to install" >> /dev/kmsg
		    echo "ReSpeaker has an updated version! Attempting to install" >> $BOOT_DIR/candle_log.txt
		    ./uninstall.sh
		    echo -e 'N\n' | ./install.sh
		    cp ./dkms.conf /home/pi/candle/installed_respeaker_version.txt
		else
		    echo "not a new respeaker version" >> /dev/kmsg
		fi
	
	    else
		echo "Doing initial ReSpeaker install"
		echo -e 'N\n' | ./install.sh
	    fi
	
	    cd $CANDLE_BASE
	    rm -rf seeed-voicecard
	
	else
	    echo "Error, failed to download respeaker source"
	fi
        
    #else
    #    echo "$BOOT_DIR/candle_original_version.txt already existed, skipping respeaker driver install"
    #fi
    
    
else
    echo
    echo "Candle: skipping ReSpeaker drivers install"
    echo "Candle: skipping ReSpeaker drivers install" >> /dev/kmsg
    echo "Candle: skipping ReSpeaker drivers install" >> $BOOT_DIR/candle_log.txt
    echo
fi



# Experiment: install mode modern pipewire bluetooth audio option
apt install -y pipewire libspa-0.2-bluetooth
raspi-config nonint do_audioconf 2

if [ -f /etc/bluetooth/main.conf ]; then
    sed -i 's/#JustWorksRepairing.*/JustWorksRepairing = always/' /etc/bluetooth/main.conf
fi



# BLUEALSA
if [ "$SKIP_BLUEALSA" = no ] || [ -z "${SKIP_BLUEALSA}" ]
then
    
    echo
    echo "INSTALLING BLUEALSA BLUETOOTH SPEAKER DRIVERS"
    echo "Candle: building BlueAlsa (audio streaming)" >> /dev/kmsg
    echo "Candle: building BlueAlsa (audio streaming)" >> $BOOT_DIR/candle_log.txt
    echo
    
    
    # for BlueAlsa
    echo "installing bluealsa support packages"
    apt-get install -y --no-install-recommends git automake build-essential libtool pkg-config python3-docutils python3-bluetooth
    apt-get install -y --no-install-recommends libasound2-dev libbluetooth-dev libdbus-1-dev libglib2.0-dev libsbc-dev libmp3lame-dev libspandsp-dev 
    
    
    #for i in libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev python3-bluetooth; do
    #    echo "$i"
    #    echo "Candle: installing $i" >> /dev/kmsg
    #    echo "Candle: installing $i" >> $BOOT_DIR/candle_log.txt
    #    apt -y install "$i" "$reinstall"  #--print-uris
    #    echo
    #done
    #apt install libasound2-dev libdbus-glib-1-dev libgirepository1.0-dev libsbc-dev libmp3lame-dev libspandsp-dev -y


    
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
    echo "Candle: Skipping BlueAlsa build"
    echo "Candle: Skipping BlueAlsa build" >> /dev/kmsg
    echo "Candle: Skipping BlueAlsa build" >> $BOOT_DIR/candle_log.txt
fi

cd $CANDLE_BASE
rm -rf bluez-alsa






# sudo update-rc.d gateway-iptables defaults

# TODO: also need to look closer at this: https://github.com/WebThingsIO/gateway/tree/37591f4be3542901255da3c901396f3e9b8a443b/image/etc




echo ""
echo "INSTALLING RECOVERY PARTITION"
echo ""

# only install the recovery partition if the system has a recovery partition
if lsblk | grep -q 'mmcblk0p4'; then

    cd $CANDLE_BASE/.webthings
    
    if [ -f recovery.fs ]; then
        echo "Warning, recovery.fs already existed. Removing it first."
        rm recovery.fs
    fi
    
    echo "Downloading the recovery partition"
    echo "Downloading the recovery partition" >> /dev/kmsg
    echo "Downloading the recovery partition" >> $BOOT_DIR/candle_log.txt
    
    wget https://www.candlesmarthome.com/img/recovery/recovery.fs.tar.gz -O recovery.fs.tar.gz --retry-connrefused 

    if [ -f recovery.fs.tar.gz ]; then
        echo "untarring the recovery partition"
        tar xf recovery.fs.tar.gz

        if [ -f recovery.fs ]; then # -n is for "non-zero string"
            #echo "Mounting the recovery partition"
            #losetup --partscan /dev/loop0 recovery.img

            echo "Copying recovery partition data"
            echo "Copying recovery partition data" >> /dev/kmsg
            echo "Copying recovery partition data" >> $BOOT_DIR/candle_log.txt
            dd if=recovery.fs of=/dev/mmcblk0p3 bs=1M

            #if [ -n "$(lsblk | grep loop0p2)" ] && [ -n "$(lsblk | grep mmcblk0p3)" ]; then 
            #fi
        else
            echo "ERROR, failed to download or extract the recovery disk image"
            echo "ERROR, failed to download or extract the recovery disk image" >> /dev/kmsg
            echo "ERROR, failed to download or extract the recovery disk image" >> $BOOT_DIR/candle_log.txt
        fi

        rm recovery.fs.tar.gz
        rm recovery.fs
    else
        echo "ERROR, recovery partition file not downloaded"
    
        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
            /bin/ply-image $BOOT_DIR/error.png
            #sleep 7200
        fi
        
        exit 1
    fi
fi







echo ""
echo "Installing other files and services"
echo ""

systemctl stop triggerhappy.socket
systemctl stop triggerhappy.service

# switch back to root of home folder
cd "$CANDLE_BASE"

# Make folders that should be owned by Pi user
mkdir /home/pi/Arduino
chown pi:pi /home/pi/Arduino

mkdir /home/pi/.arduino15
chown pi:pi /home/pi/.arduino15

mkdir -p /home/pi/.webthings/arduino/.arduino15
mkdir -p /home/pi/.webthings/arduino/Arduino

chown pi:pi /home/pi/.webthings/arduino/.arduino15
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

# TODO: would this help with mosquitto?
#addgroup -S -g 1883 mosquitto 2>/dev/null && \
#adduser -S -u 1883 -D -H -h /var/empty -s /sbin/nologin -G mosquitto -g mosquitto mosquitto 2>/dev/null && \

# Make folders that should be owned by root
mkdir -p /home/pi/.webthings/var/lib/bluetooth
mkdir -p /home/pi/.webthings/etc/wpa_supplicant
#mkdir -p /home/pi/.webthings/etc/NetworkManager/
mkdir -p /home/pi/.webthings/etc/ssh

if [ -d /etc/NetworkManager/system-connections ]; then
	rm /etc/NetworkManager/system-connections/*
	#cp -r /etc/NetworkManager/* /home/pi/.webthings/etc/NetworkManager/
fi

#echo "Candle: moving and copying directories so fstab works" >> /dev/kmsg

if [ -f /etc/bluetooth/main.conf ]; then
    if cat /etc/bluetooth/main.conf | grep -q "Experimental=true" 
    then
        echo "Bluetooth experimental already enabled"
    else 
        echo "Enabling Bluetooth experimental"
        #echo "Experimental=true" >> /etc/bluetooth/main.conf
	sed -i 's/#Experimental = false/Experimental=true/' /etc/bluetooth/main.conf
    fi
fi


if [ ! -d /home/pi/.webthings/tmp ]; then
    mkdir -p /home/pi/.webthings/tmp
    rm -rf /tmp/*
    echo "cleared tmp contents"
    ls -l -a /tmp
    cp -r /tmp/* /home/pi/.webthings/tmp
fi
mkdir -p /home/pi/.webthings/tmp
chmod 1777 /home/pi/.webthings/tmp
find /home/pi/.webthings/tmp \
    -mindepth 1 \
    -name '.*-unix' -exec chmod 1777 {} + -prune -o \
    -exec chmod go-rwx {} +


# Prepare a location for Matter settings
mkdir /home/pi/.webthings/hasdata
ln -s /home/pi/.webthings/hasdata /data
chown pi:pi /data
chown pi:pi /home/pi/.webthings/hasdata


# COPY FILES

cd $CANDLE_BASE



# PREPARE FOR BINDS IN FSTAB
echo "generating ssh, wpa_supplicant and bluetooth folders on user partition"

mkdir -p /home/pi/.webthings/arduino
mkdir -p /home/pi/.webthings/arduino/Arduino
mkdir -p /home/pi/.webthings/arduino/.arduino15

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

if [ -d /home/pi/configuration-files ]; then

    echo "Copying configuration files into place"
    echo "Candle: Copying configuration files into place" >> /dev/kmsg
    echo "Candle: Copying configuration files into place" >> $BOOT_DIR/candle_log.txt
    
    rm /home/pi/configuration-files/LICENSE
    rm /home/pi/configuration-files/README.md
    rm -rf /home/pi/configuration-files/.git
    
    if [ -d /home/pi/candle/configuration-files-backup ]; then
        rm -rf /home/pi/candle/configuration-files-backup/*
        echo "Updating backup of the configuration files" >> /dev/kmsg
        echo "Updating backup of the configuration files" >> $BOOT_DIR/candle_log.txt
    else
        echo "Creating intial backup of the configuration files" >> /dev/kmsg
        echo "Creating intial backup of the configuration files" >> $BOOT_DIR/candle_log.txt
        mkdir -p /home/pi/candle/configuration-files-backup
    fi
    
    echo
    echo "copying configuration-files to configuration-files-backup"
    cp -r /home/pi/configuration-files/* /home/pi/candle/configuration-files-backup
    
    echo
    echo "Doing rsync from configuration-files-backup"
    rsync -vr --inplace /home/pi/candle/configuration-files-backup/* /
    echo "Configuration files should be copied" >> /dev/kmsg
    echo "Configuration files should be copied" >> $BOOT_DIR/candle_log.txt
    
else
   
    echo "Error, configuration files directory missing"
    echo "Candle: Error, configuration files directory missing" >> /dev/kmsg
    echo "Error, configuration files directory missing" >> $BOOT_DIR/candle_log.txt
fi



#if [ ! -f $BOOT_DIR/candle_config_version.txt ]; then
#    touch $BOOT_DIR/candle_config_version.txt
#fi
#if ! diff -q /home/pi/configuration-files/boot/candle_config_version.txt $BOOT_DIR/candle_config_version.txt &>/dev/null; 
#then
#    echo "Different config version, intiating Rsync"
#    echo "Candle: Different config version, intiating Rsync" >> /dev/kmsg
#    rsync -vr /home/pi/configuration-files/ /
#else
#    echo "No new config version detected"
#fi

# This is handled by prepare_disk_image
#if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
#    if [ -f /home/pi/candle/candle_first_run.sh ]; then
#        cp /home/pi/candle/candle_first_run.sh $BOOT_DIR/candle_first_run.sh
#    fi
#fi
#chmod +x /home/pi/candle_first_run.sh

mkdir -p /home/pi/.webthings/uploads
chown -R pi:pi /home/pi/.webthings/uploads

if [ ! -f /home/pi/candle/early.sh ]; then
    echo "ERROR, early.sh is missing?"
    exit 1
fi

# CHMOD THE NEW FILES
chmod +x /home/pi/candle/early.sh
chmod +x /etc/rc.local
chmod +x /home/pi/candle/reboot_to_recovery.sh
chmod +x /etc/xdg/openbox/autostart
chmod +x /home/pi/candle/late.sh
chmod +x /home/pi/candle/kiosk.sh
chmod +x /home/pi/candle/every_minute.sh
chmod +x /home/pi/candle/debug.sh
chmod +x /home/pi/candle/files_check.sh
chmod +x /home/pi/candle/install_samba.sh
chmod +x /home/pi/candle/prepare_for_disk_image.sh
chmod +x /home/pi/candle/unsnap.sh



# CHOWN THE NEW FILES
chown pi:pi /home/pi/*
chown -R pi:pi /home/pi/candle
chown -R pi:pi /home/pi/.config

chown -R pi:pi /home/pi/.webthings/etc/mosquitto
chmod 0700 /home/pi/.webthings/etc/mosquitto/mosquitto_users

chown pi:pi /home/pi/.webthings/etc/webthings_settings_backup.js
chown pi:pi /home/pi/.webthings/etc/webthings_settings.js
chown pi:pi /home/pi/.webthings/etc/webthings_tunnel_default.js






# ADD SYMLINKS

# Create symlink for .asoundrc
if [ ! -L /home/pi/.asoundrc ]; then
    if [ -f /home/pi/.webthings/etc/asoundrc ]; then
        echo "Creating symlink from /home/pi/.asoundrc to /home/pi/.webthings/etc/asoundrc"
        if [ -f /home/pi/.asoundrc ]; then
	    rm /home/pi/.asoundrc
        fi
        ln -s /home/pi/.webthings/etc/asoundrc /home/pi/.asoundrc
    fi
fi

# make libffi.so.6 "available" for python (voco) by linking to the newer version
if [ -d /usr/lib/aarch64-linux-gnu ]; then
  if [ ! -f /usr/lib/aarch64-linux-gnu/libffi.so.6 ] && [ -f /usr/lib/aarch64-linux-gnu/libffi.so.7 ]; then
    if [ ! -L /usr/lib/aarch64-linux-gnu/libffi.so.6 ]; then
      echo "creating symlink for  libffi.so.6 -> libffi.so.7"
      ln -s /usr/lib/aarch64-linux-gnu/libffi.so.7 /usr/lib/aarch64-linux-gnu/libffi.so.6
    fi
  fi
fi

# Create locations on the user partition for time
if [ ! -L /etc/localtime ]; then
    echo "creating symlink for /etc/localtime"
    mkdir -p /home/pi/.webthings/etc
    if [ ! -f /home/pi/.webthings/etc/localtime ]; then
        echo "copying localtime file into position"
        cp /etc/localtime /home/pi/.webthings/etc/localtime
    fi
    rm /etc/localtime
    ln -s /home/pi/.webthings/etc/localtime /etc/localtime
fi


# Creating symlink for timezone
if [ ! -L /etc/timezone ]; then
    echo "removing /etc/timezone file and creating a symlink to /home/pi/.webthings/etc/timezone instead"
    # move timezone file to user partition
    if [ ! -f /home/pi/.webthings/etc/timezone ]; then
        echo "copying /etc/timezone to /home/pi/.webthings/etc/timezone"
        cp --verbose /etc/timezone /home/pi/.webthings/etc/timezone
    fi
    rm /etc/timezone
    ln -s /home/pi/.webthings/etc/timezone /etc/timezone
fi


# Create symlink for fake-hwclock
if [ ! -L /etc/fake-hwclock.data ]; then
    echo "removing /etc/fake-hwclock.data file and creating a symlink to /home/pi/.webthings/etc/fake-hwclock.data instead"
    # create fake-hwclock file
    if [ ! -f /home/pi/.webthings/etc/fake-hwclock.data ]; then
        echo "copying /etc/fake-hwclock.data to /home/pi/.webthings/etc/fake-hwclock.data"
        cp --verbose /etc/fake-hwclock.data /home/pi/.webthings/etc/fake-hwclock.data
    fi
    rm /etc/fake-hwclock.data
    ln -s /home/pi/.webthings/etc/fake-hwclock.data /etc/fake-hwclock.data
fi


# Create location on the user partition for language
if [ ! -L /etc/default/locale ]; then
    echo "creating symlink for /etc/default/locale"
    mkdir -p /home/pi/.webthings/etc/default
    if [ ! -f /home/pi/.webthings/etc/default/locale ]; then
        echo "copying locale file into position"
        cp /etc/default/locale /home/pi/.webthings/etc/default/locale
    fi
    rm /etc/default/locale
    ln -s /home/pi/.webthings/etc/default/locale /etc/default/locale
fi






#chown mosquitto: /home/pi/.webthings/etc/mosquitto/zcandle.conf
#chown mosquitto: /home/pi/.webthings/etc/mosquitto/mosquitto.conf



# ENABLE SERVICES
echo
echo "ENABLING AND DISABLING SERVICES"
echo "Candle: enabling services" >> /dev/kmsg
echo "Candle: enabling services" >> $BOOT_DIR/candle_log.txt
echo
#systemctl daemon-reload

# disable triggerhappy. Wait, is this used to switch to the tty output?
#systemctl disable triggerhappy.socket
#systemctl disable triggerhappy.service


# enable Candle services
systemctl enable candle_first_run.service
#systemctl enable candle_start_swap.service
systemctl enable candle_early.service
systemctl enable candle_late.service 
systemctl enable candle_kiosk.service
systemctl enable candle_every_minute.timer
systemctl enable candle_splashscreen.service
systemctl enable candle_splashscreen180.service
systemctl enable candle_reboot.service
systemctl enable candle_reboot180.service
systemctl enable candle_splashscreen_updating.service
systemctl enable candle_splashscreen_updating180.service
systemctl enable candle_hostname_fix.service # ugly solution, might not even be necessary anymore? Nope, tested, still needed.
# TODO: the candle_early script also seems to apply the hostname fix (and restart avahi-daemon). Then again, can't hurt to have redundancy.

# disable old splash screen
systemctl disable splashscreen.service

# enable BlueAlsa services
systemctl enable bluealsa.service 
systemctl enable bluealsa-aplay.service 

# Webthings Gateway
systemctl enable webthings-gateway.service
systemctl disable webthings-gateway.check-for-update.service
systemctl disable webthings-gateway.check-for-update.timer
systemctl disable webthings-gateway.update-rollback.service

# disable apt services
systemctl disable apt-daily.service
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.service

# disable man-db timer
systemctl disable man-db.timer

# disable modemManager
systemctl disable ModemManager.service

#disable wpa_supplicant service because dhpcpcd is managing it. Otherwise it runs twice.
systemctl disable wpa_supplicant.service


# enable half-hourly save of time
systemctl enable fake-hwclock-save.service

# Hide the login text (it will still be available on tty3 - connect a keyboard to your pi and press CTRl-ALT-F3 to see it)
systemctl enable getty@tty3.service
systemctl disable getty@tty1.service


if [ -f /home/pi/candle/ready.sh ]; then
    systemctl disable gateway-iptables.service
fi



# Automatically restart the controller on serious crashes
if [ -f /etc/sysctl.conf ]; then
    if cat /etc/sysctl.conf | grep -q kernel.panic; then
        sed -i 's/.*kernel.panic.*/kernel.panic = 6/' /etc/sysctl.conf
    else
        echo "kernel.panic = 5" >> /etc/sysctl.conf
    fi
fi

if [ -f /etc/systemd/system.conf ]; then
    sed -i 's/.*RuntimeWatchdogSec.*/RuntimeWatchdogSec=15s/' /etc/systemd/system.conf
    sed -i 's/.*RebootWatchdogSec.*/RebootWatchdogSec=5min/'  /etc/systemd/system.conf
    #sed -i 's/.*DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=90s/' /etc/systemd/system.conf
fi


# KIOSK

if [ -f $BOOT_DIR/config.txt ]; then

    # Hides the Raspberry Pi logos normally shown at boot

    if [ $(cat $BOOT_DIR/config.txt | grep -c "disable_splash") -eq 0 ];
    then
    	echo "- Adding disable_splash to config.txt"
    	echo 'disable_splash=1' >> $BOOT_DIR/config.txt
    else
        echo "- Splash was already disabled in config.txt"
    fi

    # add HDMI always on
    #if [ $(cat $BOOT_DIR/config.txt | grep -c "hdmi_force_hotplug") -eq 0 ];
    #then
    # 	echo "- Adding hdmi_force_hotplug=1 to config.txt"
    #	echo 'hdmi_force_hotplug=1' >> $BOOT_DIR/config.txt
    #else
    #    echo "- hdmi_force_hotplug was already in config.txt"
    #    if [ $(cat $BOOT_DIR/config.txt | grep -c "#hdmi_force_hotplug=1") -eq 0 ];
    #    then
    #        sed -i 's|#hdmi_force_hotplug=1|hdmi_force_hotplug=1|g' $BOOT_DIR/config.txt
    #        
    #    fi
    #fi


    # Hide the text normally shown when linux boots up
    isInFile=$(cat $BOOT_DIR/cmdline.txt | grep -c "tty3")
    if [ $isInFile -eq 0 ]
    then    
    	echo "- Modifying cmdline.txt"
        echo "Candle: adding kiosk parameters to cmdline.txt" >> /dev/kmsg
        echo "Candle: adding kiosk parameters to cmdline.txt" >> $BOOT_DIR/candle_log.txt
    	# change text output to third console. press alt-shift-F3 during boot to see it again.
        sed -i ' 1 s/tty1/tty3/' $BOOT_DIR/cmdline.txt
        
        echo "cmdline in between after switchting tty to 3:"
        cat $BOOT_DIR/cmdline.txt
        echo
        
    	# hide all the small things normally shown at boot
    	sed -i ' 1 s/.*/& quiet plymouth.ignore-serial-consoles splash logo.nologo vt.global_cursor_default=0/' $BOOT_DIR/cmdline.txt   
        
        echo "cmdline in between after hiding kiosk:"
        cat $BOOT_DIR/cmdline.txt
        echo     
    else
        echo "- The cmdline.txt file was already modified"
        echo "Candle: cmdline.txt kiosk parameters were already present" >> /dev/kmsg
        echo "Candle: cmdline.txt kiosk parameters were already present" >> $BOOT_DIR/candle_log.txt
    fi
    
    # Use the older display driver for now, as this solves many audio headaches.
    # https://github.com/raspberrypi/linux/issues/4543
    
	#echo "setting fkms display driver"
    #sed -i "s/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/" $BOOT_DIR/config.txt


    # Set more power for USB ports
    isInFile3=$(cat $BOOT_DIR/config.txt | grep -c "max_usb_current")
    if [ $isInFile3 -eq 0 ]
    then
    	echo "- Setting USB to deliver more current in config.txt"
    	echo "max_usb_current=1" >> $BOOT_DIR/config.txt
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
rm /etc/xdg/openbox/rc.xml
wget https://www.candlesmarthome.com/tools/rc.xml -O /etc/xdg/openbox/rc.xml --retry-connrefused 

# Modify the xinitrc file to automatically log in the pi user
#echo "- Creating xinitrc file"
#echo "exec openbox-session" > /etc/X11/xinit/xinitrc

echo "- Creating xwrapper.config file"
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config

# give Pi user rights to TTY
usermod -a -G tty pi




# ADD CHROMIUM POLICY

# Add policy file to disable things like file selection
mkdir -p /etc/chromium/policies/managed/
echo '{"AllowFileSelectionDialogs": false, "AudioCaptureAllowed": false, "AutoFillEnabled": false, "PasswordManagerEnabled": false}' > /etc/chromium/policies/managed/candle.json





echo




# TODO:

# ~/.config/configstore/update-notifier-npm.json <- set output to true
# Respeaker drivers?

# update python libraries except for 2 (schemajson and... )
# pip3 list --outdated
# not to be updated:
# - websocket-client
# - jsonschema (if memory serves)











# CREATE INITIAL BACKUPS

cd $CANDLE_BASE


# important boot files backup
if [ ! -f /etc/rc.local.bak ]; then
    cp /etc/rc.local /etc/rc.local.bak
fi
if [ -f /home/pi/candle/early.sh ]; then
    if [ ! -f /home/pi/candle/early.sh.bak ]; then
        cp /home/pi/candle/early.sh /home/pi/candle/early.sh.bak
    fi
else
    echo
    echo "ERROR, early.sh does not exist!"
fi    

if [ -f /etc/xdg/openbox/autostart ]; then
    if [ ! -f /etc/xdg/openbox/autostart.bak ]; then
        cp /etc/xdg/openbox/autostart /etc/xdg/openbox/autostart.bak
    fi
else
    echo "ERROR, autostart does not exist"
fi




# Download some more splash screens
if [ ! -f "$BOOT_DIR/splash_updating-0.png" ]; then
    echo "Downloading progress bar images"
    wget https://www.candlesmarthome.com/tools/splash_updating-0.png -O $BOOT_DIR/splash_updating-0.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating-1.png -O $BOOT_DIR/splash_updating-1.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating-2.png -O $BOOT_DIR/splash_updating-2.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating-3.png -O $BOOT_DIR/splash_updating-3.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating-4.png -O $BOOT_DIR/splash_updating-4.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating-5.png -O $BOOT_DIR/splash_updating-5.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating180-0.png -O $BOOT_DIR/splash_updating180-0.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating180-1.png -O $BOOT_DIR/splash_updating180-1.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating180-2.png -O $BOOT_DIR/splash_updating180-2.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating180-3.png -O $BOOT_DIR/splash_updating180-3.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating180-4.png -O $BOOT_DIR/splash_updating180-4.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/splash_updating180-5.png -O $BOOT_DIR/splash_updating180-5.png --retry-connrefused 
    wget https://www.candlesmarthome.com/tools/error.png -O $BOOT_DIR/error.png --retry-connrefused 
fi




# CLEANUP

echo
echo "CLEANING UP"
echo
echo "Candle: almost done, cleaning up" >> /dev/kmsg
echo "Candle: almost done, cleaning up" >> $BOOT_DIR/candle_log.txt

# Clean NPM cache
export NVM_DIR="/home/pi/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
npm cache clean --force # already done in install_candle_controller script

echo "Clearing Apt leftovers"
apt clean -y
apt-get clean -y
#apt remove --purge
apt autoremove -y
rm -rf /var/lib/apt/lists/*

find /tmp -type f -atime +10 -delete

# SAVE STATE OF INSTALLED PACKAGES

# Generate file that can be used to re-install this exact combination of Python packages's versions
pip3 list --format=freeze > /home/pi/candle/candle_requirements.txt

# Create file that simply lists the installed packages and their versions
#apt list --installed 2>/dev/null | grep -v -e "Listing..." | sed 's/\// /' | awk '{print $1 "=" $3}' > /home/pi/candle/candle_packages.txt

# Create a script that could re-install all those packages if the sources were available. 
# However, the Raspberry servers only serve the very latest versions, so this is moot.
#apt list --installed 2>/dev/null | grep -v -e "apt/" -e "apt-listchanges/" -e "apt-utils/" -e "libapt-" -e "Listing..." | sed 's/\// /' | awk '{print "apt -y --reinstall install " $1 "=" $3}' > /home/pi/candle/candle_packages_installer.sh

# Prepare for potential download of all current versions of the packages
#mkdir -p /home/pi/.webthings/deb_packages
#chown pi:pi /home/pi/.webthings/deb_packages
#apt list --installed 2>/dev/null | grep -v -e "Listing..." | sed 's/\// /' | awk '{print "echo \'" $1 "\' >> /dev/kmsg && apt download " $1 "=" $3}' > /home/pi/.webthings/deb_packages/candle_packages_downloader.sh



if [ -f /home/pi/create_latest_candle_dev.sh ]; then
    echo "removing old create_latest_candle_dev.sh script"
    rm /home/pi/create_latest_candle_dev.sh
fi

if [ -f /home/pi/recovery.img ]; then
    echo "removing old recovery.img file"
    rm /home/pi/recovery.img
fi

if [ -f /home/pi/prepare_for_disk_image.sh ]; then
    echo "removing old prepare for disk image script"
    rm /home/pi/prepare_for_disk_image.sh
fi


if [ -d /opt/vc/lib ]; then
    echo "removing left over /opt/vc/lib"
    rm -rf /opt/vc/lib
fi


echo "removing swap"

dphys-swapfile swapoff
dphys-swapfile uninstall
update-rc.d dphys-swapfile remove
if [ -f /home/pi/.webthings/swap ]; then
    # TODO: don't remove this if the syetem is low on memory (which is why it's there in the first place)
    swapoff /home/pi/.webthings/swap
    rm /home/pi/.webthings/swap
fi
if [ -f /var/swap ]; then
    echo "Candle: removing swap" >> /dev/kmsg
    echo "Candle: removing swap" >> $BOOT_DIR/candle_log.txt
    swapoff /var/swap
    rm /var/swap
fi


echo "Clearing tmp"
rm -rf /tmp/*

if [ -f /home/pi/.wget-hsts ]; then
    rm /home/pi/.wget-hsts
fi

# TODO: is deleting this a good idea? Won't chromium just recreate it, this time without any modifications?
if [ -d /home/pi/.config/chromium ]; then
    rm -rf /home/pi/.config/chromium
fi

if [ -f /home/pi/.config/configstore/update-notifier-npm.jso ]; then
    echo '{"optOut": true,"lastUpdateCheck": 0}' > /home/pi/.config/configstore/update-notifier-npm.json 
    chown pi:pi /home/pi/.config/configstore/update-notifier-npm.json 
fi

# Remove files left over by Windows or MacOS
rm -rf $BOOT_DIR/.Spotlight*

if [ -f $BOOT_DIR/._cmdline.txt ]; then
    rm $BOOT_DIR/._cmdline.txt
fi




# Set Candle as the hostname
if [ ! -e /home/pi/.webthings/etc/hostname ]
then
    echo "candle" > /etc/hostname
    echo "candle" > /home/pi/.webthings/etc/hostname
    echo "Candle: creating /home/pi/.webthings/etc/hostname" >> /dev/kmsg
    echo "Candle: creating /home/pi/.webthings/etc/hostname" >> $BOOT_DIR/candle_log.txt
else
    echo "/home/pi/.webthings/etc/hostname already existed"
    echo "Candle: /home/pi/.webthings/etc/hostname already existed" >> /dev/kmsg
    echo "Candle: /home/pi/.webthings/etc/hostname already existed" >> $BOOT_DIR/candle_log.txt
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
if cat $BOOT_DIR/cmdline.txt | grep -q PARTUUID; then
    echo "replacing PARTUUID= in bootcmd.txt with /dev/mmcblk0p2"
    sed -i ' 1 s|root=PARTUUID=.* |root=/dev/mmcblk0p2 |g' $BOOT_DIR/cmdline.txt # should that g be there?
    #sed -i ' 1 s/.*/& quiet plymouth.ignore-serial-consoles splash logo.nologo vt.global_cursor_default=0/' $BOOT_DIR/cmdline.txt   
fi

# Copying the fstab file is the last thing to do since it could render the system inaccessible if the mountpoints it needs are not available
if [ -n "$(lsblk | grep mmcblk0p3)" ] || [ -n "$(lsblk | grep mmcblk0p4)" ]; then

    if [ -f $BOOT_DIR/fstab3.bak ] \
    && [ -f $BOOT_DIR/fstab4.bak ]; then
        echo "$BOOT_DIR/fstab3.bak and $BOOT_DIR/fstab4.bak exist"
    else
        echo "ERROR, $BOOT_DIR/fstab3.bak and $BOOT_DIR/fstab4.bak do not exist"
        echo "WARNING, $BOOT_DIR/fstab3.bak and $BOOT_DIR/fstab4.bak do not exist" >> /dev/kmsg
        echo "ERROR, $BOOT_DIR/fstab3.bak and $BOOT_DIR/fstab4.bak do not exist" >> $BOOT_DIR/candle_log.txt
    fi

    if [ -d /home/pi/.webthings/etc/wpa_supplicant ] \
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

        if lsblk | grep -q mmcblk0p4; 
        then
            echo "copying 4 partition version of fstab"
            echo "Candle: copying 4 partition version of fstab" >> /dev/kmsg
            echo "Candle: copying 4 partition version of fstab" >> $BOOT_DIR/candle_log.txt
        
            if ! diff -q /home/pi/configuration-files/boot/firmware/fstab4.bak /etc/fstab &>/dev/null; then
                echo "fstab file is different, copying it"
                cp --verbose /home/pi/configuration-files/boot/firmware/fstab4.bak /etc/fstab
            else
                echo "new fstab file is same as the old one, not copying it."
            fi
        
        else
            echo "copying 3 partition version of fstab"
            echo "Candle: copying 3 partition version of fstab" >> /dev/kmsg
            echo "Candle: copying 3 partition version of fstab" >> $BOOT_DIR/candle_log.txt
        
            if ! diff -q /home/pi/configuration-files/boot/firmware/fstab3.bak /etc/fstab &>/dev/null; then
                echo "3 partition fstab file is different, copying it"
                echo "Candle: 3 partition fstab file is different, copying it" >> /dev/kmsg
                cp --verbose /home/pi/configuration-files/boot/firmware/fstab3.bak /etc/fstab
            else
                echo "new fstab file is same as the old one, not copying it."
                echo "Candle: new fstab file is same as the old one, not copying it." >> /dev/kmsg
                echo "new 3 partition fstab file is same as the old one, not copying it." >> $BOOT_DIR/candle_log.txt
            fi
        fi

    
    else
        echo
        echo "ERROR, SOME VITAL FSTAB MOUNTPOINTS DO NOT EXIST!"
        # The only reason this is a warning and not an error (which would stop the process in de UI), is that the process is nearly done anyway.
        echo "Candle: WARNING, SOME VITAL MOUNTPOINTS DO NOT EXIST, NOT CHANGING FSTAB" >> /dev/kmsg
        echo "Candle: ERROR, SOME VITAL MOUNTPOINTS DO NOT EXIST, NOT CHANGING FSTAB" >> $BOOT_DIR/candle_log.txt
        echo ""
    
        ls /home/pi/.webthings/etc/wpa_supplicant
        ls /home/pi/.webthings/var/lib/bluetooth
        ls /home/pi/.webthings/etc/ssh
        ls /home/pi/.webthings/etc/hostname
        ls /home/pi/.webthings/tmp
        ls /home/pi/.webthings/arduino/.arduino15
        ls /home/pi/.webthings/arduino/Arduino
    
        echo ""
    
    fi
else
    echo "ERROR, no 3rd or 4th partition"
fi


echo "Clearing /home/pi/configuration-files"
rm -rf /home/pi/configuration-files





# if this is not a cutting edge build, then use the cmdline.txt and config.txt from the configuration files
if [ ! -f $BOOT_DIR/candle_cutting_edge.txt ]; then # || [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
    
    # Copy the Candle cmdline over the old one. This one is disk UUID agnostic.
    if [ -f $BOOT_DIR/cmdline-candle.txt ]; then
        rm $BOOT_DIR/cmdline.txt
        cp $BOOT_DIR/cmdline-candle.txt $BOOT_DIR/cmdline.txt
    fi

    # Copy the Candle config.txt over the old one.
    if [ -f $BOOT_DIR/config.txt.bak ]; then
        rm $BOOT_DIR/config.txt
        cp $BOOT_DIR/config.txt.bak $BOOT_DIR/config.txt
    fi
fi


#echo "setting internet time to true"
#timedatectl set-ntp true
#sleep 2
#fake-hwclock save








# OTHER

# Create fix for missing audio firmware
if [ ! -e /usr/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.bin ]; then
  ln -s /usr/lib/firmware/brcm/brcmfmac43455-sdio.bin /usr/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.bin  
  echo
  echo "Candle: added symlink for missing audio firmware"
  echo
fi













#
#  AT THIS POINT THE SYSTEM UPDATE IS MOSTLY DONE
#  PART 2: INSTALL UPDATED CANDLE CONTROLLER SOFTWARE
#



    
    

if [[ -z "${SKIP_CONTROLLER}" ]] || [ "$SKIP_CONTROLLER" = no ]
then
    echo
    
    if [ -f install_candle_controller.sh ]; then
        chmod +x ./install_candle_controller.sh
        sudo -u pi ./install_candle_controller.sh
        wait
        rm ./install_candle_controller.sh

        cd $CANDLE_BASE

        # This should work now, but setcap has been move to install_candle_controller script instead
        #NODE_PATH=$(sudo -i -u pi which node)
        #setcap cap_net_raw+eip $(eval readlink -f "$NODE_PATH")
    
        # Check if the installation of the controller succeeded
    
        if [ -d /ro ]; then
            if [ ! -f /ro/home/pi/webthings/gateway/.post_upgrade_complete ] || [ ! -f /ro/home/pi/node12 ]; then
                echo 
                echo "ERROR, detected failure to install candle-controller"
                echo "Candle: ERROR, failed to install candle-controller" >> /dev/kmsg
                echo "$(date) - ERROR, failed to install candle-controller" >> /home/pi/.webthings/candle.log
                echo "$(date) - ERROR, failed to install candle-controller" >> $BOOT_DIR/candle_log.txt
                echo 
		
                # Show error image
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                    /bin/ply-image $BOOT_DIR/error.png
                    #sleep 7200
                fi

                exit 1
            fi
            
        elif [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ] || [ ! -e /home/pi/node12 ]
	then
    
            echo 
            echo "ERROR, detected failure to install candle-controller"
            echo "Candle: ERROR, failed to install candle-controller" >> /dev/kmsg
            echo "Candle: ERROR, failed to install candle-controller" >> /home/pi/.webthings/candle.log
            echo "Candle: ERROR, failed to install candle-controller" >> $BOOT_DIR/candle_log.txt
            echo

            # Show error image
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                /bin/ply-image $BOOT_DIR/error.png
            fi

            exit 1
        fi
    
    else
        echo "Error, install_candle_controller.sh was missing. Should not be possible."
	echo "Error, install_candle_controller.sh was missing." >> $BOOT_DIR/candle_log.txt
    fi
    
    
    cd $CANDLE_BASE

    if [ -f /home/pi/controller_backup.tar ]; then
        chown pi:pi /home/pi/controller_backup.tar
    fi
    
fi


if [ -e /home/pi/webthings/gateway/static/images/floorplan.svg ];
then
    cp /home/pi/webthings/gateway/static/images/floorplan.svg /home/pi/.webthings/floorplan.svg
    chown pi:pi /home/pi/.webthings/floorplan.svg
    mkdir -p /home/pi/.webthings/uploads
    cp /home/pi/webthings/gateway/static/images/floorplan.svg /home/pi/.webthings/uploads/floorplan.svg
else
    echo 
    echo "WARNING: missing floorplan"
    echo "Error, missing floorplan." >> $BOOT_DIR/candle_log.txt
    echo 
fi


# Make sure permissions of newly pre-installed addons are ok

cd $CANDLE_BASE/.webthings
chown -R pi:pi addons
chmod -R 755 addons
chown -R pi:pi data
chmod -R 755 data
chown -R pi:pi uploads
chmod -R 755 uploads
chown -R pi:pi chromium
chmod -R 755 chromium
chown -R pi:pi arduino
chmod -R 755 arduino
cd $CANDLE_BASE/

#
#  ADDITIONAL CLEANUP
#
#if [ -f /home/pi/create_latest_candle.sh ]; then
#    echo "Removing left-over /home/pi/create_latest_candle.sh" >> /dev/kmsg
#    rm /home/pi/create_latest_candle.sh
#fi

if [ -f /home/pi/ro-root.sh ]; then
    rm /home/pi/ro-root.sh
fi


# Some final insurance
chown pi:pi /home/pi/*
chown -R pi:pi /home/pi/candle/*

rm -rf python311


#
#  DONE
#


if [ -f $BOOT_DIR/cmdline-candle.txt ]; then
    if [ -n "$(lsblk | grep mmcblk0p3)" ] || [ -n "$(lsblk | grep mmcblk0p4)" ]; then
        echo "copying default Candle cmdline.txt into place"
        rm $BOOT_DIR/cmdline.txt
        cp $BOOT_DIR/cmdline-candle.txt $BOOT_DIR/cmdline.txt
    fi
fi


# Fix hostname issue from RC2
if [ -f /home/pi/.webthings/etc/hostname ] && [ -f /home/pi/.webthings/etc/hosts ]; then
    hostname="$(cat /home/pi/.webthings/etc/hostname)"
    if ! cat /etc/hosts | grep -q "$hostname"; then
        echo "hostname was not in /etc/hosts. Attempting to fix."
        echo "before:"
        cat /home/pi/.webthings/etc/hosts
        echo ""
        sed -i -E -e "s|127\.0\.1\.1[ \t]+.*|127\.0\.1\.1 \t$hostname|" /home/pi/.webthings/etc/hosts
        echo "after:"
        cat /home/pi/.webthings/etc/hosts
        echo ""
    fi
else
    echo
    echo "Error, /home/pi/.webthings/etc/hostname and/or /home/pi/.webthings/etc/hosts did not exist"
    echo "Candle: ERROR, /home/pi/.webthings/etc/hostname and/or /home/pi/.webthings/etc/hosts did not exist" >> /dev/kmsg
    echo "ERROR, /home/pi/.webthings/etc/hostname and/or /home/pi/.webthings/etc/hosts did not exist" >> $BOOT_DIR/candle_log.txt
    exit 1
fi



if [ -d /home/pi/webthings/gateway ] && [ -d /home/pi/webthings/gateway2 ]; then
    rm -rf /home/pi/webthings/gateway2
fi


# cp /home/pi/.webthings/etc/webthings_settings_backup.js /home/pi/.webthings/etc/webthings_settings.js

if [ -f $BOOT_DIR/candle_first_run_complete.txt ] && [ ! -f $BOOT_DIR/candle_original_version.txt ]; then
    echo "2.0.3" > $BOOT_DIR/candle_original_version.txt
fi

# remember when the disk image was created
if [ ! -f /home/pi/candle/creation_date.txt ]; then
    echo "$(date +%s)" > /home/pi/candle/creation_date.txt
fi

# remember when the update script was last run
#echo "$(date +%s)" > /home/pi/candle/update_date.txt

# Disable old bootup actions service
systemctl disable candle_bootup_actions.service

# delete bootup_actions, just in case this script is being run as a bootup_actions script.
if [ -f $BOOT_DIR/bootup_actions.sh ]; then
    rm $BOOT_DIR/bootup_actions.sh
    echo "removed $BOOT_DIR/bootup_actions.sh"
fi
if [ -f $BOOT_DIR/bootup_actions_failed.sh ]; then
    rm $BOOT_DIR/bootup_actions_failed.sh
    echo "removed $BOOT_DIR/bootup_actions_failed.sh"
fi

if [ -f $BOOT_DIR/post_bootup_actions.sh ]; then
    rm $BOOT_DIR/post_bootup_actions.sh
    echo "removed $BOOT_DIR/post_bootup_actions.sh"
fi
if [ -f $BOOT_DIR/post_bootup_actions_failed.sh ]; then
    rm $BOOT_DIR/post_bootup_actions_failed.sh
    echo "removed $BOOT_DIR/post_bootup_actions_failed.sh"
fi

# Remove cutting edge
if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    echo "disabling cutting edge" >> /dev/kmsg
    echo "disabling cutting edge" >> $BOOT_DIR/candle_log.txt
    rm $BOOT_DIR/candle_cutting_edge.txt
fi

if [ -d /home/pi/configuration-files ]; then
    echo "removing configuration-files dir"
    rm -rf /home/pi/configuration-files
fi

# DONE!
echo "$(date) - system update complete" >> /home/pi/.webthings/candle.log
echo "$(date) - system update complete" >> $BOOT_DIR/candle_log.txt







# RUN DEBUG SCRIPT

if [ "$SKIP_DEBUG" = no ] || [[ -z "${SKIP_DEBUG}" ]]; 
then
    echo
    echo
    echo 
    echo "ALMOST DONE, RUNNING DEBUG SCRIPT"
    echo

    if [ -f $BOOT_DIR/candle_first_run_complete.txt ]; then
        /home/pi/candle/debug.sh > $BOOT_DIR/debug.txt

        echo "" >> $BOOT_DIR/debug.txt
        echo "THIS OUTPUT WAS CREATED BY THE SYSTEM UPDATE PROCESS" >> $BOOT_DIR/debug.txt
        cat $BOOT_DIR/debug.txt
        echo "Candle: DONE. Debug output placed in $BOOT_DIR/debug.txt" >> /dev/kmsg
    else
        /home/pi/candle/debug.sh
    fi

    echo
    echo
   
fi

echo


if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
    
    if [[ -n "${CREATE_DISK_IMAGE}" ]] || [ "$CREATE_DISK_IMAGE" = yes ]; 
    then
        echo "CREATING DISK IMAGE"
        echo "Candle: calling prepare_for_disk_image.sh" >> /dev/kmsg
        chmod +x /home/pi/candle/prepare_for_disk_image.sh 
        /home/pi/candle/prepare_for_disk_image.sh 
        exit 0
  
    else
        echo "NOT RUNNING PREPARE_FOR_DISK_IMAGE SCRIPT. Stopping early."
    
        # To be safe, start SSH on the first run
        #touch $BOOT_DIR/ssh.txt
    
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
        

            cd $CANDLE_BASE/.webthings/deb_packages
            chmod +x ./candle_packages_downloader.sh
            sudo -u pi ./candle_packages_downloader.sh
        
            # fix the filenames. Replaces "%3a" with ":".
            # for f in *; do mv "$f" "${f//%3a/:}"; done
  
            echo
            echo "Downloaded packages in /home/pi/.webthings/deb_packages:"
            ls -l
            du /home/pi/.webthings/deb_packages -h
        
        fi
    
        cd $CANDLE_BASE/
  
        # On the next boot allow the system partition to be writeable
        # touch $BOOT_DIR/candle_rw_once.txt
    
        #MY_SCRIPT_VARIABLE="${CANDLE_DEV}"
        echo
        echo "MOSTLY DONE"
        echo
        echo "To finalise enter this command:"
        echo "sudo /home/pi/prepare_for_disk_image.sh"
        echo
        echo "Once that script is done the pi will shut down and can be imaged."
        echo
        echo "Note that if you reboot, the read-only mode will become active."
        echo "If you want to delay this once, then use this command:"
        echo "touch $BOOT_DIR/candle_rw_once.txt"
        echo "...or if you want skip read-only mode permanently:"
        echo "touch $BOOT_DIR/candle_rw_keep.txt"
        echo ""
    
    fi

fi


# If developer mode is active during a system update, then the system will permanently have SSH enabled
if [ ! -f $BOOT_DIR/developer.txt ]; then
    # Disable SSH access
    #systemctl disable ssh.service
    raspi-config nonint do_ssh 1 # 0 is enable, 1 is disable
fi


# Here it's possible to also ask the script to not reboot.
if [[ -n "${SKIP_REBOOT}" ]] || [ "$SKIP_REBOOT" = yes ]; then
    echo "Candle: Not rebooting" >> /dev/kmsg
    echo "DONE"
else
    echo
    echo "Candle: Rebooting in 10 seconds" >> /dev/kmsg
    echo
    sleep 10
    if [ -f $BOOT_DIR/candle_rw_once.txt ]; then
        rm $BOOT_DIR/candle_rw_once.txt
    fi
    reboot
fi

exit 0
