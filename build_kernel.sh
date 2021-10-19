#!/bin/sh

KERNEL_BASE="5.10"
KERNEL_VER="5.10.72"
ZFS_VER="2.0.6"

BUILD_PATH="/var/tmp/portage/kernel"
CONFIG_TPL="/root/bin/config-base"
DISTFILES="/var/lib/portage/distfiles"

KERNEL_SRC_TAR="linux-$KERNEL_BASE.tar.xz"
KERNEL_PATCH="patch-$KERNEL_VER.xz"
KERNEL_SRC_URL="https://cdn.kernel.org/pub/linux/kernel/v5.x"
ZFS_SRC_TAR="zfs-$ZFS_VER.tar.gz"
ZFS_SRC_URL="https://github.com/zfsonlinux/zfs/releases/download/zfs-$ZFS_VER"

LINUX=$BUILD_PATH/linux-$KERNEL_BASE
ZFS=$BUILD_PATH/zfs-$ZFS_VER


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

	echo "Install kernel"
	make install
	make modules_install
}


mkdir $BUILD_PATH

fetch_linux

fetch_zfs
patch_zfs

make_linux

rm -r $BUILD_PATH
