#!/bin/bash
set +e

#part of the Candle disk image creation script

# This script should be run as user pi (not root)
if ! [ "$EUID" -ne 0 ];
then
  echo "Please run as user pi (do not use sudo)"
  exit 1
fi

if [ ! -s /etc/resolv.conf ]; then
    # no nameserver
    echo "no nameserver, aborting"
    echo "Candle: No nameserver, aborting" | sudo tee -a /dev/kmsg
    exit 1
fi

# Add /home/pi/.local/bin to path
if [ -z "$(printenv PATH | grep /home/pi/.local/bin)" ]; then 
    export PATH="/home/pi/.local/bin:$PATH"
    echo "added /home/pi/.local/bin to PATH"
fi


echo "DATE         : $(date)"
echo "IP ADDRESS   : $(hostname -I)"
echo "USER         : $(whoami)"
echo "PATH         : $PATH"
scriptname=$(basename "$0")
echo "NAME         : $scriptname"

if [ -f /boot/candle_cutting_edge.txt ]; then
echo "Cutting edge : yes"
else
echo "Cutting edge : no"
fi

echo
echo

cd /home/pi || exit

echo "candle: installing python gateway addon" | sudo tee -a /dev/kmsg
echo "candle: installing python gateway addon" | sudo tee -a /boot/candle_log.txt
python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon

if [ ! command -v npm &> /dev/null ] || [ "$(cat /home/pi/.webthings/.node_version)" != 12 ];
then
    echo
    echo "NPM could not be found. Installing it now."
    echo "Candle: Installing NVM" | sudo tee -a /dev/kmsg
    echo "Candle: Installing NVM" | sudo tee -a /boot/candle_log.txt
    
    
    if [ -f ./install_nvm.sh ]; then
        rm ./install_nvm.sh
        echo "spotted NVM installation left-over: install_nvm.sh"
    fi
    #if [ -d ./.nvm ]; then
    #    rm -rf ./.nvm
    #    echo "spotted NVM installation left-over: .nvm dir"
    #fi
    #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
    wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh -O install_nvm.sh
    if [ ! -f install_nvm.sh ]; then
        echo "ERROR, install_nvm.sh failed to download"
        echo "ERROR, install_nvm.sh failed to download" | sudo tee -a /dev/kmsg
        echo "ERROR, install_nvm.sh failed to download" | sudo tee -a /boot/candle_log.txt
        
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
            sudo /bin/ply-image /boot/error.png
            sleep 7200
        fi
        
        exit 1
    fi
    
    chmod +x install_nvm.sh
    ./install_nvm.sh

    #. ~/.bashrc
    
    
    export NVM_DIR="/home/pi/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    
    if [ -z "$(nvm --version)" ]; then
        echo "ERROR, nvm is not available. Installation failed?"
        echo "ERROR, nvm is not available. Installation failed?" | sudo tee -a /dev/kmsg
        echo "ERROR, nvm is not available. Installation failed?" | sudo tee -a /boot/candle_log.txt
        
        if [ ! -f /boot/candle_first_run_complete.txt ]; then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
                sudo /bin/ply-image /boot/error.png
                sleep 7200
            fi
        
            exit 1
        fi
    else
        echo "NVM is available now"
    fi
    

    if cat /home/pi/.profile | grep NVM
    then
        echo "NVM lines already appended to .profile"
        echo "NVM lines already appended to .profile" | sudo tee -a /dev/kmsg
        echo "NVM lines already appended to .profile" | sudo tee -a /boot/candle_log.txt
    else
        echo "Appending NVM lines to .profile"
        echo >> /home/pi/.profile
        echo 'export NVM_DIR="/home/pi/.nvm"' >> /home/pi/.profile
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/pi/.profile
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/pi/.profile
    fi

    
    
    echo "starting nvm install"
    nvm install 12
    nvm use 12
    nvm alias default 12
else
    echo "NPM seems to already be installed." | sudo tee -a /dev/kmsg
    echo "NPM seems to already be installed." | sudo tee -a /boot/candle_log.txt
fi


if [ -d /home/pi/.nvm ]; then
    export NVM_DIR="/home/pi/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi


if [ -f ./install_nvm.sh ]; then
    echo "removing install_nvm.sh"
    rm ./install_nvm.sh
fi


