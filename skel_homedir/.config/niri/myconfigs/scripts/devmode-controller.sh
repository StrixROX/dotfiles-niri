#!/bin/bash
# devmode-controller.sh - start/stop controller for devmode.service

AUTOCOMPLETE_MODEL="qwen2.5-coder-3b-instruct"

function start() {
    # Load the autocomplete model into LM Studio
    lms load $AUTOCOMPLETE_MODEL
    lms server start
}

function stop() {
    # Unload the autocomplete model from LM Studio
    lms server stop
    lms unload $AUTOCOMPLETE_MODEL
}

case "$1" in
    start)
        notify-send "Dev Mode" "Starting..."
        start
        notify-send "Dev Mode" "Started"
        ;;
    stop)
        notify-send "Dev Mode" "Stopping..."
        stop
        notify-send "Dev Mode" "Stopped"
        ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac
