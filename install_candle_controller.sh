#!/bin/bash
set +e

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
  echo "Compiling typescript. this will take a while..."
  npx tsc -p .
  echo "(it probably found some errors, don't worry about those)"
  echo " "
  echo "Running webpack. this will take a while too..."
  NODE_OPTIONS="--max-old-space-size=496" npx webpack
  
  echo " "
  echo "INSTALLING CANDLE STORE ADDON"
  echo " "

  mkdir -p /home/pi/.webthings/addons
  chown -R pi:pi /home/pi/.webthings/addons
  cd /home/pi/.webthings/addons
  rm candleappstore-0.4.18-linux-arm-v3.9.tgz
  rm -rf package
  rm -rf candleappstore
  wget https://github.com/createcandle/candleappstore/releases/download/0.4.18/candleappstore-0.4.18-linux-arm-v3.9.tgz
  tar -xf candleappstore-0.4.18-linux-arm-v3.9.tgz
  mv package candleappstore
  chown -R pi:pi candleappstore
  rm candleappstore-0.4.18-linux-arm-v3.9.tgz
  
  rm -rf package
  rm -rf candle-theme
  wget https://github.com/createcandle/candle-theme/releases/download/2.5.0/candle-theme-2.5.0.tgz
  tar -xf candle-theme-2.5.0.tgz
  mv package candle-theme
  chown -R pi:pi candle-theme
  rm candle-theme-2.5.0.tgz
  
  rm -rf package
  rm -rf power-settings
  wget https://github.com/createcandle/power-settings/releases/download/3.2.18/power-settings-3.2.18.tgz
  tar -xf power-settings-3.2.18.tgz
  mv package power-settings
  chown -R pi:pi power-settings
  rm power-settings-3.2.18.tgz
  
  rm -rf package
  rm -rf tutorial
  wget https://github.com/createcandle/tutorial/releases/download/1.0.7/tutorial-1.0.7.tgz
  tar -xf tutorial-1.0.7.tgz
  mv package tutorial
  chown -R pi:pi tutorial
  rm tutorial-1.0.7.tgz
  
  rm -rf package
  rm -rf bluetoothpairing
  wget https://github.com/createcandle/bluetoothpairing/releases/download/0.5.8/bluetoothpairing-0.5.8.tgz
  tar -xf bluetoothpairing-0.5.8.tgz
  mv package bluetoothpairing
  chown -R pi:pi bluetoothpairing
  rm bluetoothpairing-0.5.8.tgz
  
  rm -rf package
  rm -rf photo-frame
  wget https://github.com/flatsiedatsie/photo-frame/releases/download/1.4.16/photo-frame-1.4.16.tgz
  tar -xf photo-frame-1.4.16.tgz
  mv package photo-frame
  chown -R pi:pi photo-frame
  rm photo-frame-1.4.16.tgz
  
  rm -rf package
  rm -rf followers
  wget https://github.com/flatsiedatsie/followers-addon/releases/download/0.6.8/followers-0.6.8.tgz
  tar -xf followers-0.6.8.tgz
  mv package followers
  chown -R pi:pi followers
  rm followers-0.6.8.tgz
  
  rm -rf package
  rm -rf internet-radio
  wget https://github.com/flatsiedatsie/internet-radio/releases/download/2.1.31/internet-radio-2.1.31.tgz
  tar -xf internet-radio-2.1.31.tgz
  mv package internet-radio
  chown -R pi:pi internet-radio
  rm internet-radio-2.1.31.tgz
  
  rm -rf package
  rm -rf zigbee2mqtt-adapter
  wget https://github.com/kabbi/zigbee2mqtt-adapter/releases/download/1.1.2/zigbee2mqtt-adapter-1.1.2.tgz
  tar -xf zigbee2mqtt-adapter-1.1.2.tgz
  mv package zigbee2mqtt-adapter
  chown -R pi:pi zigbee2mqtt-adapter
  rm zigbee2mqtt-adapter-1.1.2.tgz
  
  rm -rf package
  rm -rf privacy-manager
  wget https://github.com/createcandle/privacy-manager/releases/download/0.2.8/privacy-manager-0.2.8.tgz
  tar -xf privacy-manager-0.2.8.tgz
  mv package privacy-manager
  chown -R pi:pi privacy-manager
  rm privacy-manager-0.2.8.tgz
  
  rm -rf package
  rm -rf webinterface
  wget https://github.com/createcandle/webinterface/releases/download/0.2.2/webinterface-0.2.2.tgz
  tar -xf webinterface-0.2.2.tgz
  mv package webinterface
  chown -R pi:pi webinterface
  rm webinterface-0.2.2.tgz
  
  echo " "
  #echo "running gateway for 15 seconds to create folders"
  #cd /home/pi/webthings/gateway
  #timeout 15 npm run run-only
  #echo "controller installation should be complete"
  echo "ls /home/pi/.webthings:"
  ls /home/pi/.webthings
  
  mkdir -p /home/pi/.webthings/config
  cp /home/pi/.webthings/addons/power-settings/db.sqlite3 /home/pi/.webthings/config/db.sqlite3
  chown pi:pi /home/pi/.webthings/config/db.sqlite3
  
else
  echo "Please run as user pi"
  exit 1
fi


