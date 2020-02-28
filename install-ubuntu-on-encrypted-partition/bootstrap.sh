#!/usr/bin/env bash
set -euo pipefail

# Settings
OS_DEVICE="nvme0n1"
EFI_PARTITION="nvme0n1p1"
BOOT_PARTITION="nvme0n1p2"
ROOT_PARTITION="nvme0n1p3"
DATA_DEVICE="sda"
DATA_PARTITION="sda1"
MINIMAL_DATA_DEVICE_SIZE="3886057648" # number of sectors (something about 1.8 TiB)

# Functions
# Color print
function cprint {
	case "${1}" in
		red   ) echo "$(tput setaf 1)${2}$(tput sgr0)";;
		green ) echo "$(tput setaf 2)${2}$(tput sgr0)";;
		blue  ) echo "$(tput setaf 4)${2}$(tput sgr0)";;
	esac
}

# Color set
function cset {
	case "${1}" in
		red   ) echo -n "$(tput setaf 1)";;
		green ) echo -n "$(tput setaf 2)";;
		blue  ) echo -n "$(tput setaf 4)";;
	reset ) echo -n "$(tput sgr0)";;
	esac
}

# Check if run as root or not

if [[ "${EUID}" -ne 0 ]]
then
	echo "Please run as root"
	exit
fi

# Start of the script

USER=""
while true; do
	read -r -p "Enter name that you use in our organization: " USERNAME
	if [[ -z "${USERNAME}" ]]; then
		cprint red "Your username is empty."
		cprint red "Do you think you are nothing?"
		cprint red "Do you think people don't like you?"
		cprint red "Do you think you are unnecessary or unwanted?"
		cprint red "I know that feeling, bro."
		cprint red "But you have to type at least something."
		cprint red "I can help you. Use username 'nothing' or 'emptiness'."
		cprint red "I know you can do it. Just believe in yourself."
		continue
	fi
	USER="${USERNAME}"
	break
done

echo "Let's do it"

echo -n "Checking /dev/${DATA_DEVICE} size... "
DATA_DEVICE_SIZE=$(sgdisk --print /dev/"${DATA_DEVICE}" | head -1 | cut -d" " -f 3)
if (( DATA_DEVICE_SIZE < MINIMAL_DATA_DEVICE_SIZE )); then
	echo -n "You are trying to erase wrong /dev/sda disk... "
	echo -n "Bye."
	exit 1
fi

echo -n "Erasing /dev/${DATA_DEVICE}... "
sgdisk --clear --mbrtogpt /dev/"${DATA_DEVICE}" > /dev/null
cprint green "done"

echo -n "Creating partition on /dev/${DATA_DEVICE}... "
sgdisk --new 1:2048:3906029134 /dev/"${DATA_DEVICE}" > /dev/null
cprint green "done"

echo -n "Erasing /dev/${OS_DEVICE}... "
sgdisk --clear --mbrtogpt /dev/"${OS_DEVICE}" > /dev/null
cprint green "done"

echo -n "Creating partitions on /dev/${OS_DEVICE}... "
sgdisk --new 1:2048:2099199 /dev/"${OS_DEVICE}" > /dev/null
sgdisk --new 2:2099200:3147775 /dev/"${OS_DEVICE}" > /dev/null
sgdisk --new 3:3147776:976773134 /dev/"${OS_DEVICE}" > /dev/null
cprint green "done"

# Change type for ESP
sgdisk --typecode 1:EF00 /dev/"${OS_DEVICE}" > /dev/null

# Create encrypted partition on "$ROOT_PARTITION"
PASSWORD=""
while true; do
	read -r -s -p "Enter the password your disk will be encrypted with: " PASSWORD_FIRST
	echo
	read -r -s -p "Again, please. It is important: " PASSWORD_SECOND
	echo
	PASSWORD=${PASSWORD_FIRST}

	# Check first and second attempts match
	if [[ "${PASSWORD_FIRST}" != "${PASSWORD_SECOND}" ]]; then
		cprint red "Passwords don't match. Please try again."
		continue
	fi

	# Check password strength
	CRACKLIB_RESULT="$(cracklib-check <<<"${PASSWORD}")"
	OK="$(awk -F': ' '{ print $2 }' <<<"${CRACKLIB_RESULT}")"
	if [[ "${OK}" == "OK" ]]; then
		cprint green "This is a good password, man!"
	else
		cprint red "Your password is weak like a baby. Add more POWER!!!1111"
		continue
	fi
	break
