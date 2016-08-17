#!/bin/sh

echo rsync --stats -az --delete "$1" "$2"
rsync --stats -az --delete "$1" "$2" > rsync.log
cat rsync.log
grep -q 'Total transferred file size: 0 bytes$' rsync.log
while [ $? -ne 0 ]; do
	echo "# retry rsync until no more file, after sleep 30."
	sleep 30
	echo rsync --stats -az --delete "$1" "$2"
	rsync --stats -az --delete "$1" "$2" > rsync.log
	cat rsync.log
	grep -q 'Total transferred file size: 0 bytes$' rsync.log
done
