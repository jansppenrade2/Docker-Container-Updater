#!/bin/bash

echo "$DCU_CRONTAB_EXECUTION_EXPRESSION /opt/docker_container_updater/container_update.sh" > /etc/crontabs/root

echo "Configuring postfix..."
postconf -e "relayhost = $(echo $DCU_MAIL_RELAYHOST)"
postfix stop
postfix start

echo "Starting crond in foreground..."
crond -f
