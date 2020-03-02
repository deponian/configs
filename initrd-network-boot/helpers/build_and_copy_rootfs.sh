#!/usr/bin/env bash
set -euo pipefail

CHROOT=$1

if [[ "$EUID" != 0 ]]
then
	echo "Please run as root"
	exit
fi

if [[ -z "$CHROOT" ]]
then
	echo "You have to specify chroot directory."
	exit
fi

if [[ ! -d "$CHROOT" ]]
then
	echo "Directory $CHROOT doesn't exist."
	exit
fi

### Colors ###
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

### Functions ###
function superprint {
	TEXT=$1
	SIZE=${#TEXT}
	SIZE=$((SIZE + 43))
	echo "${GREEN}"
	seq -s: "$SIZE" | tr -d '[:digit:]'
	echo ":::::::::::::::::::: $TEXT ::::::::::::::::::::"
	seq -s: "$SIZE" | tr -d '[:digit:]'
	echo "${RESET}"
}

### Real work here ###
superprint "Clean up old data"
rm base.rootfs.squashfs
rm vmlinuz
rm initrd.img
rm -rf initrd

superprint "Do you want to continue building?"

ANSWER=''
read -r -p "Say (y)es or (n)o: " ANSWER

if [ "$ANSWER" != "y" ]; then
	echo "Cleaning up has finished"
	exit
fi

superprint "Copy kernel and initrd"
cp "$CHROOT"/vmlinuz vmlinuz
chmod 644 vmlinuz
cp "$CHROOT"/initrd.img initrd.img.gz

superprint "Unzip initrd"
gunzip initrd.img.gz

superprint "Extract initrd cpio archive"
mkdir initrd
(	cd initrd || exit
	cpio -iv < ../initrd.img
	cp ../initrd-for-network-boot/init .
	cp ../initrd-for-network-boot/scripts/nfs ./scripts/

	superprint "Build new initrd"
	find . | cpio --create --format='newc' | gzip > ../initrd.img
)

superprint "Build squashfs image of root"
(	cd "$CHROOT" || exit
	mksquashfs . ../base.rootfs.squashfs
)

superprint "Do you want to copy files to clab?"

ANSWER=''
read -r -p "Say (y)es or (n)o: " ANSWER

if [ "$ANSWER" != "y" ]; then
	echo "Copying canceled"
	exit
fi

TFTP='/srv/share/tftp/distr/liveos/openstack-compute'
NFS='/srv/share/nfs/openstack-compute/base.rootfs'

superprint "Copy kernel to clab"
ssh -i /home/rufus/.ssh/id_rsa root@clab rm $TFTP/vmlinuz.old
ssh -i /home/rufus/.ssh/id_rsa root@clab mv $TFTP/vmlinuz $TFTP/vmlinuz.old
scp -i /home/rufus/.ssh/id_rsa vmlinuz root@clab:$TFTP/

superprint "Copy initrd to clab"
ssh -i /home/rufus/.ssh/id_rsa root@clab rm $TFTP/initrd.img.old
ssh -i /home/rufus/.ssh/id_rsa root@clab mv $TFTP/initrd.img $TFTP/initrd.img.old
scp -i /home/rufus/.ssh/id_rsa initrd.img root@clab:$TFTP/

superprint "Copy root image to clab"
ssh -i /home/rufus/.ssh/id_rsa root@clab rm $NFS/base.rootfs.squashfs.old
ssh -i /home/rufus/.ssh/id_rsa root@clab mv $NFS/base.rootfs.squashfs $NFS/base.rootfs.squashfs.old
scp -i /home/rufus/.ssh/id_rsa base.rootfs.squashfs root@clab:$NFS/

superprint "Job has done"
