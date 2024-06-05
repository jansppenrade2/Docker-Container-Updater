#!/bin/bash

echo "$DCU_CRONTAB_EXECUTION_EXPRESSION /opt/dcu/dcu_main.sh" > /etc/crontabs/root

echo "Configuring postfix..."
postconf -e "relayhost = $(echo $DCU_MAIL_RELAYHOST)"
postfix start

if { [[ "$1" = "dcu" ]] && [ -z "$2" ]; } || [ -z "$1" ]; then
    echo "Starting crond in foreground..."
    crond -f
elif [ "$1" = "dcu" ] && [ "$2" = "--self-update" ]; then
    start_time=$(date +%s)
    while [[ ! -f "/opt/dcu/.main_update_process_completed" ]]; do
        now_time=$(date +%s)
        if (( now_time - start_time >= 3600 )); then
            echo "ERROR  timeout reached!"
            echo "INFO   exiting..."
            sleep 10
            exit 1
        fi
        sleep 10
    done
fi