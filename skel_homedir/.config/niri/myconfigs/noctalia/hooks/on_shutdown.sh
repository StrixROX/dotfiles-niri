#!/usr/bin/bash

pkill linux-wallpaper
if [[ "$?" == "1" ]]; then
    exit 0
fi

