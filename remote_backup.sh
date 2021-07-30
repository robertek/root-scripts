#!/bin/sh

################################################################################
# example usage:
#
# REMOTE_IP="1.2.3.4"
# NETDEV="enp0s31f6"
# PORT=8022
#
# . /path/to/remote_backup.sh
#
# SNAP_NAME="backup-done"
# REMOTE_DATASET="wpool/BACKUP/home"
# LOCAL_DATASET="rpool/HOME"
# sync_dataset
# 
# REMOTE_RDATASET="wpool/BACKUP/notebook_root"
# sync_root
################################################################################

ZFS="/sbin/zfs"
BEADM="/root/bin/beadm"

if [ -z $PORT ]
then
	SSH="/usr/bin/ssh"
else
	SSH="/usr/bin/ssh -p $PORT"
fi

TIMEOUT="120"
REMOTE_HOST="root@$REMOTE_IP"
ZFSR="$SSH $REMOTE_HOST $ZFS"
SNAP_NAME="backup-done"

function check_host {
	ping -c1 $REMOTE_IP -I $NETDEV || exit 1
}

function sync_dataset {
	check_host

	LAST_BACKUP="$LOCAL_DATASET@$SNAP_NAME"
	NEW_BACKUP_SNAP="backup-`date +%Y%m%d_%H%M`"
	NEW_BACKUP="$LOCAL_DATASET@$NEW_BACKUP_SNAP"

	# check if exists last backup
	$ZFS get all $LAST_BACKUP >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		SEND_PARAM="-i $LAST_BACKUP $NEW_BACKUP"
	else
		SEND_PARAM="$NEW_BACKUP"
	fi

	#return

	# create new snapshot
	$ZFS snapshot $NEW_BACKUP || exit 1

	# send new snapshot
	$ZFS send $SEND_PARAM | $ZFSR receive -Feuv $REMOTE_DATASET

	# check if done
	$ZFSR list -t snapshot | grep $NEW_BACKUP_SNAP >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		$ZFS destroy $LAST_BACKUP
		$ZFS rename $NEW_BACKUP $LAST_BACKUP
	else
		$ZFS destroy $NEW_BACKUP
	fi
}

function sync_root {
	check_host

	RDATASET=`$BEADM list -a | perl -ne 'if (/NR/) { s/\s*(\S+)\s+.*/\1/ ; print }'`
	RNAME=`basename $RDATASET`
	RSNAPSHOT="${RDATASET}@copy"

	# send new root if not already backed up
	$ZFSR list | grep $REMOTE_RDATASET/$RNAME >/dev/null 2>&1
	if [ $? -eq 1 ]
	then
		$ZFS snapshot $RSNAPSHOT
		$ZFS send $RSNAPSHOT | $ZFSR receive -euv $REMOTE_RDATASET
		echo $?
		$ZFS destroy $RSNAPSHOT
	fi
}
