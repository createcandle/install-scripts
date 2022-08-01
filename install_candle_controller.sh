#!/bin/bash

# This script should be run as user pi (not root)

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  
    echo "HOME: $HOME"
  
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
  mkdir /home/pi/webthings
  chown pi:pi /home/pi/webthings
  cd /home/pi/webthings
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
  
else
  then echo "Please do not run as root"
  exit
fi


