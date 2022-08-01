#!/bin/bash

# This script should be run as user pi (not root)

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
then

  echo "HOME: $HOME"

  cd /home/pi

  python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon

  rm install.sh
  #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
  wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh
  chmod +x install.sh
  ./install.sh
  
  #. ~/.bashrc

  export NVM_DIR="/home/pi/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

  nvm install 14
  nvm use 14
  nvm alias default 14

  echo " "
  echo "NODE AND NPM VERSIONS:"
  node --version
  npm --version

  echo " "
  echo "DOWNLOADING AND INSTALLING CANDLE CONTROLLER"
  echo "Do not worry about the errors you will see with optipng and jpegtran"
  echo " "
  
  # Download Candle controller from Github and install it
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
  echo "compiling typescript.. this will take a while"
  npx tsc -p .
  echo "running webpack.. this will take a while"
  npx webpack
  
  echo " "
  echo "INSTALLING CANDLE STORE ADDON"
  echo " "

  mkdir -p /home/pi/.webthings/addons
  chown -R pi:pi /home/pi/.webthings/addons
  cd /home/pi/.webthings/addons
  rm candleappstore-0.4.17-linux-arm64-v3.9.tgz
  rm -rf package
  rm -rf candleappstore
  wget https://github.com/createcandle/candleappstore/releases/download/0.4.17/candleappstore-0.4.17-linux-arm64-v3.9.tgz
  tar -xf candleappstore-0.4.17-linux-arm64-v3.9.tgz
  mv package candleappstore
  chown -R pi:pi candleappstore
  rm candleappstore-0.4.17-linux-arm64-v3.9.tgz
  
  echo " "
  echo "running gateway for 15 seconds to create folders"
  cd /home/pi/webthings/gateway
  timeout 15 npm run run-only
  echo "controller installation should be complete"
  echo "ls /home/pi/.webthings:"
  ls /home/pi/.webthings
  exit 0
  
else
  echo "Please run as user pi"
  exit 1
fi


