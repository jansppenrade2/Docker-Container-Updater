#!/bin/bash

echo "$DCU_CRONTAB_EXECUTION_EXPRESSION /opt/docker_container_updater/container_update.sh" > /etc/crontabs/root
crond -f
