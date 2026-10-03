#!/bin/sh

mkdir -p /data

if [ ! -f /data/index.html ]; then
  echo "Week 6 Day 7 backend persistent data" > /data/index.html
fi

python -m http.server 8000 --directory /data
