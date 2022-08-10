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
python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon

if ! command -v npm &> /dev/null
then
    echo "NPM could not be found. Installing it now."
    echo "Installing NVM" >> sudo tee -a /dev/kmsg
    
    echo "installing NVM"
    rm ./install_nvm.sh
    #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
    wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh -O install_nvm.sh
    chmod +x install_nvm.sh
    ./install_nvm.sh

    #. ~/.bashrc

    if cat /home/pi/.profile | grep NVM
    then
        echo "NVM lines already appended to .profile"
    else
        echo "Appending NVM lines to .profile"
        echo " " >> /home/pi/.profile
        echo 'export NVM_DIR="/home/pi/.nvm"' >> /home/pi/.profile
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/pi/.profile
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/pi/.profile
    fi

    export NVM_DIR="/home/pi/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

    nvm install 14
    nvm use 14
    nvm alias default 14
else
    echo "NPM seems to already be installed."
    echo "NPM seems to already be installed." >> sudo tee -a /dev/kmsg
fi



echo " "
echo "NODE AND NPM VERSIONS:"
node --version
npm --version

npm config set metrics-registry="https://"
#npm config set registry="https://"
npm config set user-agent=""
if [ -f /home/pi/.npm/anonymous-cli-metrics.json ]
then
  rm /home/pi/.npm/anonymous-cli-metrics.json
fi

echo " "
echo "DOWNLOADING AND INSTALLING CANDLE CONTROLLER"
echo "Do not worry about the errors you will see with optipng and jpegtran"
echo " "

# Download Candle controller from Github and install it

if [ -f /home/pi/webthings/build/app.js ]
then
    echo "Detected old webthings directory! Renamed it to webthings-old"
    echo "Detected old webthings directory! Renamed it to webthings-old" >> sudo tee -a /dev/kmsg
    mv /home/pi/webthings /home/pi/webthings-old
fi
rm -rf /home/pi/webthings

echo "Starting gateway installation" >> sudo tee -a /dev/kmsg
mkdir -p /home/pi/webthings
chown pi:pi /home/pi/webthings
cd /home/pi/webthings
rm -rf candle-controller
rm -rf gateway
git clone --depth 1 https://github.com/createcandle/candle-controller.git
mv candle-controller gateway
chown -R pi:pi /home/pi/webthings/gateway
cd gateway

rm -rf node_modules/

export CPPFLAGS="-DPNG_ARM_NEON_OPT=0"
# CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm install imagemin-optipng --save-dev
# npm install typescript --save-dev # TODO: check if this is now in package.json already
# npm install
CPPFLAGS="-DPNG_ARM_NEON_OPT=0" npm ci

echo " "
echo "COMPILING TYPESCRIPT AND RUNNING WEBPACK"
echo "Compiling Typescript and running Webpack" >> sudo tee -a /dev/kmsg

#npm run build

#npm install -D webpack-cli

rm -rf build
cp -rL src build
cp -rL static build/static
find build -name '*.ts' -delete
echo "Compiling typescript. this will take a while..."
npx tsc -p .
echo "(it probably found some errors, don't worry about those)"
echo " "
echo "Running webpack. this will take a while too..."
NODE_OPTIONS="--max-old-space-size=496" npx webpack

touch .post_upgrade_complete

_node_version=$(node --version | grep -E -o '[0-9]+' | head -n1)

echo "${_node_version}" > "/home/pi/.webthings/.node_version"
echo "Node version in .node_version file:"
cat /home/pi/.webthings/.node_version

echo " "
echo "Linking gateway addon"
cd "/home/pi/webthings/gateway/node_modules/gateway-addon"
npm link
cd -




echo " "
echo "INSTALLING CANDLE ADDONS"
echo " "

mkdir -p /home/pi/.webthings/addons
chown -R pi:pi /home/pi/.webthings/addons


if ! [ -d /home/pi/.webthings/addons/candleappstore ] 
then
    echo "Installing addons" >> sudo tee -a /dev/kmsg
        
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
    rm -rf power-settings
    wget https://github.com/createcandle/power-settings/releases/download/3.2.37/power-settings-3.2.37.tgz
    for f in power-settings*.tgz; do
        tar -xf "$f"
    done
    mv package power-settings
    chown -R pi:pi power-settings
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

echo " "
#echo "running gateway for 15 seconds to create folders"
#cd /home/pi/webthings/gateway
#timeout 10 npm run run-only
#echo "controller installation should be complete"
#echo "ls /home/pi/.webthings:"
#ls /home/pi/.webthings

cd /home/pi
rm ./install_nvm.sh

mkdir -p /home/pi/.webthings/config
chown -R pi:pi /home/pi/.webthings/config
if ! [ -e /home/pi/.webthings/config/db.sqlite3 ] 
then
    echo "copying initial Candle database from power settings addon"
    cp /home/pi/.webthings/addons/power-settings/db.sqlite3 /home/pi/.webthings/config/db.sqlite3
    chown pi:pi /home/pi/.webthings/config/db.sqlite3
else
    echo "warning, not copying default database since a database file already exists"
fi



npm config set metrics-registry="https://"
#npm config set registry="https://"
npm config set user-agent=""
rm /home/pi/.npm/anonymous-cli-metrics.json

npm cache clean --force
nvm cache clear

echo " "
echo "sub-script that installs the Candle controller is done. Returning to the main install script."
echo "Gateway install script done" >> sudo tee -a /dev/kmsg

exit 0


