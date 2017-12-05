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
RPOOL=`$CAT /proc/cmdline | $TR " " "\n" | $GREP "rpool=" | $CUT -d"=" -f2`

[[ -z $RPOOL ]] && RPOOL=`$ECHO $ROOT | $CUT -d"/" -f1`
[[ -z $RPOOL ]] && RPOOL="rpool"

$ECHO "Importing: $RPOOL"

if [[ -f /etc/$RPOOL.cache ]]
then
	$ZPOOL import -c /etc/$RPOOL.cache -N $RPOOL
else
	$ZPOOL import -N $RPOOL
fi

[[ -z $ROOT ]] && ROOT=`$ZPOOL get -H bootfs $RPOOL | $TR -s "\t" ":" | $CUT -d: -f3`

$ECHO "Mounting: $ROOT"
/sbin/mount.zfs $ROOT /newroot

#rescue shell if mount fail
[[ $? -ne 0 ]] && $BUSYBOX --install -s && $SH

#unmount pseudo FS
$UMOUNT /sys
$UMOUNT /proc
$UMOUNT /dev

#root switch
exec $SWITCH_ROOT /newroot /usr/lib/systemd/systemd
