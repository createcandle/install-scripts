#!/bin/bash
set +e

# This script is part of the Candle disk image creation script, although it can be run stand-alone to only install the controller itself.

BIT_TYPE=$(getconf LONG_BIT)
ARCHSTRING="linux-arm64"
if [ '$BIT_TYPE -ne 64' ]; then
    ARCHSTRING="linux-arm"
fi

echo "Architecture: $ARCHSTRING"

echo ""

# This script should be run as user pi (not root)
if ! [ "$EUID" -ne 0 ];
then
  echo "Please do not run as root (do not use sudo)"
  exit 1
fi

if [ ! -s /etc/resolv.conf ]; then
    # no nameserver
    echo "no nameserver, aborting"
    echo "Candle: No nameserver, aborting" | sudo tee -a /dev/kmsg
    exit 1
fi


BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

# It should in theory be possible to install this in any directory, not just /home/pi (untested)
CANDLE_BASE='.'
if [ -d /home/pi ]; then
    CANDLE_BASE="/home/pi"
else
    CANDLE_BASE="$(pwd)"
fi


# Add /home/pi/.local/bin to path
if [ -z "$(printenv PATH | grep $CANDLE_BASE/.local/bin)" ]; then 
    export PATH="$CANDLE_BASE/.local/bin:$PATH"
    echo "added $CANDLE_BASE/.local/bin to PATH"
fi


echo "DATE         : $(date)"
echo "IP ADDRESS   : $(hostname -I)"
echo "BITS         : $BIT_TYPE"
echo "USER         : $(whoami)"
echo "PATH         : $PATH"
echo "CANDLE_BASE  : $CANDLE_BASE"
scriptname=$(basename "$0")
echo "NAME         : $scriptname"

if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
echo "Cutting edge : yes"
else
echo "Cutting edge : no"
fi

echo
echo

cd "$CANDLE_BASE" || exit




if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    CUTTING_EDGE=yes
fi

if [ "$CUTTING_EDGE" = no ] || [[ -z "${CUTTING_EDGE}" ]];
then
    echo "no environment indication to go cutting edge"
    
    if [ ! -f "$CANDLE_BASE/latest_stable_controller.tar.txt" ] && [ ! -f "$CANDLE_BASE/latest_stable_controller.tar" ]; then
    
        echo "Candle: Starting download of stable controller tar"
        echo "Candle: Starting download of stable controller tar. Takes a while." | sudo tee -a /dev/kmsg
        echo "Candle: Starting download of stable controller tar" | sudo tee -a $BOOT_DIR/candle_log.txt
        wget -nv https://www.candlesmarthome.com/img/controller/latest_stable_controller.tar -O "$CANDLE_BASE/latest_stable_controller.tar"
        wget -nv https://www.candlesmarthome.com/img/controller/latest_stable_controller.tar.txt -O "$CANDLE_BASE/latest_stable_controller.tar.txt"
    
        if [ -f "$CANDLE_BASE/latest_stable_controller.tar" ] && [ -f "$CANDLE_BASE/latest_stable_controller.tar.tx"t ]; then
        
            echo "controller tar & md5 downloaded OK"
            echo "Candle: controller tar & md5 downloaded OK" | sudo tee -a /dev/kmsg
            echo "Candle: controller tar & md5 downloaded OK"| sudo tee -a $BOOT_DIR/candle_log.txt
        
            if [ "$(md5sum latest_stable_controller.tar | awk '{print $1}')"  = "$(cat $CANDLE_BASE/latest_stable_controller.tar.txt)" ]; then
                echo "MD5 checksum of latest_stable_controller.tar matched"
            
                chown pi:pi "$CANDLE_BASE/latest_stable_controller.tar"
            
                if [ -f "$CANDLE_BASE/controller_backup_fresh.tar" ]; then
                    rm "$CANDLE_BASE/controller_backup_fresh.tar"
                fi
            
            else
                echo "Candle: Error, MD5 checksum of latest_stable_controller.tar did not match, bad download?"
                echo "Candle: Error, MD5 checksum of latest_stable_controller.tar did not match, bad download?" | sudo tee -a /dev/kmsg
                echo "Candle: Error, MD5 checksum of latest_stable_controller.tar did not match, bad download?"| sudo tee -a $BOOT_DIR/candle_log.txt
            
                if [ -f "$CANDLE_BASE/latest_stable_controller.tar" ]; then
                    rm "$CANDLE_BASE/latest_stable_controller.tar"
                fi
                if [ -f "$CANDLE_BASE/latest_stable_controller.tar.txt" ]; then
                    rm "$CANDLE_BASE/latest_stable_controller.tar.txt"
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
            echo "Candle: Error, download of stable controller tar or md5 failed. Aborting." | sudo tee -a /dev/kmsg
            echo "$(date) - download of stable controller tar or md5 failed. Aborting." | sudo tee -a $BOOT_DIR/candle_log.txt
        
            if [ -f "$CANDLE_BASE/latest_stable_controller.tar" ]; then
                rm "$CANDLE_BASE/latest_stable_controller.tar"
            fi
            if [ -f "$CANDLE_BASE/latest_stable_controller.tar.txt" ]; then
                rm "$CANDLE_BASE/latest_stable_controller.tar.txt"
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
    else
        echo "latest_stable_controller.tar already downloaded"
    fi
    
