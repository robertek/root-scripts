#!/bin/bash

HIDE="Maintainer|Upstream|Repository|FEATURES|INFO|Applying|autoconf|autoheader|autoreconf|automake|libtoolize|aclocal|elibtoolize|Updating icons|desktop mime|shared mime|LOG|autopoint|/lib/systemd"
ELOG_DIR="/var/log/portage/elog"

for FILE in $ELOG_DIR/*.log
do 
	echo "################################################################################"
	echo "$FILE"
	echo "################################################################################"
	egrep -v "$HIDE" $FILE
	echo "################################################################################"
	echo -n "Delete? [y/N]: "
	read YES
	[[ $YES == "y" ]] && rm $FILE
done
