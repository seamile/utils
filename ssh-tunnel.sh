#!/bin/bash

USER="alex"
SERVER="$1"

while true
do
    echo "connecting $SERVER"
    # ssh -qTnN -D 0.0.0.0:1086 $USER@$SERVER
    ssh -qTnN -D 0.0.0.0:1086 $SERVER
    echo 'retry after 1s ...'
    sleep 1
done
