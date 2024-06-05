#!/bin/bash

echo "$DCU_CRONTAB_EXECUTION_EXPRESSION /opt/dcu/dcu_main.sh" > /etc/crontabs/root

echo "Configuring postfix..."
postconf -e "relayhost = $(echo $DCU_MAIL_RELAYHOST)"
postfix start

if { [[ "$1" = "dcu" ]] && [ -z "$2" ]; } || [ -z "$1" ]; then
    echo "Starting crond in foreground..."
    crond -f
elif [ "$1" = "dcu" ] && [ "$2" = "--self-update" ]; then
    echo "INFO   Waiting for status update..."
    start_time=$(date +%s)
    while [[ ! -f "/opt/dcu/.main_update_process_completed" ]]; do
        now_time=$(date +%s)
        if (( now_time - start_time >= 3600 )); then
            echo "ERROR  Timeout reached!"
            echo "INFO   Exiting..."
            sleep 10
            exit 1
        fi
        sleep 10
    done
    echo "INFO   Proceeding with self-update process..."
    echo "INFO       Executing \"/opt/dcu/dcu_main.sh\""
    /opt/dcu/dcu_main.sh
fi