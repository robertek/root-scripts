#!/bin/sh

################################################################################
# example usage:
#
# REMOTE_IP="1.2.3.4"
# PORT=8022
#
# . /path/to/remote_backup.sh
#
# SNAP_NAME="backup-done"
# REMOTE_DATASET="bpool/BACKUP/home"
# LOCAL_DATASET="rpool/HOME"
# sync_dataset
# 
# REMOTE_DATASET="bpool/BACKUP/machine_name"
# LOCAL_DATASET="rpool/SYSTEM/root"
# PREFIX="update-"
# sync_dataset_extern
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

check_host() {
	ping -c1 $REMOTE_IP >/dev/null || exit 1
}

sync_dataset() {
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


# sync dataset with existing snapshots
#
# variables:
#   LOCAL_DATASET
#   REMOTE_DATASET
#   PREFIX
sync_dataset_extern() {
	[ -z ${LOCAL_DATASET} ] && exit 1
	[ -z ${REMOTE_DATASET} ] && exit 1
	[ -z ${PREFIX} ] && exit 1

	check_host

	NEW_SNAPSHOT=`${ZFS} list -o name -t snapshot ${LOCAL_DATASET} | grep ${PREFIX} | tail -1 | cut -d@ -f2`
	LOCAL_DATASET_NOPOOL=`echo ${LOCAL_DATASET} | cut -d/ -f2-`

	# check for initail snapshot
	${ZFSR} list ${REMOTE_DATASET}/${LOCAL_DATASET_NOPOOL} >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		OLD_SNAPSHOT=`${ZFSR} list -o name -t snapshot ${REMOTE_DATASET}/${LOCAL_DATASET_NOPOOL} | grep ${PREFIX} | tail -1 | cut -d@ -f2`
		SEND_PARAM="-i ${LOCAL_DATASET}@${OLD_SNAPSHOT} ${LOCAL_DATASET}@${NEW_SNAPSHOT}"
		[ ${OLD_SNAPSHOT} = ${NEW_SNAPSHOT} ] && return
	else
		SEND_PARAM="${LOCAL_DATASET}@${NEW_SNAPSHOT}"
	fi

	# hold the local snapshot
	${ZFS} hold backup ${LOCAL_DATASET}@${NEW_SNAPSHOT}

	# send the new snapshot
	${ZFS} send -h ${SEND_PARAM} | ${ZFSR} receive -Fduv ${REMOTE_DATASET}

	# check if done
	${ZFSR} list -t snapshot ${REMOTE_DATASET}/${LOCAL_DATASET_NOPOOL}@${NEW_SNAPSHOT} >/dev/null 2>&1
	if [ $? -eq 0 ]
	then
		if [ ! -z ${OLD_SNAPSHOT} ]
		then
			${ZFS} release backup ${LOCAL_DATASET}@${OLD_SNAPSHOT}
			${ZFSR} release backup ${REMOTE_DATASET}/${LOCAL_DATASET_NOPOOL}@${OLD_SNAPSHOT}
		fi
	else
		${ZFS} release backup ${LOCAL_DATASET}@${NEW_SNAPSHOT}
	fi
}
