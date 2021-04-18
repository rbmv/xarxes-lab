#!/bin/bash
port=8080
while true; do 
r=`netstat -lnt | grep $port | wc -l`
if [[ $r =~ "0" ]]; then
    fortune | nc -l $port
else
    exit 1
fi
done
