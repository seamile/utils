#!/bin/bash

if [[ "$1" == "-j" ]]; then
    USER="alex"
    SERVER="jmp"
else
    USER="alex"
    SERVER="bee"
fi

while true
do
    echo "connecting $USER@$SERVER"
    # ssh -qTnN -D 0.0.0.0:1086 $USER@$SERVER
    ssh -qTnN -D 0.0.0.0:1086 $SERVER
done
