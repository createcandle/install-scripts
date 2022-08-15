#!/bin/bash
set +e

#part of the Candle disk image creation script

# This script should be run as user pi (not root)
if ! [ "$EUID" -ne 0 ]
then
  echo "Please run as user pi (do not use sudo)"
  exit
fi


echo "HOME: $HOME"

cd /home/pi || exit

echo "installing python gateway addon"
echo "candle: installing python gateway addon" | sudo tee -a /dev/kmsg
python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon

if [ ! command -v npm &> /dev/null ] || [ $(cat /home/pi/.webthings/.node_version) != 12 ];
then
    echo
    echo "NPM could not be found. Installing it now."
    echo "candle: installing NVM" | sudo tee -a /dev/kmsg
    
    
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
    chmod +x install_nvm.sh
    ./install_nvm.sh

    #. ~/.bashrc

    if cat /home/pi/.profile | grep NVM
    then
        echo "NVM lines already appended to .profile"
        echo "NVM lines already appended to .profile" | sudo tee -a /dev/kmsg
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
    echo "NPM seems to already be installed."
    echo "NPM seems to already be installed." | sudo tee -a /dev/kmsg
fi


if [ -d /home/pi/.nvm ]; then
    export NVM_DIR="/home/pi/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi



echo
echo "NODE AND NPM VERSIONS:"
node --version
npm --version
echo "candle: node --version: $(node --version)" | sudo tee -a /dev/kmsg
echo "candle: npm --version: $(npm --version)" | sudo tee -a /dev/kmsg


npm cache verify


npm config set metrics-registry="https://"
#npm config set registry="https://"
#npm config set user-agent=""
if [ -f /home/pi/.npm/anonymous-cli-metrics.json ]
then
  rm /home/pi/.npm/anonymous-cli-metrics.json
fi




# Download Candle controller from Github and install it

echo
echo "DOWNLOADING AND INSTALLING CANDLE CONTROLLER"
echo "Do not worry about the errors you will see with optipng and jpegtran"
echo


# Create a backup first
if [ -f /home/pi/webthings/gateway/build/app.js ] \
&& [ -f /home/pi/webthings/gateway/build/static/index.html ] \
&& [ -d /home/pi/webthings/gateway/node_modules ] \
&& [ -d /home/pi/webthings/gateway/build/static/bundle ];
then
    echo "Detected old webthings directory! Creating aditional backup"
    echo "Detected old webthings directory! Creating additional backup" | sudo tee -a /dev/kmsg
    #mv /home/pi/webthings /home/pi/webthings-old
    tar -czf ./controller_backup_fresh.tar ./webthings
fi



#rm -rf /home/pi/webthings

echo "Starting controller installation" | sudo tee -a /dev/kmsg
mkdir -p /home/pi/webthings
chown pi:pi /home/pi/webthings
cd /home/pi/webthings

if [ -d ./candle-controller ]; then
    echo "spotted candle-controller directory. Must be left over from interupted install"
    rm -rf candle-controller
fi


#!/bin/bash

# DOWNLOAD CANDLE CONTROLLER FROM GITHUB

if [ -f /boot/developer.txt ]; then
    git clone --depth 1 https://github.com/createcandle/candle-controller.git
    mv candle-controller gateway2
    
else
    curl -s https://api.github.com/repos/createcandle/candle-controller/releases/latest \
    | grep "tarball_url" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | sed 's/,*$//' \
    | wget -qi - -O candle-controller.tar

    tar -xf candle-controller.tar
    rm candle-controller.tar
    
    for directory in createcandle-candle-controller*; do
      [[ -d $directory ]] || continue
      echo "Directory: $directory"
      mv -- "$directory" ./gateway2
    done
    
    #mv ./install-scripts/install_candle_controller.sh ./install_candle_controller.sh
    echo
    echo "result:"
    ls ./gateway2
fi

if [ ! -d gateway2 ]; then
    echo
    echo "ERROR, missing gateway2 directory"
    echo
    exit 1
fi




chown -R pi:pi /home/pi/webthings/gateway2
cd gateway2

rm -rf node_modules/

export CPPFLAGS="-DPNG_ARM_NEON_OPT=0"
# CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install imagemin-optipng --save-dev
# npm install typescript --save-dev # TODO: check if this is now in package.json already
# npm install
CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm ci

#echo "Does node_modules exist now?: $(ls /home/pi/webthings/gateway)" | sudo tee -a /dev/kmsg

