#!/bin/sh

KERNEL_BASE="6.1"
#KERNEL_VER="6.1.2"
KERNEL_VER=`curl https://cdn.kernel.org/pub/linux/kernel/v6.x/ 2>/dev/null | grep 'patch-6.1.[0-9]' | sed 's/.*\(6.1.[0-9]\+\).*/\1/' | tail -1`
ZFS_VER="2.1.9"

BUILD_PATH="/var/tmp/portage/kernel"
CONFIG_TPL="/root/bin/config-base"
DISTFILES="/var/lib/portage/distfiles"

KERNEL_SRC_TAR="linux-$KERNEL_BASE.tar.xz"
KERNEL_PATCH="patch-$KERNEL_VER.xz"
KERNEL_SRC_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x"
ZFS_SRC_TAR="zfs-$ZFS_VER.tar.gz"
ZFS_SRC_URL="https://github.com/openzfs/zfs/releases/download/zfs-$ZFS_VER"

LINUX=$BUILD_PATH/linux-$KERNEL_BASE
ZFS=$BUILD_PATH/zfs-$ZFS_VER

BASE_INITRAMFS=/boot/initramfs
INITRAMFS=/boot/initramfs-${KERNEL_VER}

download() {
	[ -f $DISTFILES/$2 ] || wget $1/$2 -O $DISTFILES/$2

	cp $DISTFILES/$2 $BUILD_PATH
}

fetch_linux() {
	echo "Fetch Linux"
	cd $BUILD_PATH
	download $KERNEL_SRC_URL $KERNEL_SRC_TAR
	download $KERNEL_SRC_URL $KERNEL_PATCH

	echo "Unpack Linux"
	tar -xf $KERNEL_SRC_TAR || exit 1

	echo "Patch Linux"
	cd $LINUX
	xzcat $BUILD_PATH/$KERNEL_PATCH | patch -p1

	echo "Prepare Linux"
	cd $LINUX
	cp $CONFIG_TPL .config
	make olddefconfig
	make prepare
}

fetch_zfs() {
	echo "Fetch ZFS"
	cd $BUILD_PATH
	download $ZFS_SRC_URL $ZFS_SRC_TAR
	echo "Unpack ZFS"
	tar -xf $ZFS_SRC_TAR || exit 1
}

patch_zfs() {
	echo "Patch ZFS"
	cd $ZFS
	./autogen.sh
	./configure --with-linux=$LINUX --with-linux-obj=$LINUX --enable-linux-builtin
	./copy-builtin $LINUX
}

make_linux() {
	echo "Build kernel"
	cd $LINUX
	cp $CONFIG_TPL .config
	make olddefconfig || exit 1
	make -j4 || exit 1

	echo "Install modules"
	make modules_install

	echo "Install kernel"
	cp -f System.map /boot/System.map-$KERNEL_VER
	cp -f arch/x86/boot/bzImage /boot/vmlinuz-$KERNEL_VER
}


mkdir $BUILD_PATH
echo "Created building path in $BUILD_PATH"

fetch_linux

fetch_zfs
patch_zfs

make_linux

# link initramfs
[ -f $INITRAMFS ] || ln $BASE_INITRAMFS $INITRAMFS

rm -r $BUILD_PATH