echo
echo "NODE AND NPM VERSIONS:"
node --version
npm --version
echo "Candle: Node --version: $(node --version)" | sudo tee -a /dev/kmsg
echo "Candle: NPM --version: $(npm --version)"   | sudo tee -a /dev/kmsg
echo "Candle: Node --version: $(node --version)" | sudo tee -a /boot/candle_log.txt
echo "Candle: NPM --version: $(npm --version)"   | sudo tee -a /boot/candle_log.txt

npm cache verify


npm config set metrics-registry="https://"
#npm config set registry="https://"
#npm config set user-agent=""
if [ -f /home/pi/.npm/anonymous-cli-metrics.json ]
then
  rm /home/pi/.npm/anonymous-cli-metrics.json
fi


_node_version=$(node --version | grep -E -o '[0-9]+' | head -n1)
echo "Node version: ${_node_version}" | sudo tee -a /dev/kmsg
echo "Node version: ${_node_version}" | sudo tee -a /boot/candle_log.txt

echo "${_node_version}" > "/home/pi/.webthings/.node_version"
echo "Node version in .node_version file:"
cat /home/pi/.webthings/.node_version


sudo setcap cap_net_raw+eip $(eval readlink -f `which node`)
sudo setcap cap_net_raw+eip $(eval readlink -f `which python3`)


# Download Candle controller from Github and install it

echo
echo "INSTALLING CANDLE CONTROLLER"

echo



# Create a backup first

availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
if [ -f /home/pi/latest_stable_controller.tar ]; then
    if [ "$availMem" -gt "200000" ]; 
    then
        if [ -f /home/pi/webthings/gateway/build/app.js ] \
        && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
        && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
        && [ -d /home/pi/webthings/gateway/node_modules ] \
        && [ -d /home/pi/webthings/gateway/build/static/bundle ];
        then
            echo "Detected old webthings directory! Creating fresh backup"
            echo "Candle: Detected old webthings directory. Creating fresh backup" | sudo tee -a /dev/kmsg
            echo "Candle: Detected old webthings directory. Creating fresh backup" | sudo tee -a /boot/candle_log.txt
            #mv /home/pi/webthings /home/pi/webthings-old
            tar -czf ./controller_backup_fresh.tar ./webthings
        fi
    fi
fi


#rm -rf /home/pi/webthings

if [ -d ./candle-controller ]; then
    echo "spotted candle-controller directory. Must be left over from interupted install"
    rm -rf candle-controller
fi


#!/bin/bash

# DOWNLOAD CANDLE CONTROLLER FROM GITHUB

if [ -f /boot/candle_cutting_edge.txt ]; then
    
    echo "Candle: Starting controller source code download" | sudo tee -a /dev/kmsg
    echo "Candle: Starting controller source code download" | sudo tee -a /boot/candle_log.txt
    mkdir -p /home/pi/webthings
    chown pi:pi /home/pi/webthings
    cd /home/pi/webthings
    
    git clone --depth 1 https://github.com/createcandle/candle-controller.git
    if [ -d ./candle-controller ]; then
        echo "Cutting edge controller download succeeded" | sudo tee -a /dev/kmsg
        echo "Cutting edge controller download succeeded" | sudo tee -a /boot/candle_log.txt
        rm -rf /home/pi/webthings/gateway2
        mv -f ./candle-controller /home/pi/webthings/gateway2
    else
        echo "ERROR, downloading cutting edge candle-controller dir from Github failed" | sudo tee -a /dev/kmsg
        echo "ERROR, downloading cutting edge candle-controller dir from Github failed" | sudo tee -a /boot/candle_log.txt
        
        if [ ! -f /boot/candle_first_run_complete.txt ]; then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
                sudo /binif [ ! -f /boot/candle_first_run_complete.txt ]; then/ply-image /boot/error.png
                sleep 7200
            fi
        
            exit 1
        fi
    fi
    
    
