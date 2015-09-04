#!/bin/bash
#restarts every hour, takes only some seconds
python getnfo.py sconfig.yaml
while true
do
sleep 3600
RELAYPID=$(ps aux | grep "python getnfo.py sconfig.yaml" | grep -v grep | awk '{print $2}')
kill -9 $RELAYPID
python getnfo.py sconfig.yaml
done