done

# Generate keyfile
dd if=/dev/random of=/media/ubuntu/main/"${USER}".key bs=32 count=1 2> /dev/null

echo -n "Creating encrypted partition on /dev/${ROOT_PARTITION}... "
echo "${PASSWORD}" | cryptsetup luksFormat /dev/"${ROOT_PARTITION}"
echo "${PASSWORD}" | cryptsetup luksOpen /dev/"${ROOT_PARTITION}" "${ROOT_PARTITION}"_crypt
echo "${PASSWORD}" | cryptsetup luksAddKey /dev/"${ROOT_PARTITION}" /media/ubuntu/main/"${USER}".key
cprint green "done"

echo -n "Creating encrypted partition on /dev/${DATA_PARTITION}... "
echo "${PASSWORD}" | cryptsetup luksFormat /dev/"${DATA_PARTITION}"
echo "${PASSWORD}" | cryptsetup luksOpen /dev/"${DATA_PARTITION}" "${DATA_PARTITION}"_crypt
echo "${PASSWORD}" | cryptsetup luksAddKey /dev/"${DATA_PARTITION}" /media/ubuntu/main/"${USER}".key
cprint green "done"

# Create filesystems on partitions
echo -n "Creating ext4 on HDD (/dev/mapper/${DATA_PARTITION}_crypt)... "
mkfs.ext4 -q -m 0.5 /dev/mapper/"${DATA_PARTITION}"_crypt
cprint green "done"

echo -n "Creating fat on efi partition (/dev/${EFI_PARTITION})... "
mkfs.vfat /dev/"${EFI_PARTITION}" > /dev/null
cprint green "done"

echo -n "Creating ext2 on boot partition (/dev/${BOOT_PARTITION})... "
yes | mkfs.ext2 -q /dev/"${BOOT_PARTITION}"
cprint green "done"

echo -n "Creating ext4 on root partition (/dev/mapper/${ROOT_PARTITION}_crypt)... "
mkfs.ext4 -q /dev/mapper/"${ROOT_PARTITION}"_crypt
cprint green "done"

echo -n "Unpacking of root... "
mount /dev/mapper/"${ROOT_PARTITION}"_crypt /mnt
tar -xf root.tar.gz -C /mnt .
cprint green "done"

echo -n "Unpacking of boot... "
mount /dev/"${BOOT_PARTITION}" /mnt/boot
tar -xf boot.tar.gz -C /mnt/boot .
cprint green "done"

echo -n "Unpacking of efi... "
mount /dev/"${EFI_PARTITION}" /mnt/boot/efi
tar -xf efi.tar.gz -C /mnt/boot/efi .
cprint green "done"

echo -n "Mounting of HDD... "
mount /dev/mapper/"${DATA_PARTITION}"_crypt /mnt/mnt/data
cprint green "done"

echo -n "Removing old swapfile... "
if [[ -f /mnt/swapfile ]]; then
	rm /mnt/swapfile
fi
cprint green "done"

echo -n "Replacing mount points for root and data... "
sed --in-place "s|${ROOT_PARTITION}|mapper/${ROOT_PARTITION}_crypt|g" /mnt/etc/fstab
sed --in-place "s|${DATA_PARTITION}|mapper/${DATA_PARTITION}_crypt|g" /mnt/etc/fstab
cprint green "done"

echo -n "Adding crypttab entries for root and data... "
echo "" > /mnt/etc/crypttab
echo "${ROOT_PARTITION}_crypt /dev/${ROOT_PARTITION} none luks" >> /mnt/etc/crypttab
echo "${DATA_PARTITION}_crypt /dev/${DATA_PARTITION} none luks" >> /mnt/etc/crypttab
cprint green "done"

# Mount proc, sys and dev for chroot
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /dev /mnt/dev
mount --bind /dev/pts /mnt/dev/pts

echo "Entering in chroot..."

# Copy chroot script to new root
cp chroot.sh /mnt

# Chroot to new root
chroot /mnt ./chroot.sh

# Delete chroot script from new root
rm /mnt/chroot.sh

echo -n "Umounting all partitions... "
umount --recursive /mnt
cprint green "done"

echo -n "Closing encrypted partitions... "
cryptsetup luksClose "${DATA_PARTITION}"_crypt
cryptsetup luksClose "${ROOT_PARTITION}"_crypt
cprint green "done"

cprint green "Installation has finished"

