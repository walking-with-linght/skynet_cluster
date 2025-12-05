#!/bin/bash

# source run_nohup.sh
# echo "  >>------- hall server ---------"
# run hall ${PROJECT_PATH}/skynet/skynet ./etc/config.hall

servers=`sudo netstat -ntlp | grep 64001 | sort | awk '{print $NF}' | awk -F'/' '{print $1}'`
for i in $servers
do
        echo $i
        sudo kill -9 $i
done

./skynet/skynet etc/config.monitor > monitor.log  &