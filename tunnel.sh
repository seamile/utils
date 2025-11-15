#!/bin/bash

USER="alex"
ENVFILE="/tmp/ssh-tunnel.env"

function set_server() {
    if [ -n "$1" ]; then
        echo "SERVER=$1" > $ENVFILE
        echo "Set SERVER to '$1'"
    else
        echo "Set SERVER failed"
        return 1
    fi
}

function connect() {
    source $ENVFILE
    if pkill -0 -f 'ssh -qTnN -D 0.0.0.0:1086'; then
        echo "Already connected"
        exit 0
    else
        echo "Connecting to server '$SERVER'"
        ssh -qTnN -D 0.0.0.0:1086 $SERVER
    fi
}

function disconnect() {
    echo 'Disconnecting'
    pkill -f 'ssh .* -W'
    pkill -f 'ssh -qTnN -D 0.0.0.0:1086'
    rm -f $ENVFILE
}

function reconnect() {
    echo "Reconnect to server '$1'"
    if pkill -0 -f 'ssh -qTnN -D 0.0.0.0:1086'; then
        disconnect
        set_server $1
        pkill -HUP -f $(basename $0)
    else
        echo "Not connected"
    fi
}

function usage() {
    echo "Usage: $(basename $0) [-h] [-s SERVER] [-u USER] [-r NEW_SERVER]"
    echo "Example:"
    echo "  ssh-tunnel -s SERVER"
    echo "  ssh-tunnel -r NEW_SERVER"
}

while getopts ":s:u:r:h" opt; do
    case $opt in
        s)
            set_server $OPTARG
            ;;
        u)
            USER=$OPTARG
            ;;
        r)
            reconnect $OPTARG
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

trap "echo 'Reconnecting...'" HUP
trap "disconnect; exit 0" INT TERM

if [ ! -f $ENVFILE ]; then
    set_server bee
fi

while true; do
    connect
    sleep 1
done
