#!/bin/bash

hour=$(/bin/date +%H)

if [ "$hour" -ge 19 ] || [ "$hour" -lt 6 ]; then
    current=$(defaults read -g AppleInterfaceStyle 2>/dev/null)

    if [ "$current" != "Dark" ]; then
        /usr/bin/osascript -e \
            'tell application "System Events" to tell appearance preferences to set dark mode to true'
    fi
fi
