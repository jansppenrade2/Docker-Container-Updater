#!/bin/bash

echo "$DCU_CRONTAB_EXECUTION_EXPRESSION /opt/dcu/dcu_main.sh" > /etc/crontabs/root

echo "Configuring postfix..."
postconf -e "relayhost = $(echo $DCU_MAIL_RELAYHOST)"
postfix start

if { [[ "$1" = "dcu" ]] && [ -z "$2" ]; } || [ -z "$1" ]; then
    echo "Starting crond in foreground..."
    crond -f
elif [ "$1" = "dcu" ] && [ "$2" = "--self-update" ]; then
    /opt/dcu/dcu_self_update_helper.sh
fi