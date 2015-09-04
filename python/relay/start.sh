#!/bin/bash
#restarts every hour, takes only some seconds
python relay.py econfig.yaml
while true
do
sleep 3600
RELAYPID=$(ps aux | grep "python relay.py econfig.yaml" | grep -v grep | awk '{print $2}')
kill -9 $RELAYPID
python relay.py econfig.yaml
done
