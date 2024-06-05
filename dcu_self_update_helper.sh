#!/bin/bash
#
# DOCKER CONTAINER UPDATER
# Self-Update Helper Script
#
# ## Version
# 2024.06.05-a

dcu_container_name="$DCU_CONFIG_FILE"
dcu_container_name_backed_up="$DCU_CONTAINER_NAME_BACKED_UP"
dcu_self_update_helper_command="$DCU_SELF_UPDATE_HELPER_COMMAND"
renamed_successfully=false
new_container_started_successfully=false
old_container_stopped_successfully=false

echo "DCU Container Name:      \"$dcu_container_name\""
echo "DCU Self-Update Command: \"$dcu_container_name\""
echo "Processing self-update..."
echo "Renaming DCU container from $dcu_container_name to $dcu_container_name_backed_up..."
{ docker rename "$dcu_container_name" "$dcu_container_name_backed_up" > /dev/null; result=$?; } || result=$?
[ $result -eq 0 ] && renamed_successfully=true  && echo "  => Container successfully renamed"
[ $result -ne 0 ] && renamed_successfully=false && echo "  => Failed to rename container: $result"

[ "$renamed_successfully" == true  ] && echo "Disabling automatic startup for $dcu_container_name_backed_up..."
[ "$renamed_successfully" == true  ] && { docker update "$dcu_container_name_backed_up" --restart no > /dev/null; result=$?; } || result=$?
[ "$renamed_successfully" == true  ] && [ $result -eq 0 ] && echo "  => Successfully updated startup policy"
[ "$renamed_successfully" == true  ] && [ $result -ne 0 ] && echo "  => Failed to update startup policy: $result"

[ "$renamed_successfully" == true  ] && echo "Stopping $dcu_container_name_backed_up..."
[ "$renamed_successfully" == true  ] && { docker stop "$dcu_container_name_backed_up" > /dev/null; result=$?; } || result=$?
[ "$renamed_successfully" == true  ] && [ $result -eq 0 ] && old_container_stopped_successfully=true  && echo "  => Successfully stopped container"
[ "$renamed_successfully" == true  ] && [ $result -ne 0 ] && old_container_stopped_successfully=false && echo "  => Failed stop old container: $result"

[ "$renamed_successfully" == true  ] && [ "$old_container_stopped_successfully" == true  ] && echo "Executing docker run command..."
[ "$renamed_successfully" == true  ] && [ "$old_container_stopped_successfully" == true  ] && echo "  => $dcu_self_update_helper_command"
[ "$renamed_successfully" == true  ] && [ "$old_container_stopped_successfully" == true  ] && { eval "$dcu_self_update_helper_command" > /dev/null; result=$?; } || result=$?
[ "$renamed_successfully" == true  ] && [ "$old_container_stopped_successfully" == true  ] && [ $result -eq 0 ] && new_container_started_successfully=true  && echo "  => New container started successfully"
[ "$renamed_successfully" == true  ] && [ "$old_container_stopped_successfully" == true  ] && [ $result -ne 0 ] && new_container_started_successfully=false && echo "  => Failed to start new container: $result"