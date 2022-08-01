#!/bin/bash

# This script should be run as user pi (not root)

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
then

  echo "HOME: $HOME"

  cd /home/pi

  python3 -m pip install git+https://github.com/WebThingsIO/gateway-addon-python#egg=gateway_addon

  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
  #. ~/.bashrc

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

  echo " "
  echo "NODE AND NPM VERSIONS:"
  node --version
  npm --version

  echo " "
  echo "DOWNLOADING AND INSTALLING CANDLE CONTROLLER"
  
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
  
  npm install -D webpack-cli
  
  rm -rf build
  cp -rL src build
  cp -rL static build/static
  find build -name '*.ts' -delete
  npx tsc -p .
  npx webpack
  
  echo " "
  echo "INSTALLING CANDLE STORE ADDON"
  echo " "

  mkdir -p /home/pi/.webthings/addons
  cd /home/pi/.webthings/addons
  rm candleappstore-0.4.17-linux-arm64-v3.9.tgz
  rm -rf package
  rm -rf candleappstore
  wget https://github.com/createcandle/candleappstore/releases/download/0.4.17/candleappstore-0.4.17-linux-arm64-v3.9.tgz
  tar -xf candleappstore-0.4.17-linux-arm64-v3.9.tgz
  mv package candleappstore
  chown pi:pi candleappstore
  rm candleappstore-0.4.17-linux-arm64-v3.9.tgz
  
  cd /home/pi/webthings/gateway
  timeout 5 npm run run-only
  
else
  echo "Please do not run as root"
  exit
fi


