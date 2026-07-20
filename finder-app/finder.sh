#!/bin/sh
# Searches for a string in files under a directory and reports counts.
# Arguments:
#   $1: filesdir - directory to search
#   $2: searchstr - string to search for

if [ $# -lt 2 ]; then
    echo "Error: Two arguments required - filesdir and searchstr"
    exit 1
fi

filesdir=$1
searchstr=$2

if [ ! -d "$filesdir" ]; then
    echo "Error: ${filesdir} is not a valid directory"
    exit 1
fi

numfiles=$(find "$filesdir" -type f | wc -l)
numlines=$(grep -r "$searchstr" "$filesdir" | wc -l)

echo "The number of files are ${numfiles} and the number of matching lines are ${numlines}"
