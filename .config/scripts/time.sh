#!/bin/bash

date=$(date +"%A %B %d")
time=$(date +"%I:%M %p")

notify-send "$time" "$date"
