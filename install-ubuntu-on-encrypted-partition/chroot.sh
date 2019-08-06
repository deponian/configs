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

# Add user
echo "Creating new user... "
read -p "Enter username: " USERNAME
useradd -m -G sudo -s /bin/bash "$USERNAME"

PASSWORD=""
while true; do
        read -s -p "Enter password: " PASSWORD_FIRST
        echo
        read -s -p "Again, please. It is important: " PASSWORD_SECOND
        echo
        PASSWORD=${PASSWORD_FIRST}
        [ "$PASSWORD_FIRST" = "$PASSWORD_SECOND" ] && break
        print_red "Passwords don't match. Please try again."
	echo -n "${BLUE}"
done
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Install and update grub
grub-install
update-grub

# Update initramfs
update-initramfs -k all -c