# Stable controller. Now simply downloads the entire folder and puts it into place.
else

    if [ -f /home/pi/latest_stable_controller.tar ]; then
        
        echo "Will extract latest_stable_controller.tar"
        
        cd /home/pi
        
        if [ -d /home/pi/webthings/gateway2 ]; then
            rm -rf /home/pi/webthings/gateway2
        fi

        availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
        if [ "$availMem" -gt "1000000" ]; 
        then
            echo "Candle: Doing safe unpack of latest_stable_controller.tar"
            echo "Candle: Doing safe unpack of latest_stable_controller.tar" | sudo tee -a /dev/kmsg
            echo "Doing safe unpack of latest_stable_controller.tar" | sudo tee -a /boot/candle_log.txt
            mkdir -p /home/pi/downloaded_controller
            rm -rf /home/pi/downloaded_controller/*
            echo "extracting"
            tar -xf latest_stable_controller.tar -C /home/pi/downloaded_controller
            
            ls /home/pi/downloaded_controller
            
            if [ -f /home/pi/downloaded_controller/webthings/gateway/.post_upgrade_complete ]; then
                echo "extraction worked fine"
                if [ -d /home/pi/webthings/gateway ]; then
                    rm -rf /home/pi/webthings/gateway
                fi
                echo "moving extracted gateway dir into place"
                mv /home/pi/downloaded_controller/webthings/gateway /home/pi/webthings/gateway
            else
                echo "extraction did not go as planned"    
            fi
            
            echo "removing extracted files"
            rm -rf /home/pi/downloaded_controller
            
        else
            # more risky move because of low disk space
            echo "Candle: Low disk space, doing direct unpack of latest_stable_controller.tar" | sudo tee -a /dev/kmsg
            echo "Low disk space, doing direct unpack of latest_stable_controller.tar" | sudo tee -a /boot/candle_log.txt
            
            if [ -d /home/pi/webthings ]; then
                sudo rm -rf /home/pi/webthings
            fi
            tar -xf latest_stable_controller.tar
        fi
        
    else
        
        echo "Stable, but latest_stable_controller.tar missing. Attempting build." | sudo tee -a /dev/kmsg
        echo "Stable, but latest_stable_controller.tar missing. Attempting build." | sudo tee -a /boot/candle_log.txt
        
        mkdir -p /home/pi/webthings
        chown pi:pi /home/pi/webthings
        cd /home/pi/webthings
        
        curl -s https://api.github.com/repos/createcandle/candle-controller/releases/latest \
        | grep "tarball_url" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O candle-controller-git.tar

        if [ -f candle-controller-git.tar ]; then
            echo "Stable Github Candle Controller release download succeeded" | sudo tee -a /dev/kmsg
            echo "Stable Github Candle Controller release download succeeded" | sudo tee -a /boot/candle_log.txt
            tar -xf candle-controller-git.tar
            rm candle-controller-git.tar
    
            
            for directory in createcandle-candle-controller*; do
              [[ -d $directory ]] || continue
              echo "Directory: $directory"
              rm -rf ./gateway2
              mv -f "$directory" ./gateway2
            done
    
            #mv ./install-scripts/install_candle_controller.sh ./install_candle_controller.sh
            echo
            echo "PWD: $(pwd)"
            echo "ls /home/pi/webthings/gateway2:"
            ls /home/pi/webthings/gateway2
        else
            echo "ERROR, downloading latest stable release of candle-controller source dir from Github failed" | sudo tee -a /dev/kmsg
            echo "ERROR, downloading latest stable release of candle-controller source dir from Github failed" | sudo tee -a /boot/candle_log.txt
        
            if [ ! -f /boot/candle_first_run_complete.txt ]; then
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
                    sudo /bin/ply-image /boot/error.png
                    sleep 7200
                fi
        
                exit 1
            fi
            
        fi
    fi

fi


if [ -f /boot/candle_cutting_edge.txt ] && [ ! -d /home/pi/webthings/gateway2 ]; then
    echo
    echo "ERROR, missing gateway2 directory"
    echo "Candle: ERROR, missing gateway2 directory" | sudo tee -a /dev/kmsg
    echo "Candle: ERROR, missing gateway2 directory" | sudo tee -a /boot/candle_log.txt
    echo
    
    
    if [ ! -f /boot/candle_first_run_complete.txt ]; then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
            sudo /bin/ply-image /boot/error.png
            sleep 7200
        fi

        exit 1
    fi
fi


if [ -d /home/pi/webthings/gateway2 ]; then
    echo "/home/pi/webthings/gateway2 exists"
    
    cd /home/pi/webthings/gateway2

    rm -rf node_modules/

    export CPPFLAGS="-DPNG_ARM_NEON_OPT=0"
    # CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install imagemin-optipng --save-dev
    # npm install typescript --save-dev # TODO: check if this is now in package.json already

    # npm install
    echo "Candle: Installing Node modules (takes a while)" | sudo tee -a /dev/kmsg
    echo "Candle: Installing Node modules (takes a while)" | sudo tee -a /boot/candle_log.txt
    
    echo "Do not worry about the errors you will see with optipng and jpegtran"
    
    CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm ci

    #echo "Does node_modules exist now?: $(ls /home/pi/webthings/gateway)" | sudo tee -a /dev/kmsg




    echo
    #echo "COMPILING TYPESCRIPT AND RUNNING WEBPACK"
    #echo "Compiling Typescript and running Webpack" | sudo tee -a /dev/kmsg

    #npm run build

    #npm install -D webpack-cli

    rm -rf build
    cp -rL src build
    cp -rL static build/static
    find build -name '*.ts' -delete
    echo
    echo "Compiling typescript. this will take a while..."
    echo "Candle: Compiling typescript. This will take a while..." | sudo tee -a /dev/kmsg
    echo "Candle: Compiling typescript. This will take a while..." | sudo tee -a /boot/candle_log.txt
    npx tsc -p .
    echo "(it probably found some errors, don't worry about those)"
    echo
    #echo "Running webpack. this will take a while too..."
    echo "Candle: Running webpack. This will take a while too..." | sudo tee -a /dev/kmsg
    echo "Candle: Running webpack. This will take a while too..." | sudo tee -a /boot/candle_log.txt
    
    totalk="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
    echo "memory size: $totalk"
    if [ "$totalk" -lt 600000 ]
    then
        echo "very low memory, --max-old-space-size=496"
        NODE_OPTIONS="--max-old-space-size=496" npx webpack
    elif [ "$totalk" -lt 1200000 ]
    then
        echo "low memory, --max-old-space-size=750"
        NODE_OPTIONS="--max-old-space-size=750" npx webpack
    elif [ "$totalk" -lt 2200000 ]
    then
        echo "normal memory, --max-old-space-size=1024"
        NODE_OPTIONS="--max-old-space-size=1024" npx webpack
    else
        echo "big memory, --max-old-space-size=2048"
        NODE_OPTIONS="--max-old-space-size=2048" npx webpack
    fi
    
    if [ -f /home/pi/webthings/gateway2/build/app.js ] \
    && [ -f /home/pi/webthings/gateway2/build/static/index.html ] \
    && [ -d /home/pi/webthings/gateway2/node_modules ] \
    && [ -d /home/pi/webthings/gateway2/build/static/bundle ];
    then
      touch .post_upgrade_complete
      echo "$(date +%s)" > update_date.txt
      #echo "Controller installation seems ok"
      
      echo "Controller installation seems ok, at $(pwd)" | sudo tee -a /dev/kmsg
    else
      echo  
      echo "ERROR, controller installation is missing parts"
      echo "Candle: ERROR, controller installation is mising parts" | sudo tee -a /dev/kmsg
      echo "$(date) - ERROR, controller installation is mising parts" | sudo tee -a /boot/candle_log.txt
      echo
    fi


    echo "New controller was created at $(pwd)"
    # Move the freshly created gateway into position
    cd /home/pi
    if [ -d /home/pi/webthings/gateway2 ]; then
    
        echo "Starting move/copy of /home/pi/webthings/gateway2 to /home/pi/webthings/gateway"
        #rm-rf /home/pi/webthings/gateway
        if [ ! -d /home/pi/webthings/gateway ]; then
            echo "Candle: Gateway didn't exist, moving gateway2 into position" | sudo tee -a /dev/kmsg
            echo "Candle: Gateway didn't exist, moving gateway2 into position" | sudo tee -a /boot/candle_log.txt
            mv /home/pi/webthings/gateway2 /home/pi/webthings/gateway
        else
            echo "Candle: Gateway dir existed, doing rsync from gateway2" | sudo tee -a /dev/kmsg
            echo "Candle: Gateway dir existed, doing rsync from gateway2" | sudo tee -a /boot/candle_log.txt
            rsync -r -q --delete /home/pi/webthings/gateway2/* /home/pi/webthings/gateway
            chown -R pi:pi /home/pi/webthings/gateway
            rm -rf /home/pi/webthings/gateway2
        fi
    else
        # This should never happen
        echo "ERROR, gateway2 was just created.. but is missing?" | sudo tee -a /dev/kmsg
        echo "ERROR, gateway2 was just created.. but is missing?" | sudo tee -a /boot/candle_log.txt
    fi
    
fi




echo
echo
echo "Candle: Linking gateway addon" | sudo tee -a /dev/kmsg
echo "Candle: Linking gateway addon" | sudo tee -a /boot/candle_log.txt
if [ -d /home/pi/webthings/gateway/node_modules/gateway-addon ];
then
    cd "/home/pi/webthings/gateway/node_modules/gateway-addon"
    npm link
    cd /home/pi
else
    echo "ERROR, /home/pi/webthings/gateway/node_modules/gateway-addon was missing"
    echo "Candle: ERROR, /home/pi/webthings/gateway/node_modules/gateway-addon was missing" | sudo tee -a /dev/kmsg
    echo "Candle: ERROR, /home/pi/webthings/gateway/node_modules/gateway-addon was missing" | sudo tee -a /boot/candle_log.txt
fi




# TODO: maybe do another sanity check and restore a backup if need be?


if [ ! -f /home/pi/webthings/gateway/build/app.js ] \
|| [ ! -f /home/pi/webthings/gateway/build/static/index.html ] \
|| [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
|| [ ! -d /home/pi/webthings/gateway/node_modules ] \
|| [ ! -d /home/pi/webthings/gateway/build/static/bundle ]; 
then
    echo "Candle: WARNING, INSTALLATION OF CANDLE CONTROLLER FAILED! RESTORING BACKUP"   | sudo tee -a /dev/kmsg
    echo "$(date) - WARNING, INSTALLATION OF CANDLE CONTROLLER FAILED! RESTORING BACKUP" | sudo tee -a /boot/candle_log.txt
    
    # restore the backup in case something has gone very wrong
    if [ -f /home/pi/controller_backup.tar ];
    then
        cd /home/pi
        sudo rm -rf /home/pi/webthings
        tar -xf ./controller_backup.tar
    fi
    
    
else
    echo
    echo "Everything looks good"
    echo "Candle: a valid controller exists" | sudo tee -a /dev/kmsg
    echo "Candle: a valid controller exists" | sudo tee -a /boot/candle_log.txt
    echo
fi


cd /home/pi


echo
echo "INSTALLING CANDLE ADDONS"
echo

mkdir -p /home/pi/.webthings/addons
chown -R pi:pi /home/pi/.webthings/addons


if [ ! -f /home/pi/.webthings/config/db.sqlite3 ] || [ ! -d /home/pi/.webthings/addons/power-settings ];
then
    echo "installing power settings addon"
    cd /home/pi/.webthings/addons
    rm -rf package
    rm -rf power-settings
    wget https://github.com/createcandle/power-settings/releases/download/3.3.10/power-settings-3.3.10.tgz
    for f in power-settings*.tgz; do
        tar -xf "$f"
    done
    mv package power-settings
    chown -R pi:pi power-settings
    rm ./*.tgz
else
    echo "no need to (re-)install power-settings addon"
fi


# Once the Candle app store exists, this part is never run again.
# TODO: what if part of this failed?
if [ ! -d /home/pi/.webthings/addons/candleappstore ]; 
then
    echo "Candle: Installing addons" | sudo tee -a /dev/kmsg
    echo "Candle: Installing addons" | sudo tee -a /boot/candle_log.txt
        
    cd /home/pi/.webthings/addons
  
    rm -rf package
    rm -rf candle-theme
    wget https://github.com/createcandle/candle-theme/releases/download/2.5.0/candle-theme-2.5.0.tgz
    for f in candle-theme*.tgz; do
        tar -xf "$f"
    done
    mv package candle-theme
    chown -R pi:pi candle-theme
    rm ./*.tgz


    rm -rf package
    rm -rf tutorial
    wget https://github.com/createcandle/tutorial/releases/download/1.0.7/tutorial-1.0.7.tgz
    for f in tutorial*.tgz; do
        tar -xf "$f"
    done
    mv package tutorial
    chown -R pi:pi tutorial
    rm ./*.tgz


    rm -rf package
    rm -rf bluetoothpairing
    wget https://github.com/createcandle/bluetoothpairing/releases/download/0.5.8/bluetoothpairing-0.5.8.tgz
    for f in bluetoothpairing*.tgz; do
        tar -xf "$f"
    done
    mv package bluetoothpairing
    chown -R pi:pi bluetoothpairing
    rm ./*.tgz


    rm -rf package
    rm -rf photo-frame
    wget https://github.com/flatsiedatsie/photo-frame/releases/download/1.4.17/photo-frame-1.4.17.tgz
    for f in photo-frame*.tgz; do
        tar -xf "$f"
    done
    mv package photo-frame
    chown -R pi:pi photo-frame
    rm ./*.tgz


    rm -rf package
    rm -rf followers
    wget https://github.com/flatsiedatsie/followers-addon/releases/download/0.6.8/followers-0.6.8.tgz
    for f in followers*.tgz; do
        tar -xf "$f"
    done
    mv package followers
    chown -R pi:pi followers
    rm ./*.tgz


    rm -rf package
    rm -rf internet-radio
    wget https://github.com/flatsiedatsie/internet-radio/releases/download/2.2.2/internet-radio-2.2.2.tgz
    for f in internet-radio*.tgz; do
        tar -xf "$f"
    done
    mv package internet-radio
    chown -R pi:pi internet-radio
    rm ./*.tgz


    rm -rf package
    rm -rf zigbee2mqtt-adapter
    wget https://github.com/kabbi/zigbee2mqtt-adapter/releases/download/1.1.4/zigbee2mqtt-adapter-1.1.4.tgz
    #tar -xf zigbee2mqtt-adapter-1.1.3.tgz
    for f in zigbee2mqtt-adapter*.tgz; do
        tar -xf "$f"
    done
    mv package zigbee2mqtt-adapter
    chown -R pi:pi zigbee2mqtt-adapter
    rm ./*.tgz


    rm -rf package
    rm -rf privacy-manager
    wget https://github.com/createcandle/privacy-manager/releases/download/0.2.8/privacy-manager-0.2.8.tgz
    for f in privacy-manager*.tgz; do
        tar -xf "$f"
    done
    mv package privacy-manager
    chown -R pi:pi privacy-manager
    rm ./*.tgz


    rm -rf package
    rm -rf webinterface
    wget https://github.com/createcandle/webinterface/releases/download/0.2.3/webinterface-0.2.3.tgz
    for f in webinterface*.tgz; do
        tar -xf "$f"
    done
    mv package webinterface
    chown -R pi:pi webinterface
    rm ./*.tgz
    
    
    rm -rf package
    rm -rf candleappstore
    wget https://github.com/createcandle/candleappstore/releases/download/0.4.18/candleappstore-0.4.18-linux-arm-v3.9.tgz
    for f in candleappstore*.tgz; do
        tar -xf "$f"
    done
    mv package candleappstore
    chown -R pi:pi candleappstore
    rm ./*.tgz
    
fi

#cd /home/pi/webthings/gateway
#timeout 10 npm run run-only
echo "controller installation should be complete"
echo "ls /home/pi/.webthings:"
#ls /home/pi/.webthings

cd /home/pi



mkdir -p /home/pi/.webthings/config
chown -R pi:pi /home/pi/.webthings/config
if [ ! -f /home/pi/.webthings/config/db.sqlite3 ];
then
    echo "Candle: copying initial Candle database from power settings addon" | sudo tee -a /dev/kmsg
    echo "Candle: copying initial Candle database from power settings addon" | sudo tee -a /boot/candle_log.txt
    if [ -f /home/pi/.webthings/addons/power-settings/db.sqlite3 ]; then
        cp /home/pi/.webthings/addons/power-settings/db.sqlite3 /home/pi/.webthings/config/db.sqlite3
        chown pi:pi /home/pi/.webthings/config/db.sqlite3
    else
        echo
        echo "Candle: ERROR, /home/pi/.webthings/addons/power-settings/db.sqlite3 was missing" | sudo tee -a /dev/kmsg
        echo "Candle: ERROR, /home/pi/.webthings/addons/power-settings/db.sqlite3 was missing" | sudo tee -a /boot/candle_log.txt
    fi
else
    echo "warning, not copying default database since a database file already exists"
    echo "Candle: Database file already existed, not replacing it" | sudo tee -a /dev/kmsg
    echo "Candle: Database file already existed, not replacing it" | sudo tee -a /boot/candle_log.txt
fi



npm config set metrics-registry="https://"
#npm config set registry="https://"
npm config set user-agent=""
rm /home/pi/.npm/anonymous-cli-metrics.json

npm cache clean --force
nvm cache clear

echo
#echo "sub-script that installs the Candle controller is done. Returning to the main install script."
echo "Candle: Returning to the main install script." | sudo tee -a /dev/kmsg
echo "Candle: Returning to the main install script." | sudo tee -a /boot/candle_log.txt
echo
exit 0