fi





echo "candle: installing python gateway addon" | sudo tee -a /dev/kmsg
echo "candle: installing python gateway addon" | sudo tee -a $BOOT_DIR/candle_log.txt
python3 -m pip install git+https://github.com/createcandle/gateway-addon-python#egg=gateway_addon --break-system-packages

# Install the gateway addon for Python 3.11 too, if Python 3.11 exists
python3.11 --version && python3.11 -m pip install git+https://github.com/createcandle/gateway-addon-python#egg=gateway_addon



# install newer version of Python websocket client
#python3 -m pip install --force-reinstall -v "websocket-client==1.4.2"


if [ ! command -v npm &> /dev/null ] || [ "$(cat $CANDLE_BASE/.webthings/.node_version)" != 12 ];
then
    echo
    echo "NPM could not be found. Installing it now."
    echo "Candle: Installing NVM" | sudo tee -a /dev/kmsg
    echo "Candle: Installing NVM" | sudo tee -a $BOOT_DIR/candle_log.txt
    
    
    if [ -f ./install_nvm.sh ]; then
        rm ./install_nvm.sh
        echo "spotted NVM installation left-over: install_nvm.sh"
    fi
    #if [ -d ./.nvm ]; then
    #    rm -rf ./.nvm
    #    echo "spotted NVM installation left-over: .nvm dir"
    #fi
    #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
    #wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh -O install_nvm.sh
    #wget https://raw.githubusercontent.com/creationix/nvm/master/install.sh -O install_nvm.sh
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    #curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
    

    #. ~/.bashrc
    
    
    export NVM_DIR="$CANDLE_BASE/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    
    if [ -z "$(nvm --version)" ]; then
        echo "ERROR, nvm is not available. Installation failed?"
        echo "ERROR, nvm is not available. Installation failed?" | sudo tee -a /dev/kmsg
        echo "ERROR, nvm is not available. Installation failed?" | sudo tee -a $BOOT_DIR/candle_log.txt
        
        if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                sudo /bin/ply-image $BOOT_DIR/error.png
                sleep 7200
            fi
        
            exit 1
        fi
    else
        echo "NVM is available now"
    fi
    

    if cat "$CANDLE_BASE/.profile" | grep NVM
    then
        echo "NVM lines already appended to .profile"
        echo "NVM lines already appended to .profile" | sudo tee -a /dev/kmsg
        echo "NVM lines already appended to .profile" | sudo tee -a $BOOT_DIR/candle_log.txt
    else
        echo "Appending NVM lines to .profile"
        echo >> "$CANDLE_BASE/.profile"
        echo 'export NVM_DIR="$HOME/.nvm"' >> "$CANDLE_BASE/.profile"
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$CANDLE_BASE/.profile"
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$CANDLE_BASE/.profile"
    fi

    
    echo
    echo "starting nvm install"
    
    #nvm uninstall 12
    for v in $(nvm_ls 12); do nvm uninstall $v; done
    nvm install 12
    
    #nvm install 16
    
    #nvm uninstall 18
    #nvm uninstall 18
    for v in $(nvm_ls 18); do nvm uninstall $v; done
    nvm install 18
else
    echo "NPM seems to already be installed." | sudo tee -a /dev/kmsg
    echo "NPM seems to already be installed." | sudo tee -a $BOOT_DIR/candle_log.txt
fi


if [ -d "$CANDLE_BASE/.nvm" ]; then
    export NVM_DIR="$CANDLE_BASE/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi


if [ -f ./install_nvm.sh ]; then
    echo "removing install_nvm.sh"
    rm ./install_nvm.sh
fi

nvm use 18
nvm alias default 18

# install older version of NPM to avoid issue: reify:date-fns: http fetch GET 200 https://registry.npmjs.org/date-fns/-/date-fns-2.29.3.tgz 105523ms (cache miss)
# npm install -g npm@6.14.17 # Node 14 version # it seems waiting very long also solves it...


echo
echo "NODE AND NPM VERSIONS:"
node --version
npm --version
echo "Candle: Node --version: $(node --version)" | sudo tee -a /dev/kmsg
echo "Candle: NPM --version: $(npm --version)"   | sudo tee -a /dev/kmsg
echo "Candle: Node --version: $(node --version)" | sudo tee -a $BOOT_DIR/candle_log.txt
echo "Candle: NPM --version: $(npm --version)"   | sudo tee -a $BOOT_DIR/candle_log.txt

npm cache verify


#npm config set metrics-registry="https://"
#npm config set registry="https://"
#npm config set user-agent=""
if [ -f "$CANDLE_BASE/.npm/anonymous-cli-metrics.json" ]
then
  rm "$CANDLE_BASE/.npm/anonymous-cli-metrics.json"
