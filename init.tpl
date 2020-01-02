#!/bin/busybox sh

ZPOOL="/sbin/zpool"
BUSYBOX="/bin/busybox"
CAT="$BUSYBOX cat"
CUT="$BUSYBOX cut"
GREP="$BUSYBOX grep"
TR="$BUSYBOX tr"
ECHO="$BUSYBOX echo"
MOUNT="$BUSYBOX mount"
UMOUNT="$BUSYBOX umount"
SH="$BUSYBOX sh"
SWITCH_ROOT="$BUSYBOX switch_root"
MKDIR="$BUSYBOX mkdir"

# mount pseudo FS
$MOUNT -t proc none /proc
$MOUNT -t sysfs none /sys
$MOUNT -t devtmpfs none /dev
$MKDIR /dev/pts
$MOUNT -t devpts /dev/pts /dev/pts

# crashdump
$GREP "kdump" /proc/cmdline >/dev/null
if [[ $? -eq 0 ]] 
then
	$BUSYBOX --install -s && $SH
	$UMOUNT /sys
	$UMOUNT /proc
	$UMOUNT /dev
	exit
fi

# plymouth
$GREP "splash" /proc/cmdline >/dev/null
if [[ $? -eq 0 -a -x /usr/sbin/plymouthd -a -x /usr/bin/plymouth ]]
then
	PLYMOUTH=1
	$MKDIR -p /run/plymouth
	/usr/sbin/plymouthd --attach-to-session --pid-file /run/plymouth/pid --mode=boot
	/usr/bin/plymouth show-splash
fi

# zfs
ROOT=`$CAT /proc/cmdline | $TR " " "\n" | $GREP "root=" | $CUT -d"=" -f2`
RPOOL=`$CAT /proc/cmdline | $TR " " "\n" | $GREP "rpool=" | $CUT -d"=" -f2`

[[ -z $RPOOL ]] && RPOOL=`$ECHO $ROOT | $CUT -d"/" -f1`
[[ -z $RPOOL ]] && RPOOL="rpool"

[[ $PLYMOUTH == 1 ]] || $ECHO "Importing: $RPOOL"

if [[ -f /etc/$RPOOL.cache ]]
then
	$ZPOOL import -c /etc/$RPOOL.cache -N $RPOOL
else
	$ZPOOL import -N $RPOOL
fi

[[ -z $ROOT ]] && ROOT=`$ZPOOL get -H bootfs $RPOOL | $TR -s "\t" ":" | $CUT -d: -f3`

[[ $PLYMOUTH == 1 ]] || $ECHO "Mounting: $ROOT"
/sbin/mount.zfs $ROOT /newroot

# rescue shell if mount fail
[[ $? -ne 0 ]] && $BUSYBOX --install -s && $SH

# plymouth newroot
[[ $PLYMOUTH == 1 ]] && /usr/bin/plymouth --newroot=/newroot

# unmount pseudo FS
$UMOUNT /sys
$UMOUNT /proc

# root switch
exec $SWITCH_ROOT /newroot /usr/lib/systemd/systemd
