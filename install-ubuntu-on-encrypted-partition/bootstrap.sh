#!/bin/bash

# Colors
RED=`tput setaf 1`
GREEN=`tput setaf 2`
BLUE=`tput setaf 4`
RESET=`tput sgr0`

# Functions
function print_green {
	echo -n "${GREEN}"
	echo "$1"
	echo -n "${RESET}"
}

function print_red {
	echo -n "${RED}"
	echo "$1"
	echo -n "${RESET}"
}

# Start of the script
echo "Let's do it"

echo -n "Erasing /dev/sda... "
sgdisk --clear /dev/sda > /dev/null
print_green "done"

echo -n "Creating partition on /dev/sda... "
sgdisk --new 1:2048:3906029134 /dev/sda > /dev/null
print_green "done"

echo -n "Erasing /dev/nvme0n1... "
sgdisk --clear /dev/nvme0n1 > /dev/null
print_green "done"

echo -n "Creating partitions on /dev/nvme0n1... "
sgdisk --new 1:2048:2099199 /dev/nvme0n1 > /dev/null
sgdisk --new 2:2099200:3147775 /dev/nvme0n1 > /dev/null
sgdisk --new 3:3147776:976773134 /dev/nvme0n1 > /dev/null
print_green "done"

# Change type for ESP
sgdisk --typecode 1:EF00 /dev/nvme0n1 > /dev/null

# Create encrypted partition on nvme0n1p3
PASSWORD=""
while true; do
	read -s -p "Enter the password your disk will be encrypted with: " PASSWORD_FIRST
	echo
	read -s -p "Again, please. It is important: " PASSWORD_SECOND
	echo
	PASSWORD=${PASSWORD_FIRST}
	[ "$PASSWORD_FIRST" = "$PASSWORD_SECOND" ] && break
	print_red "Passwords don't match. Please try again."
done
print_green "Password has accepted."
echo -n "Creating encrypted partition on /dev/nvme0n1p3... "
echo "$PASSWORD" | cryptsetup luksFormat /dev/nvme0n1p3
echo "$PASSWORD" | cryptsetup luksOpen /dev/nvme0n1p3 nvme0n1p3_crypt
print_green "done"
echo -n "Creating encrypted partition on /dev/sda1... "
echo "$PASSWORD" | cryptsetup luksFormat /dev/sda1
echo "$PASSWORD" | cryptsetup luksOpen /dev/sda1 sda1_crypt
print_green "done"

# Create filesystems on partitions
echo -n "Creating ext4 on HDD (/dev/mapper/sda1_crypt)... "
mkfs.ext4 -q -m 0.5 /dev/mapper/sda1_crypt
print_green "done"

echo -n "Creating fat on efi partition (/dev/nvme0n1p1)... "
mkfs.vfat /dev/nvme0n1p1 > /dev/null
print_green "done"

echo -n "Creating ext2 on boot partition (/dev/nvme0n1p2)... "
yes | mkfs.ext2 -q /dev/nvme0n1p2
print_green "done"

echo -n "Creating ext4 on root partition (/dev/mapper/nvme0n1p3_crypt)... "
mkfs.ext4 -q /dev/mapper/nvme0n1p3_crypt
print_green "done"

echo -n "Unpacking of root... "
mount /dev/mapper/nvme0n1p3_crypt /mnt
tar -xf /media/ubuntu/main/root.tar.gz -C /mnt .
print_green "done"

echo -n "Unpacking of boot... "
mount /dev/nvme0n1p2 /mnt/boot
tar -xf /media/ubuntu/main/boot.tar.gz -C /mnt/boot .
print_green "done"

echo -n "Unpacking of efi... "
mount /dev/nvme0n1p1 /mnt/boot/efi
tar -xf /media/ubuntu/main/efi.tar.gz -C /mnt/boot/efi .
print_green "done"

echo -n "Mounting of HDD... "
mount /dev/mapper/sda1_crypt /mnt/mnt/data
print_green "done"

# Mount proc, sys and dev for chroot
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /dev /mnt/dev
mount --bind /dev/pts /mnt/dev/pts

echo "Entering in chroot..."
echo -n "${BLUE}"

# Copy chroot script to new root
cp chroot.sh /mnt

# Chroot to new root
chroot /mnt ./chroot.sh

echo -n "${RESET}"

# Delete chroot script from new root
rm /mnt/chroot.sh

echo -n "Umounting all partitions... "
umount --recursive /mnt
print_green "done"

echo -n "Closing encrypted partitions... "
cryptsetup luksClose sda1_crypt
cryptsetup luksClose nvme0n1p3_crypt
print_green "done"

print_green "Installation has finished"