fi


_node_version=$(node --version | grep -E -o '[0-9]+' | head -n1)
echo "Node version: ${_node_version}" | sudo tee -a /dev/kmsg
echo "Node version: ${_node_version}" | sudo tee -a $BOOT_DIR/candle_log.txt

echo "${_node_version}" > "$CANDLE_BASE/.webthings/.node_version"

echo "Node version in .node_version file:"
cat "$CANDLE_BASE/.webthings/.node_version"


sudo setcap cap_net_raw+eip $(eval readlink -f `which node`)
sudo setcap cap_net_raw+eip $(eval readlink -f `which python3`)


# Download Candle controller from Github and install it

echo ""
echo "INSTALLING CANDLE CONTROLLER"

echo ""



# Create a backup first

availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
if [ -f "$CANDLE_BASE/latest_stable_controller.tar" ]; then
    if [ "$availMem" -gt "200000" ]; 
    then
        if [ -f "$CANDLE_BASE/webthings/gateway/build/app.js" ] \
        && [ -f "$CANDLE_BASE/webthings/gateway/build/static/index.html" ] \
        && [ -f "$CANDLE_BASE/webthings/gateway/.post_upgrade_complete" ] \
        && [ -d "$CANDLE_BASE/webthings/gateway/node_modules" ] \
        && [ -d "$CANDLE_BASE/webthings/gateway/build/static/bundle" ];
        then
            echo "Detected old webthings directory! Creating fresh backup"
            echo "Candle: Detected old webthings directory. Creating fresh backup" | sudo tee -a /dev/kmsg
            echo "Candle: Detected old webthings directory. Creating fresh backup" | sudo tee -a $BOOT_DIR/candle_log.txt
            tar -czf ./controller_backup_fresh.tar ./webthings
        fi
    fi
fi



if [ -d ./candle-controller ]; then
    echo "spotted candle-controller directory. Must be left over from interupted install"
    rm -rf candle-controller
fi

# DOWNLOAD CANDLE CONTROLLER FROM GITHUB

