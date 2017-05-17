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

#mount pseudo FS
$MOUNT -t proc none /proc
$MOUNT -t sysfs none /sys
$MOUNT -t devtmpfs none /dev

#crashdump
$GREP "kdump" /proc/cmdline >/dev/null
if [[ $? -eq 0 ]] 
then
	$BUSYBOX --install -s && $SH
	$UMOUNT /sys
	$UMOUNT /proc
	$UMOUNT /dev
	exit
fi

#zfs
ROOT=`$CAT /proc/cmdline | $TR " " "\n" | $GREP "root=" | $CUT -d"=" -f2`
if [[ -z $ROOT ]]
then
	RPOOL=rpool
	$ZPOOL import -N $RPOOL
	ROOT=`$ZPOOL get -H bootfs $RPOOL | $TR -s "\t" ":" | $CUT -d: -f3`
else
	RPOOL=`$ECHO $ROOT | $CUT -d"/" -f1`
	$ZPOOL import -N $RPOOL
fi

/sbin/mount.zfs $ROOT /newroot

#rescue shell if mount fail
[[ $? -ne 0 ]] && $BUSYBOX --install -s && $SH

#unmount pseudo FS
$UMOUNT /sys
$UMOUNT /proc
$UMOUNT /dev

#root switch
exec $SWITCH_ROOT /newroot /sbin/init 3