sudo setcap cap_net_raw+eip $(eval readlink -f `which node`)
sudo setcap cap_net_raw+eip $(eval readlink -f `which python3`)


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
echo "Compiling typescript. this will take a while..." | sudo tee -a /dev/kmsg
npx tsc -p .
echo "(it probably found some errors, don't worry about those)"
echo
#echo "Running webpack. this will take a while too..."
echo "Running webpack. this will take a while too..." | sudo tee -a /dev/kmsg
NODE_OPTIONS="--max-old-space-size=496" npx webpack


if [ -f /home/pi/webthings/gateway2/build/app.js ] \
&& [ -f /home/pi/webthings/gateway2/build/static/index.html ] \
&& [ -d /home/pi/webthings/gateway2/node_modules ] \
&& [ -d /home/pi/webthings/gateway2/build/static/bundle ];
then
  touch .post_upgrade_complete
  #echo "Controller installation seems ok"
  echo "Controller installation seems ok" | sudo tee -a /dev/kmsg
else
  echo  
  echo "ERROR, controller installation is mising parts"
  echo
  echo "Candle: ERROR, controller installation is mising parts" | sudo tee -a /dev/kmsg
  echo "$(date) - ERROR, controller installation is mising parts" | sudo tee -a /boot/candle.log
fi

_node_version=$(node --version | grep -E -o '[0-9]+' | head -n1)
echo "Node version: ${_node_version}" | sudo tee -a /dev/kmsg

echo "${_node_version}" > "/home/pi/.webthings/.node_version"
echo "Node version in .node_version file:"
cat /home/pi/.webthings/.node_version


# Move the freshly created gateway into position
cd /home/pi
mv /home/pi/webthings/gateway2 /home/pi/webthings/gateway

echo
echo "Linking gateway addon"
if [ -d /home/pi/webthings/gateway/node_modules/gateway-addon ];
then
  cd "/home/pi/webthings/gateway/node_modules/gateway-addon"
  npm link
  cd -
else
  echo "ERROR, node_modules/gateway-addon was missing"
  echo "ERROR, node_modules/gateway-addon was missing" | sudo tee -a /dev/kmsg
fi


echo
echo "INSTALLING CANDLE ADDONS"
echo

mkdir -p /home/pi/.webthings/addons
chown -R pi:pi /home/pi/.webthings/addons


if [ ! -f /home/pi/.webthings/config/db.sqlite ] || [ ! -d /home/pi/.webthings/addons/power-settings ];
then
    rm -rf package
    rm -rf power-settings
    wget https://github.com/createcandle/power-settings/releases/download/3.2.37/power-settings-3.2.37.tgz
    for f in power-settings*.tgz; do
        tar -xf "$f"
    done
    mv package power-settings
    chown -R pi:pi power-settings
    rm ./*.tgz
fi


if [ ! -d /home/pi/.webthings/addons/candleappstore ]; 
then
    echo "Installing addons" | sudo tee -a /dev/kmsg
        
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
    wget https://github.com/flatsiedatsie/photo-frame/releases/download/1.4.16/photo-frame-1.4.16.tgz
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
    wget https://github.com/flatsiedatsie/internet-radio/releases/download/2.1.32/internet-radio-2.1.32.tgz
    for f in internet-radio*.tgz; do
        tar -xf "$f"
    done
    mv package internet-radio
    chown -R pi:pi internet-radio
    rm ./*.tgz

    rm -rf package
    rm -rf zigbee2mqtt-adapter
    wget https://github.com/kabbi/zigbee2mqtt-adapter/releases/download/1.1.3/zigbee2mqtt-adapter-1.1.3.tgz
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
    
    rm candleappstore-0.4.18-linux-arm-v3.9.tgz
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
rm ./install_nvm.sh

mkdir -p /home/pi/.webthings/config
chown -R pi:pi /home/pi/.webthings/config
if [ ! -f /home/pi/.webthings/config/db.sqlite3 ];
then
    echo "copying initial Candle database from power settings addon"
    cp /home/pi/.webthings/addons/power-settings/db.sqlite3 /home/pi/.webthings/config/db.sqlite3
    chown pi:pi /home/pi/.webthings/config/db.sqlite3
else
    echo "warning, not copying default database since a database file already exists"
    echo "Database file already existed" | sudo tee -a /dev/kmsg
fi



npm config set metrics-registry="https://"
#npm config set registry="https://"
npm config set user-agent=""
rm /home/pi/.npm/anonymous-cli-metrics.json

npm cache clean --force
nvm cache clear

echo
#echo "sub-script that installs the Candle controller is done. Returning to the main install script."
echo "sub-script that installs the Candle controller is done. Returning to the main install script." | sudo tee -a /dev/kmsg
echo
exit 0


