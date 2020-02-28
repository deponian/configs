#!/usr/bin/env bash
set -euo pipefail

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

# Start of the script

echo -n "Deleting old user... "
userdel geralt
rm -rf /home/geralt
cprint green "done"

# Add user
echo "Creating new user... "
while true; do
	read -r -p "Enter username: " USERNAME
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
	useradd -m -G sudo -s /bin/bash "${USERNAME}" && break
	cprint red "System doesn't accept you. Obey the system."
done

# Get password
PASSWORD=""
while true; do
	read -r -s -p "Enter password: " PASSWORD_FIRST
	echo
	read -r -s -p "Again, please. It is important: " PASSWORD_SECOND
	echo
	PASSWORD=${PASSWORD_FIRST}

	# Check first and second attempts match
	if [[ "${PASSWORD_FIRST}" != "${PASSWORD_SECOND}" ]]; then
		cprint red "Passwords don't match. Please try again."
		continue
	fi

	# Check if password is empty
	if [[ -z "${PASSWORD}" ]]; then
	cprint red "Password is empty. We trust to each other but not so much."
	continue
	fi
	break
done

echo "${USERNAME}:${PASSWORD}" | chpasswd

cprint green "User is created."

# Install and update grub
grub-install
update-grub

# Update initramfs
update-initramfs -k all -c


