#!/bin/bash

echo ""
echo "Installing QEMU"
sudo apt update && sudo apt install -y sshpass qemu-kvm qemu-system-aarch64 qemu-utils ipxe-qemu libvirt-daemon-system -y --no-install-recommends

if [ ! -f "raspios-arm64-lite.img.xz" ]; then
	echo "Attempting download of Raspberry Pi OS image"
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-04-14/2026-04-13-raspios-trixie-arm64-lite.img.xz -O raspios-arm64-lite.img.xz
fi

if [ ! -f "raspios-arm64-lite.img.xz" ]; then
	echo "Raspberry Pi OS image failed to download"
	exit 1
fi

if [ -f "raspios-arm64-lite.img" ]; then
	echo "Deleting old extracted Raspberry Pi OS image"
	rm raspios-arm64-lite.img
fi

if [ ! -f raspios-arm64-lite.img ]; then
	echo ""
	echo "Extracting fresh disk image"
	xz -d -k raspios-arm64-lite.img.xz

	if [ ! -f "raspios-arm64-lite.img" ]; then
		echo "could not find raspios-arm64-lite.img"
		ls *.img
		exit 1
	fi

	echo ""
	echo "Resizing disk image 4GB -> 30GB"
	qemu-img resize raspios-arm64-lite.img +26G
fi

#START_SECTOR=8192
START_SECTOR=16384
fdisk -l raspios-arm64-lite.img

START_SECTOR=$(fdisk -l raspios-arm64-lite.img | grep ^raspios-arm64-lite.img1 |  awk -F" "  '{ print $2 }')
echo "START_SECTOR: $START_SECTOR"

# ENABLE SSH ACCESS
echo ""
echo "Enabling SSH access"
mkdir -p ~/pi-boot  
sudo mount -o loop,offset=$((START_SECTOR * 512)) raspios-arm64-lite.img ~/pi-boot
#sed '/resize/d' ./infile
if [ ! -f ~/pi-boot/cmdline.txt ]; then
	echo "cmdline.txt not found"
	exit 1
fi
echo ""
echo "ls /pi-boot:"
ls ~/pi-boot

echo ""
#echo "user-data before: "
#cat ~/pi-boot/user-data








sudo bash -c 'cat <<EOF > /home/pi/pi-boot/user-data
#cloud-config
manage_resolv_conf: false
hostname: candle
manage_etc_hosts: true
packages:
- avahi-daemon
apt:
  preserve_sources_list: true
  conf: |
    Acquire {
      Check-Date "false";
    };
timezone: Europe/Amsterdam
keyboard:
  model: pc105
  layout: "us"
users:
- name: pi
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  passwd: "$y$jB5$r32Rk.3J9J5CLZb9Mx4AW/$KlC8SoXaYwefPo.5odyVnJmAcPwjn0QTepW5rmDVbB."
  ssh_authorized_keys:
    - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDB4Wy7eSGzd/XFdun4U5ez2THJPh+TC4oNvSuJHNuXnMcxcHmXWNuwjqinRBk53nj304sKp7DEZ+OsDYSp9NUj3sAVFMAmmFI1hxu5hoMv1M2Tx/d8l7Ythsu4msBxK4TfGkCl4w+WYz4zDg/GwUVHp79/e2xHHbj44nCYO2IUqrosC1fb+c4lux/xuN044fUvkZfcYPc/qClo1UsX+QzkE/R7dn9Wautyb1/BHLo74UZ3kSF0rinENRfohffwDooKgjKB+ygb9w1dBfMj3r2XuJXwmfw4Y8nu4T8Bu6zUsMk6gfOCqF6gv8tJKAsSbiXvPHCQ7VGh8SM2Uu0rn4J9 email
  sudo: ALL=(ALL) NOPASSWD:ALL
enable_ssh: true
ssh_pwauth: false
rpi:
  interfaces:
    serial: true
runcmd:
  - [ rfkill, unblock, wifi ]
  - [ sh, -c, "for f in /var/lib/systemd/rfkill/*:wlan; do echo 0 > \"$f\"; done" ]

EOF'

echo ""
echo "user-data AFTER: "
cat ~/pi-boot/user-data
echo ""

echo ""
echo "---cmdline.txt BEFORE ---"
cat ~/pi-boot/cmdline.txt
echo "-------------------------"

sudo sed -i 's/resize//' ~/pi-boot/cmdline.txt
echo ""
echo "---cmdline.txt AFTER ---"
cat ~/pi-boot/cmdline.txt
echo "------------------------"
echo ""
sudo touch ~/pi-boot/ssh 
HASH=$(echo 'smarthome' | openssl passwd -6 -stdin)
echo "pi:$HASH" | sudo tee ~/pi-boot/userconf.txt
echo "Unmounting boot partition"
sudo umount ~/pi-boot 


# qemu-system-arm
# qemu-system-arm64
# qemu-system-aarch64


echo ""
echo "KVM enabled? should be 0"
grep -c '^flags.*kvm' /proc/cpuinfo
echo ""

sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER

# https://www.codestudy.net/blog/emulating-raspberry-pi-4-with-qemu/

echo ""
echo "Starting QEMU"
sudo qemu-system-aarch64 -kernel /boot/firmware/kernel8.img \
 -dtb /boot/firmware/bcm2712-rpi-5-b.dtb \
 -machine virt \
 -cpu cortex-a72 \
 -smp 4 \
 -m 2G \
 -drive file=raspios-arm64-lite.img,format=raw \
 -append "root=/dev/vda2 rw console=ttyAMA0,115200 rootwait" \
 -serial stdio \
 -net nic \
 -net user,hostfwd=tcp::5022-:22 &

# --events on_reboot reboot
# --events on_reboot destroy
# -netdev user,id=net0,hostfwd=tcp::5022-:22 \
# -device virtio-net-device,netdev=net0 &
 
echo ""
echo "QEMU started"
#-net nic \
#-net user,hostfwd=tcp::5022-:22 \
# -machine raspi4 

echo ""
echo "LOGGING IN 1"

sleep 5
sshpass -p 'yourpassword' ssh pi@localhost -p 5022 StrictHostKeyChecking=no 'uname -a'



echo ""
echo "LOGGING IN 2"
# PreferredAuthentications=password
#sshpass -p 'yourpassword' ssh pi@localhost -p 5022 StrictHostKeyChecking=no 'bash -s' < once_inside.sh
sleep 5
sshpass -p 'yourpassword' ssh pi@localhost -p 5022 StrictHostKeyChecking=no 'uname -a'


echo ""
echo "LOGGING IN 3"
sleep 3
sshpass -p 'yourpassword' ssh pi@localhost -p 5022 StrictHostKeyChecking=no 'bash -s ' <<EOF
echo ""
echo "OK"
echo ""
echo "INSIDE START"
echo ""
cat /proc/cpuinfo | grep "model name"
uname -a
echo ""
echo "ip addr:"
ip addr
echo ""
echo ""
echo "Downloading create_latest_candle script"
curl -H 'Cache-Control: no-cache' -sSl https://raw.githubusercontent.com/createcandle/install-scripts/main/create_latest_candle_dev.sh -o create_latest_candle_dev.sh; sudo chmod +x create_latest_candle_dev.sh; sudo CUTTING_EDGE=yes CREATE_DISK_IMAGE=yes bash ./create_latest_candle_dev.sh
echo ""
echo "INSIDE DONE"
echo ""
exit
EOF

echo ""
echo "BACK OUTSIDE"
echo ""

#sudo dhclient eth0

sleep 5

sudo pkill -f qemu-system-aarch64

echo "END"
echo ""
