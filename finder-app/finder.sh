#!/bin/sh

filesdir=$1
searchstr=$2

#check if the arguments are provided

if [ -z "$filesdir" ] || [ -z "$searchstr " ]; then
	echo "Error: Both direstory and search string must be specified."
	exit 1
fi

#check if filesdir is a directory
if [ ! -d "$filesdir" ]; then
	echo "Error: $filesdir is not a directory."
	exit 1
fi

#count number of files in directory and sub-directories
numfiles=$(find "$filesdir" -type f | wc -l)

#counut number of matching lines containing searchstr
numlines=$(grep -r -- "$searchstr" "$filesdir" | wc -l)

echo "The number of files are $numfiles and the number of matching lines are $numlines"