if [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    
    echo "Candle: Starting controller source code download" | sudo tee -a /dev/kmsg
    echo "Candle: Starting controller source code download" | sudo tee -a $BOOT_DIR/candle_log.txt
    mkdir -p "$CANDLE_BASE/webthings"
    chown pi:pi "$CANDLE_BASE/webthings"
    cd "$CANDLE_BASE/webthings"
    
    git clone --depth 1 https://github.com/createcandle/candle-controller.git
    if [ -d ./candle-controller ]; then
        echo "Cutting edge controller download succeeded" | sudo tee -a /dev/kmsg
        echo "Cutting edge controller download succeeded" | sudo tee -a $BOOT_DIR/candle_log.txt
        rm -rf "$CANDLE_BASE/webthings/gateway2"
        mv -f ./candle-controller "$CANDLE_BASE/webthings/gateway2"
    else
        echo "ERROR, downloading cutting edge candle-controller dir from Github failed" | sudo tee -a /dev/kmsg
        echo "ERROR, downloading cutting edge candle-controller dir from Github failed" | sudo tee -a $BOOT_DIR/candle_log.txt
        
        if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
            if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                sudo /binif [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then/ply-image $BOOT_DIR/error.png
                sleep 7200
            fi
        
            exit 1
        fi
    fi
    
    
# Stable controller. Now simply downloads the entire folder and puts it into place.
else

    if [ -f "$CANDLE_BASE/latest_stable_controller.tar" ]; then
        
        echo "Will extract latest_stable_controller.tar"
        
        cd "$CANDLE_BASE"
        
        if [ -d "$CANDLE_BASE/webthings/gateway2" ]; then
            rm -rf "$CANDLE_BASE/webthings/gateway2"
        fi

        availMem=$(df -P "/dev/mmcblk0p2" | awk 'END{print $4}')
        if [ "$availMem" -gt "1000000" ]; 
        then
            echo "Candle: Doing safe unpack of latest_stable_controller.tar"
            echo "Candle: Doing safe unpack of latest_stable_controller.tar" | sudo tee -a /dev/kmsg
            echo "Doing safe unpack of latest_stable_controller.tar" | sudo tee -a $BOOT_DIR/candle_log.txt
            mkdir -p "$CANDLE_BASE/downloaded_controller"
            rm -rf "$CANDLE_BASE/downloaded_controller/*"
            echo "extracting"
            tar -xf latest_stable_controller.tar -C "$CANDLE_BASE/downloaded_controller"
            
            ls "$CANDLE_BASE/downloaded_controller"
            
            if [ -f "$CANDLE_BASE/downloaded_controller/webthings/gateway/.post_upgrade_complete" ]; then
                echo "extraction worked fine"
                if [ -d "$CANDLE_BASE/webthings/gateway" ]; then
                    rm -rf "$CANDLE_BASE/webthings/gateway"
                fi
                echo "moving extracted gateway dir into place"
                mv "$CANDLE_BASE/downloaded_controller/webthings/gateway $CANDLE_BASE/webthings/gateway"
            else
                echo "extraction did not go as planned"    
            fi
            
            echo "removing extracted files"
            rm -rf "$CANDLE_BASE/downloaded_controller"
            
        else
            # more risky move because of low disk space
            echo "Candle: Low disk space, doing direct unpack of latest_stable_controller.tar" | sudo tee -a /dev/kmsg
            echo "Low disk space, doing direct unpack of latest_stable_controller.tar" | sudo tee -a $BOOT_DIR/candle_log.txt
            
            if [ -d "$CANDLE_BASE/webthings" ]; then
                sudo rm -rf "$CANDLE_BASE/webthings"
            fi
            tar -xf latest_stable_controller.tar
        fi
        
    else
        
        echo "Stable, but latest_stable_controller.tar missing. Attempting build." | sudo tee -a /dev/kmsg
        echo "Stable, but latest_stable_controller.tar missing. Attempting build." | sudo tee -a $BOOT_DIR/candle_log.txt
        
        mkdir -p "$CANDLE_BASE/webthings"
        chown pi:pi "$CANDLE_BASE/webthings"
        cd "$CANDLE_BASE/webthings"
        
        curl -s https://api.github.com/repos/createcandle/candle-controller/releases/latest \
        | grep "tarball_url" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O candle-controller-git.tar

        if [ -f candle-controller-git.tar ]; then
            echo "Stable Github Candle Controller release download succeeded" | sudo tee -a /dev/kmsg
            echo "Stable Github Candle Controller release download succeeded" | sudo tee -a $BOOT_DIR/candle_log.txt
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
            echo "ls $CANDLE_BASE/webthings/gateway2:"
            ls "$CANDLE_BASE/webthings/gateway2"
        else
            echo "ERROR, downloading latest stable release of candle-controller source dir from Github failed" | sudo tee -a /dev/kmsg
            echo "ERROR, downloading latest stable release of candle-controller source dir from Github failed" | sudo tee -a $BOOT_DIR/candle_log.txt
        
            if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
                if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
                    sudo /bin/ply-image $BOOT_DIR/error.png
                    sleep 7200
                fi
        
                exit 1
            fi
            
        fi
    fi

fi


if [ -f $BOOT_DIR/candle_cutting_edge.txt ] && [ ! -d "$CANDLE_BASE/webthings/gateway2" ]; then
    echo
    echo "ERROR, missing gateway2 directory"
    echo "Candle: ERROR, missing gateway2 directory" | sudo tee -a /dev/kmsg
    echo "Candle: ERROR, missing gateway2 directory" | sudo tee -a $BOOT_DIR/candle_log.txt
    echo
    
    
    if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
            sudo /bin/ply-image $BOOT_DIR/error.png
            sleep 7200
        fi

        exit 1
    fi
fi


if [ -d "$CANDLE_BASE/webthings/gateway2" ]; then
    echo "$CANDLE_BASE/webthings/gateway2 exists"
    
    cd "$CANDLE_BASE/webthings/gateway2"

    rm -rf node_modules/

    export CPPFLAGS="-DPNG_ARM_NEON_OPT=0"
    # CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install imagemin-optipng --save-dev
    # npm install typescript --save-dev # TODO: check if this is now in package.json already

    # npm install
    echo "Candle: Installing Node modules (takes a while)" | sudo tee -a /dev/kmsg
    echo "Candle: Installing Node modules (takes a while)" | sudo tee -a $BOOT_DIR/candle_log.txt
    
    echo "Do not worry about the errors you will see with optipng and jpegtran"
    
    #CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install
    CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm ci
    #CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm ci --production


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
    echo "Candle: Compiling typescript. This will take a while..." | sudo tee -a $BOOT_DIR/candle_log.txt
    npx tsc -p .
    echo "(it probably found some errors, don't worry about those)"
    echo
    #echo "Running webpack. this will take a while too..."
    echo "Candle: Running webpack. This will take a while too..." | sudo tee -a /dev/kmsg
    echo "Candle: Running webpack. This will take a while too..." | sudo tee -a $BOOT_DIR/candle_log.txt
    
    totalk="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
    echo "memory size: $totalk"
    if [ "$totalk" -lt 600000 ]
    then
        echo "very low memory, --max-old-space-size=496"
        NODE_OPTIONS="--max-old-space-size=496" npm_config_yes=true npx webpack
    elif [ "$totalk" -lt 1200000 ]
    then
        echo "low memory, --max-old-space-size=750"
        NODE_OPTIONS="--max-old-space-size=750" npm_config_yes=true npx webpack
    elif [ "$totalk" -lt 2200000 ]
    then
        echo "normal memory, --max-old-space-size=1024"
        NODE_OPTIONS="--max-old-space-size=1024" npm_config_yes=true npx webpack  #--yes
    else
        echo "big memory, --max-old-space-size=2048"
        NODE_OPTIONS="--max-old-space-size=2048" npm_config_yes=true npx webpack
    fi
    
    
    if [ -f "$CANDLE_BASE/webthings/gateway2/build/app.js" ] \
    && [ -f "$CANDLE_BASE/webthings/gateway2/build/static/index.html" ] \
    && [ -d "$CANDLE_BASE/webthings/gateway2/node_modules" ] \
    && [ -d "$CANDLE_BASE/webthings/gateway2/build/static/bundle" ];
    then

      npx update-browserslist-db@latest
       
      npm prune --omit=dev
    
      echo "creating .post_upgrade_complete file"
      touch .post_upgrade_complete
      echo "$(date +%s)" > update_date.txt
      #echo "Controller installation seems ok"
      echo "Controller installation seems ok, at $(pwd)"
      echo "Controller installation seems ok, at $(pwd)" | sudo tee -a /dev/kmsg
      
    else
      echo  
      echo "ERROR, controller installation is missing parts"
      echo "Candle: ERROR, controller installation is mising parts" | sudo tee -a /dev/kmsg
      echo "$(date) - ERROR, controller installation is mising parts" | sudo tee -a $BOOT_DIR/candle_log.txt
      ls "$CANDLE_BASE/webthings/gateway2/build/app.js"
      ls "$CANDLE_BASE/webthings/gateway2/build/static/index.html"
      ls "$CANDLE_BASE/webthings/gateway2/node_modules"
      ls "$CANDLE_BASE/webthings/gateway2/build/static/bundle" 
      echo
    fi

    echo
    echo "New controller was created at $(pwd)"
    echo
    # Move the freshly created gateway into position
    cd "$CANDLE_BASE"
    if [ -d "$CANDLE_BASE/webthings/gateway2" ]; then
    
        echo "Starting move/copy of $CANDLE_BASE/webthings/gateway2 to $CANDLE_BASE/webthings/gateway"

        if [ ! -d "$CANDLE_BASE/webthings/gateway" ]; then
            echo "Candle: Gateway didn't exist, moving gateway2 into position"
            echo "Candle: Gateway didn't exist, moving gateway2 into position" | sudo tee -a /dev/kmsg
            echo "Candle: Gateway didn't exist, moving gateway2 into position" | sudo tee -a $BOOT_DIR/candle_log.txt
            mv "$CANDLE_BASE/webthings/gateway2" "$CANDLE_BASE/webthings/gateway"
        else
            echo "Candle: Gateway dir existed, doing rsync from gateway2"
            echo "Candle: Gateway dir existed, doing rsync from gateway2" | sudo tee -a /dev/kmsg
            echo "Candle: Gateway dir existed, doing rsync from gateway2" | sudo tee -a $BOOT_DIR/candle_log.txt
            
            # rsync recursive, quiet, checksum, copy symlinks as symlinks, preserve Executability, delete extraneous files from destination, show progress
            rsync -r -q -c -l -E --delete --progress "$CANDLE_BASE/webthings/gateway2/" "$CANDLE_BASE/webthings/gateway/"
            
            chown -R pi:pi "$CANDLE_BASE/webthings/gateway"
            rm -rf "$CANDLE_BASE/webthings/gateway2"
        fi
    else
        # This should never happen
        echo "ERROR, gateway2 was just created.. but is missing?" | sudo tee -a /dev/kmsg
        echo "ERROR, gateway2 was just created.. but is missing?" | sudo tee -a $BOOT_DIR/candle_log.txt
    fi
    
fi




echo
echo
echo "Candle: Linking gateway addon" | sudo tee -a /dev/kmsg
echo "Candle: Linking gateway addon" | sudo tee -a $BOOT_DIR/candle_log.txt
if [ -d "$CANDLE_BASE/webthings/gateway/node_modules/gateway-addon" ];
then
    cd "$CANDLE_BASE/webthings/gateway/node_modules/gateway-addon"
    npm link
    cd "$CANDLE_BASE"
else
    echo "ERROR, $CANDLE_BASE/webthings/gateway/node_modules/gateway-addon was missing"
    echo "Candle: ERROR, $CANDLE_BASE/webthings/gateway/node_modules/gateway-addon was missing" | sudo tee -a /dev/kmsg
    echo "Candle: ERROR, $CANDLE_BASE/webthings/gateway/node_modules/gateway-addon was missing" | sudo tee -a $BOOT_DIR/candle_log.txt
fi




# TODO: maybe do another sanity check and restore a backup if need be?


if [ ! -f "$CANDLE_BASE/webthings/gateway/build/app.js" ] \
|| [ ! -f "$CANDLE_BASE/webthings/gateway/build/static/index.html" ] \
|| [ ! -f "$CANDLE_BASE/webthings/gateway/.post_upgrade_complete" ] \
|| [ ! -d "$CANDLE_BASE/webthings/gateway/node_modules" ] \
|| [ ! -d "$CANDLE_BASE/webthings/gateway/build/static/bundle" ]; 
then
    echo "Candle: WARNING, INSTALLATION OF CANDLE CONTROLLER FAILED! Backup not created."   | sudo tee -a /dev/kmsg
    echo "$(date) - WARNING, INSTALLATION OF CANDLE CONTROLLER FAILED! Backup not created." | sudo tee -a $BOOT_DIR/candle_log.txt

    ls "$CANDLE_BASE/webthings/gateway/build/app.js"
    ls "$CANDLE_BASE/webthings/gateway/build/static/index.html"
    ls "$CANDLE_BASE/webthings/gateway/.post_upgrade_complete"
    ls "$CANDLE_BASE/webthings/gateway/node_modules"
    ls "$CANDLE_BASE/webthings/gateway/build/static/bundle"
    
    # restore the backup in case something has gone very wrong
    if [ -f "$CANDLE_BASE/controller_backup.tar" ];
    then
        echo "Candle: RESTORING BACKUP" | sudo tee -a /dev/kmsg
        echo "$(date) RESTORING BACKUP" | sudo tee -a $BOOT_DIR/candle_log.txt
        cd "$CANDLE_BASE"
        sudo rm -rf "$CANDLE_BASE/webthings"
        tar -xf ./controller_backup.tar
    else
        echo "Candle: NO BACKUP TO RESTORE!" | sudo tee -a /dev/kmsg
        echo "$(date) NO BACKUP TO RESTORE!" | sudo tee -a $BOOT_DIR/candle_log.txt
        
        # Could abort here..
    fi
    
else
    echo
    echo "Everything looks good"
    echo "Candle: a valid controller exists" | sudo tee -a /dev/kmsg
    echo "Candle: a valid controller exists" | sudo tee -a $BOOT_DIR/candle_log.txt
    echo
fi


cd "$CANDLE_BASE"


#
#  NODE SYMLINKS
#
# Create shortcuts to multiple installed node versions. 

# These are kept in user home directory so that the gateway can be replaced independently of node.
#cd "$CANDLE_BASE/webthings/gateway"

# Node 12
V12=$(ls $CANDLE_BASE/.nvm/versions/node | grep v12 | head -n 1) # TODO: this now assumes that the candle base dir is also a user root dir with nvm installed. Is that wise?
echo "V12: $V12"
V12_PATH="$CANDLE_BASE/.nvm/versions/node/$V12/bin/node"
echo "Node V12 path: $V12_PATH"
if [ -L node12 ]; then
    echo "removing old node12 symlink first"
    rm node12
fi
ln -s "$V12_PATH" node12

# NODE 16
#V16=$(ls $CANDLE_BASE/.nvm/versions/node | grep v16)
#echo "V16: $V16"
#V16_PATH="$CANDLE_BASE/.nvm/versions/node/$V16/bin/node"
#echo "Node V16 path: $V16_PATH"
#if [ -L node16 ]; then
#    echo "removing old node16 symlink first"
#    rm node16
#fi
#ln -s "$V16_PATH" node16

# NODE 18
V18=$(ls $CANDLE_BASE/.nvm/versions/node | grep v18 | head -n 1)
echo "V18: $V18"
V18_PATH="$CANDLE_BASE/.nvm/versions/node/$V18/bin/node"
echo "Node V18 path: $V18_PATH"
if [ -L node18 ]; then
    echo "removing old node18 symlink first"
    rm node18
fi
ln -s "$V18_PATH" node18






cd "$CANDLE_BASE"


echo
echo "INSTALLING CANDLE ADDONS"
echo

mkdir -p "$CANDLE_BASE/.webthings/addons"
chown -R pi:pi "$CANDLE_BASE/.webthings/addons"



if [ ! -f "$CANDLE_BASE/.webthings/config/db.sqlite3" ] || [ ! -d "$CANDLE_BASE/.webthings/addons/power-settings" ];
then
    echo "installing power settings addon"
    
    cd "$CANDLE_BASE/.webthings/addons"
    
    for addon in power-settings; 
    do
        echo "$addon"
        curl -s "https://api.github.com/repos/createcandle/$addon/releases/latest" \
            | grep "browser_download_url" \
            | grep -v ".sha256sum" \
            | grep "$ARCHSTRING-v3.9" \
            | cut -d : -f 2,3 \
            | tr -d \" \
            | sed 's/,*$//' \
            | wget -qi - -O addon.tgz
        if [ -f addon.tgz ]; then
            tar -xf addon.tgz
            rm addon.tgz
            
            #for directory in createcandle-"$addon"*; do
            #  [[ -d $directory ]] || continue
            #  echo "Directory: $directory"
            #  rm -rf ./"$addon"
            #  mv -- "$directory" ./$addon
            #done
            rm -rf "$addon"
            mv package "$addon"
            chown -R pi:pi "$addon"
            mkdir -p "$CANDLE_BASE/.webthings/data/$addon"
        else
            echo
            echo "ERROR, power settings tar was not downloaded from github"
            exit 1
        fi
    done
    
else
    echo "no need to (re-)install power-settings addon"
fi


# Once the Candle app store exists, this part is never run again.
# TODO: what if part of this failed?
if [ ! -d "$CANDLE_BASE/.webthings/addons/candleappstore" ]; 
then
    echo "Candle: Installing addons" | sudo tee -a /dev/kmsg
    echo "Candle: Installing addons" | sudo tee -a $BOOT_DIR/candle_log.txt
        
    cd "$CANDLE_BASE/.webthings/addons"


    # Install Zigbee2MQTT
    
    echo "zigbee2mqtt-adapter"
    if [ $BIT_TYPE -eq 64 ]; then
        curl -s https://api.github.com/repos/kabbi/zigbee2mqtt-adapter/releases/latest \
        | grep "browser_download_url" \
        | grep "linux-arm64" \
        | grep -v ".sha256sum" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O addon.tgz
    else
        curl -s https://api.github.com/repos/kabbi/zigbee2mqtt-adapter/releases/latest \
        | grep "browser_download_url" \
        | grep -v "linux-arm64" \
        | grep -v ".sha256sum" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O addon.tgz
    fi
    tar -xf addon.tgz
    rm addon.tgz
    #for directory in kabbi-zigbee2mqtt-adapter*; do
    #  [[ -d $directory ]] || continue
    #  echo "Directory: $directory"
    #  mv -- "$directory" ./zigbee2mqtt-adapter
    #done
    #chown -R pi:pi zigbee2mqtt-adapter
    #mkdir -p /home/pi/.webthings/data/zigbee2mqtt-adapter
    #rm ./*.tgz
    rm -rf zigbee2mqtt-adapter
    mv package zigbee2mqtt-adapter
    chown -R pi:pi zigbee2mqtt-adapter
    mkdir -p "$CANDLE_BASE/.webthings/data/zigbee2mqtt-adapter"
    
    
    
    # Install Flatsiedatsie addons
    
    for addon in photo-frame internet-radio;
    do
        echo "$addon"
        curl -s "https://api.github.com/repos/flatsiedatsie/$addon/releases/latest" \
            | grep "browser_download_url" \
            | grep "$ARCHSTRING-v3.9" \
            | grep -v ".sha256sum" \
            | cut -d : -f 2,3 \
            | tr -d \" \
            | sed 's/,*$//' \
            | wget -qi - -O addon.tgz
        tar -xf addon.tgz
        rm addon.tgz
        
        rm -rf "$addon"
        mv package "$addon"
        chown -R pi:pi "$addon"
        mkdir -p "$CANDLE_BASE/.webthings/data/$addon"
        #for directory in flatsiedatsie-"$addon"*; do
        #  [[ -d $directory ]] || continue
        #  echo "Directory: $directory"
        #  rm -rf ./"$addon"
        #  mv -- "$directory" ./$addon
        #done
        #chown -R pi:pi $addon
        #mkdir -p /home/pi/.webthings/data/"$addon"
    done



    # Install followers
    # separate because tar file name and addon name are not the same (followers / followers-addon)
    
    echo "followers-addon"
    curl -s "https://api.github.com/repos/flatsiedatsie/followers-addon/releases/latest" \
        | grep "browser_download_url" \
        | grep "$ARCHSTRING-v3.9" \
        | grep -v ".sha256sum" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O addon.tgz
    tar -xf addon.tgz
    rm addon.tgz
    
    rm -rf followers
    mv package followers
    chown -R pi:pi followers
    mkdir -p "$CANDLE_BASE/.webthings/data/followers"


    for addon in candleappstore; 
    do
        
        echo "$addon"
        curl -s "https://api.github.com/repos/createcandle/$addon/releases/latest" \
            | grep "browser_download_url" \
            | grep "$ARCHSTRING-v3.9" \
            | grep -v ".sha256sum" \
            | cut -d : -f 2,3 \
            | tr -d \" \
            | sed 's/,*$//' \
            | wget -qi - -O addon.tgz
        tar -xf addon.tgz
        rm addon.tgz
        
        #for directory in createcandle-"$addon"*; do
        #  [[ -d $directory ]] || continue
        #  echo "Directory: $directory"
        #  rm -rf ./"$addon"
        #  mv -- "$directory" ./$addon
        #done
        rm -rf "$addon"
        mv package "$addon"
        chown -R pi:pi "$addon"
        mkdir -p "$CANDLE_BASE/.webthings/data/$addon"
    done

    # Install Candle addons
    
    for addon in candle-theme tutorial bluetoothpairing privacy-manager webinterface scenes; 
    do
        echo "$addon"
        curl -s "https://api.github.com/repos/createcandle/$addon/releases/latest" \
            | grep "browser_download_url" \
            | grep "$ARCHSTRING-v3.9" \
            | grep -v ".sha256sum" \
            | cut -d : -f 2,3 \
            | tr -d \" \
            | sed 's/,*$//' \
            | wget -qi - -O addon.tgz
        tar -xf addon.tgz
        rm addon.tgz
        
        #for directory in createcandle-"$addon"*; do
        #  [[ -d $directory ]] || continue
        #  echo "Directory: $directory"
        #  rm -rf ./"$addon"
        #  mv -- "$directory" ./$addon
        #done
        rm -rf "$addon"
        mv package "$addon"
        chown -R pi:pi "$addon"
        mkdir -p "$CANDLE_BASE/.webthings/data/$addon"
    done
    
    rm ./*.tgz

fi




if [ -d "$CANDLE_BASE/.webthings/data/zigbee2mqtt-adapter" ];
then
    
    if [ ! -d "$CANDLE_BASE/.webthings/data/zigbee2mqtt-adapter/zigbee2mqtt" ];
    then
        cd "$CANDLE_BASE/.webthings/data/zigbee2mqtt-adapter"
    
        echo
        echo "pre-installing Zigbee2MQTT"
        echo
        curl -s "https://api.github.com/repos/Koenkk/zigbee2mqtt/releases/latest" \
        | grep "tarball_url" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O z2m.tgz
        echo "unpacking z2m.tgz"
        tar -xf z2m.tgz
        rm z2m.tgz

        for directory in Koenkk-zigbee2mqtt*; do
          [[ -d $directory ]] || continue
          echo "Directory: $directory"
          rm -rf ./zigbee2mqtt
          mv -- "$directory" ./zigbee2mqtt
        done
    
        if [ -d ./zigbee2mqtt ]; then
            chown -R pi:pi ./zigbee2mqtt
            cd ./zigbee2mqtt
            npm install -g typescript; 
            npm i --save-dev @types/node;
            npm ci
            #npm ci --production
        else
            echo "Error, pre-install of z2m failed: no dir"
        fi
        #https://api.github.com/repos/Koenkk/zigbee2mqtt/releases/latest
    
        cd "$CANDLE_BASE"
    else
        echo "Warning, Z2M was already downloaded"
    fi
    
else
    echo "Candle: WARNING, $CANDLE_BASE/.webthings/data/zigbee2mqtt does not exist? Cannot pre-install zigbee2mqtt"
    echo "Candle: WARNING, $CANDLE_BASE/.webthings/data/zigbee2mqtt does not exist? Cannot pre-install zigbee2mqtt" | sudo tee -a /dev/kmsg
    echo "$(date) $CANDLE_BASE/.webthings/data/zigbee2mqtt does not exist? Cannot pre-install zigbee2mqtt" | sudo tee -a $BOOT_DIR/candle_log.txt
fi





#cd /home/pi/webthings/gateway
#timeout 10 npm run run-only
echo "controller installation should be complete"
echo "ls $CANDLE_BASE/.webthings:"
ls "$CANDLE_BASE/.webthings"

cd "$CANDLE_BASE"



mkdir -p "$CANDLE_BASE/.webthings/config"
chown -R pi:pi "$CANDLE_BASE/.webthings/config"
if [ ! -f "$CANDLE_BASE/.webthings/config/db.sqlite3" ];
then
    echo "Candle: copying initial Candle database from power settings addon" | sudo tee -a /dev/kmsg
    echo "Candle: copying initial Candle database from power settings addon" | sudo tee -a $BOOT_DIR/candle_log.txt
    if [ -f "$CANDLE_BASE/.webthings/addons/power-settings/db.sqlite3" ]; then
        cp "$CANDLE_BASE/.webthings/addons/power-settings/db.sqlite3" "$CANDLE_BASE/.webthings/config/db.sqlite3"
        chown pi:pi "$CANDLE_BASE/.webthings/config/db.sqlite3"
    else
        echo "ERROR, $CANDLE_BASE/.webthings/addons/power-settings/db.sqlite3 was missing"
        echo "Candle: ERROR, $CANDLE_BASE/.webthings/addons/power-settings/db.sqlite3 was missing" | sudo tee -a /dev/kmsg
        echo "Candle: ERROR, $CANDLE_BASE/.webthings/addons/power-settings/db.sqlite3 was missing" | sudo tee -a $BOOT_DIR/candle_log.txt
    fi
else
    echo "warning, not copying default database since a database file already exists"
    echo "Candle: Database file already existed, not replacing it" | sudo tee -a /dev/kmsg
    echo "Candle: Database file already existed, not replacing it" | sudo tee -a $BOOT_DIR/candle_log.txt
fi



npm config set metrics-registry="https://"
#npm config set registry="https://"
npm config set user-agent=""
if [ -f "$CANDLE_BASE/.npm/anonymous-cli-metrics.json" ]
then
  rm "$CANDLE_BASE/.npm/anonymous-cli-metrics.json"
fi

npm cache clean --force
nvm cache clear

echo
#echo "sub-script that installs the Candle controller is done. Returning to the main install script."
echo "Candle: Returning to the main install script." | sudo tee -a /dev/kmsg
echo "Candle: Returning to the main install script." | sudo tee -a $BOOT_DIR/candle_log.txt
echo
exit 0


