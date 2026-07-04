#!/usr/bin/bash
#
# Utility script to start/stop linux-wallpaperengine instance
#
# Usage:
#   ./linux-wallpaperengine-controller.sh <start|stop>
#

# declarations
WALLPAPER_ID="3339942111"

START_CMD="linux-wallpaperengine --screen-root eDP-1 --scaling fit --disable-mouse --disable-parallax --fullscreen-pause-only-active --silent --no-audio-processing --fps 30 $WALLPAPER_ID"

PID=$(pgrep -f linux-wallpaperengine)

if [[ -n "$PID" ]]; then
	STOP_CMD="kill $PID"
else
	STOP_CMD="echo -n (Nothing to do)"
fi

# main logic

if [ "$1" = "stop" ]; then
	echo -n "Stopping..."
	$STOP_CMD
	echo $?

elif [ "$1" = "start" ]; then
	echo -n "Stopping..."
	$STOP_CMD
	echo $?

	echo -n "Starting..."
	nohup $START_CMD > /dev/null 2>&1 < /dev/null &
	echo $?
else
	echo "Usage: $0 <start|stop>"
	exit 1
fi
