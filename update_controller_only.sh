#!/bin/bash

if ! [ "$EUID" -ne 0 ]
then
  echo "Please run as user pi (do not use sudo)"
  exit
fi

echo " "
echo "UPDATING CONTROLLER ONLY"
echo "this script:"
echo "- removes and then recreates the webthings/gateway directory from scratch"
echo "- it does NOT change the .webthings directory (database, logs, installed addons)"
echo "- it does NOT update linux or the node version"
echo " "
cd /home/pi

sudo systemctl stop webthings-gateway.service

export NVM_DIR="/home/pi/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

echo " "
echo "NODE AND NPM VERSIONS:"
node --version
npm --version

echo " "
echo "DOWNLOADING AND INSTALLING CANDLE CONTROLLER"
echo "Do not worry about the errors you will see with optipng and jpegtran"
echo " "

# Download Candle controller from Github and install it

rm -rf /home/pi/webthings

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

sudo systemctl start webthings-gateway.service

echo " "
echo "ALMOST DONE"
echo "The controller is loading, please give it an hour to stabilise, then clear your browser and reload."
echo " "
