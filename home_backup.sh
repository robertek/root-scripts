#!/bin/sh

ZFS="/sbin/zfs"
REMOTE_ZFS="/sbin/zfs"
SSH="/usr/bin/ssh"

TIMEOUT="120"
REMOTE_IP="192.168.10.10"
REMOTE_HOST="root@$REMOTE_IP"

REMOTE_DATASET="bpool/BACKUP/notebook"
LOCAL_DATASET="rpool/HOME"
LAST_BACKUP="$LOCAL_DATASET@backup-done"
NEW_BACKUP_SNAP="backup-`date +%Y%m%d_%H%M`"
NEW_BACKUP="$LOCAL_DATASET@$NEW_BACKUP_SNAP"

# check home
ping -c1 $REMOTE_IP || exit 1

# create new snapshot
$ZFS snapshot $NEW_BACKUP

# send new snapshot
$ZFS send -i $LAST_BACKUP $NEW_BACKUP | $SSH $REMOTE_HOST $REMOTE_ZFS receive -Fduv $REMOTE_DATASET

# check if done
$SSH $REMOTE_HOST $REMOTE_ZFS list -t snapshot | grep $NEW_BACKUP_SNAP >/dev/null 2>&1
if [ $? -eq 0 ]
then
	$ZFS destroy $LAST_BACKUP
	$ZFS rename $NEW_BACKUP $LAST_BACKUP
else
	$ZFS destroy $NEW_BACKUP
fi
