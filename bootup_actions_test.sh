#!/bin/bash

echo " " >> /dev/kmsg
echo "0. TEST START. Going to sleep..." >> /dev/kmsg
/bin/ply-image /boot/splash.png
sleep 10
echo "10" >> /dev/kmsg
/bin/ply-image /boot/splash_updating180.png
sleep 10
echo "20" >> /dev/kmsg
/bin/ply-image /boot/splash.png
sleep 10
echo "30" >> /dev/kmsg
/bin/ply-image /boot/splash_updating180.png
sleep 10
echo "40" >> /dev/kmsg
/bin/ply-image /boot/splash.png
sleep 10
echo "50" >> /dev/kmsg
/bin/ply-image /boot/splash_updating180.png
sleep 10
echo "60. TEST STOP" >> /dev/kmsg
echo " " >> /dev/kmsg
sleep 10
rm /boot/bootup_actions.sh
exit 0