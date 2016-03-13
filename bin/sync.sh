#!/bin/bash

set -eE
LANG=C

if [ -z "$1" ]
then
	echo "Usage: $0 archive"
	echo "e.g. $0 debian"
	exit 1
fi

# START OF OPTIONS ######################################################

TARGET_BASE=/srv/wanna-build/tmp/archive
TARGET="$TARGET_BASE/$1"

PASSWORD_BASE=/srv/wanna-build/etc
PASSWORD_FILE="$PASSWORD_BASE/$1.rsync-password"

RSYNC_OPTIONS="--delete --delete-excluded -av"

MIRROR_EXCLUDES="--exclude=**/*.changes --exclude=**/installer-* --exclude=**/Packages.diff --exclude=**/Sources.diff --exclude=ChangeLog --exclude=**/Contents-* --exclude=**/Translation-* --exclude=**/*.bz2 --exclude=Packages --exclude=Sources --exclude=**/*.new" # the latter two because we only accept gziped files
MIRROR_OPTIONS="$MIRROR_EXCLUDES $RSYNC_OPTIONS"

# END OF OPTIONS ########################################################

mkdir -p "$TARGET"

if [ ! "$2" = "nolock" ]
then
	# Do locking to avoid destroying other's views on an archive.
	LOCKFILE="$TARGET/lock"

	cleanup() {
		rm -rf "$LOCKFILE"
	}

	if lockfile -! -r 10 $LOCKFILE
	then
		echo "Sync failed: cannot lock $LOCKFILE, aborting."
		exit 1
	fi
	trap cleanup 0
fi

# Handle the syncing.
case $1 in
debian)
	USER=cimarosa
	BUILDD_QUEUE_OPTIONS="--exclude=*.bz2 $RSYNC_OPTIONS"
	rsync --password-file "$PASSWORD_FILE" $MIRROR_OPTIONS $USER@ftp-master.debian.org::debian/dists/ "$TARGET/archive"
	rsync --password-file "$PASSWORD_BASE/$1-buildd.rsync-password" $BUILDD_QUEUE_OPTIONS $USER@ftp-master.debian.org::debian-buildd-dists/ "$TARGET/debian-buildd-dists/"
	# Also sync the Maintainers and Uploaders files for consumption through the web interface.
	rsync --password-file "$PASSWORD_FILE" $MIRROR_OPTIONS $USER@ftp-master.debian.org::debian/indices/Maintainers /srv/buildd.debian.org/etc/Maintainers
	rsync --password-file "$PASSWORD_FILE" $MIRROR_OPTIONS $USER@ftp-master.debian.org::debian/indices/Uploaders /srv/buildd.debian.org/etc/Uploaders
	;;
debian-security)
	chmod 0700 "$TARGET"
	USER=cimarosa
	BUILDD_QUEUE_OPTIONS="--exclude=*.bz2 $RSYNC_OPTIONS"
	rsync --password-file "$PASSWORD_BASE/$1.rsync-password" $MIRROR_OPTIONS $USER@security-master.debian.org::debian-security/dists/ "$TARGET/archive"
	rsync --password-file "$PASSWORD_BASE/$1-buildd.rsync-password" $BUILDD_QUEUE_OPTIONS $USER@security-master.debian.org::debian-security-buildd-dists/ "$TARGET/debian-security-buildd-dists/"
	;;
debian-edu)
	rsync $MIRROR_OPTIONS --exclude=woody/ ftp.skolelinux.no::skolelinux-dist/dists/ "$TARGET/archive"
	;;
*)
	echo "Sync target $1 not supported, aborting."
	exit 1
	;;
esac

