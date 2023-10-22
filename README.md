# Docker Container Updater
Automatic Docker Container Updater Script

# DESCRIPTION
This script is designed to automate the process of updating running and paused Docker container images while preserving their configurations. It also provides the option to specify exceptions by listing container names in the ignored_containers variable.

It's important to note that only inter-major updates are automated; major updates must be performed manually for security reasons. For example, if a container is running version 2.1.0, updates to versions 2.1.1 and 2.2.0 will be handled by this script. If an update to version 3.0.0 is available, the script will inform you in the logs but not handle this update.

To run pre or post-installation scripts for specific containers, place these scripts in the same directory as this script (container_update.sh) and name them "container_update_post_script_<container_name>.sh" or "container_update_pre_script_<container_name>.sh."

# HOW TO USE THIS SCRIPT
1. Place this script in your Docker server's file system.
2. Make it executable with the command "chmod +x </path/to/this/script/container_update.sh>."
3. For a fully automated experience, create a cron job to run this script periodically.

# HINT
For security reasons, this script is executed with enabled test mode by default. As soon as you review your log file created by this script after testing it on your system, which I highly recommend(!), you can disable the test mode by editing the variable "test_mode".

# FUNCTIONALITY
1. The script begins by checking if a previous instance is running to prevent multiple instances from running simultaneously.
2. It creates a log file for recording execution details.
3. Functions are defined to quote strings and add settings to the docker run command.
4. The script collects Docker container IDs and iterates through them.
5. It gathers information about each container, such as its image, name, network settings, and environment variables.
6. The script checks for available updates within the same major version, and if an update is available, it pulls the new image and updates the container. If the docker run command fails, all changes will be reverted, and the old container will be started again.
7. Container pre and post-installation scripts are executed, if available.
8. Container backups and image pruning can be performed.
9. The script truncates the log file to retain only recent entries.
10. It concludes the execution and removes the process ID file.

# CUSTOMIZABLE VARIABLES
- test_mode: Determines whether the script runs in test mode to prevent unwanted system changes (true/false).
- docker_executable_path: Points to the location of the Docker executable on your system.
- ignored_containers: An array storing container names to be ignored by the script.
- prune_images: Specifies whether to prune Docker images after each execution (true/false).
- prune_container_backups: Determines whether to prune Docker container backups after each execution (true/false).
- container_backups_retention_days: Specifies the number of days for retaining container backups.
- log_retention_days: Sets the number of days to keep log entries.

# TESTING ENVIRONMENT(S)
## Tested on the following operating systems with standard Docker installations
- CentOS Stream 9
- Qnap QTS

## Tested with the following Docker container images/tags
- aalbng/glpi:10.0.9
- adguard/adguardhome:v0.107.40
- dpage/pgadmin4:7.8
- linuxserver/dokuwiki:2023-04-04a-ls186
- linuxserver/plex:1.32.6
- linuxserver/sabnzbd:4.1.0
- linuxserver/swag:2.7.1
- linuxserver/swag:2.7.2
- linuxserver/webtop:ubuntu-kde
- mariadb:11.1.2
- nextcloud:27.1.2
- ocsinventory/ocsinventory-docker-image:2.12
- odoo:16.0
- onlyoffice/documentserver:7.5.0
- osixia/openldap:1.5.0
- osixia/phpldapadmin:0.9.0
- phpmyadmin/phpmyadmin:5.2.1
- portainer/portainer-ee:2.19.1
- postgres:15.4
- redis:7.2.2 2023-10-20
- thingsboard/tb-postgres:3.5.1
- vaultwarden/server:1.29.2
