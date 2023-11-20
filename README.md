DOCKER CONTAINER UPDATER
Automatic Docker Container Updater Script

## Version
2023.11.19-0

## Changelog
2023.11.19-0, janseppenrade2: Overhauled variable description
2023.11.18-c, janseppenrade2: Optimized mail message
2023.11.18-b, janseppenrade2: Added hint to notification mail in test mode
2023.11.18-a, janseppenrade2: Bugfix with notification level
2023.11.17-0, janseppenrade2: Optimized logging, added support for mail notifications via sendmail command
2023.11.16-0, janseppenrade2: Changed versioning
2023.11.13-0, janseppenrade2: Various bug fixes, regex filter creation optimization (create_regex_filter()) and improvements to major version recognition
2023.11.08-0, janseppenrade2: Reduced timeout for test mode, various bug fixes
2023.11.07-0, janseppenrade2: Bugfix in sorting list of available image tags from docker hub
2023.10.26-0, janseppenrade2: Bugfix in container startup validation; Disabled image download in test mode
2023.10.25-0, janseppenrade2: Bugfix in the order of Docker run parameters (tmpfs was missplaced); Added extended container startup validation; reduced value of $container_backups_retention_days from 14 to 7 as default
2023.10.24-0, janseppenrade2: Added Tmpfs option
2023.10.23-0, janseppenrade2: Improved regex filter creation (create_regex_filter())
2023.10.21-1, janseppenrade2: Released
2023.10.21-0, janseppenrade2: Renamed some variables and optimized it's descriptions
2023.10.18-0, janseppenrade2: Fixed a bug that prevented pruning docker container backups
2023.10.18-0, janseppenrade2: Fixed a bug that caused container updates even if there is no update available
2023.10.17-1, janseppenrade2: Added possibility to prune containers
2023.10.17-0, janseppenrade2: Several bugfixes
2023.10.07-0, janseppenrade2: Created
 
## Description
This script is designed to automate the process of updating running and paused Docker container images while preserving their configurations. It also provides the option to specify exceptions by listing container names in the `ignored_containers` variable.
It's important to note that only inter-major updates are automated; major updates must be performed manually for security reasons. For example, if a container is running version 2.1.0, updates to versions 2.1.1 and 2.2.0 will be handled by this script. If an update to version 3.0.0 is available, the script will inform you in the logs but not handle this update.
To run pre or post-installation scripts for specific containers, place these scripts in the same directory as `container_update.sh` and name them `container_update_post_script_<container_name>.sh` or `container_update_pre_script_<container_name>.sh`.
To receive notifications by e-mail, Postfix must be installed and configured on the host, as this script uses the "mail" command to send e-mails.
 
## How to use this script
1. Place this script in your Docker server's file system.
2. Make it executable with the command `chmod +x </path/to/container_update.sh>`.
3. For a fully automated experience, create a cron job to run this script periodically.
 
## Hint
For security reasons, this script is executed with enabled test mode by default. As soon as you review your log file created by this script after testing it on your system in "<scriptpath>\logs\container_update.sh.log", which I highly recommend(!), you can disable the test mode by editing the variable `test_mode`.
 
## Customizable variables
 
| Variable                           | Description                                                                                                                                                                                                      | Example Values                                         |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `test_mode`                        | Determines whether the script runs in test mode to prevent unwanted system changes.                                                                                                                              | `true`/`false`                                         |
| `docker_executable_path`           | Points to the location of the docker executable on your system.                                                                                                                                                  | `"/usr/bin/"`                                          |
| `sendmail_executable_path`         | Points to the location of the sendmail executable on your system.                                                                                                                                                | `"/usr/sbin/"`                                         |
| `ignored_containers`               | An array storing container names to be ignored by the script.                                                                                                                                                    | `("MyContainer1" "MyContainer2" "MyContainer3")`       |
| `prune_images`                     | Specifies whether to prune Docker images after each execution.                                                                                                                                                   | `true`/`false`                                         |
| `prune_container_backups`          | Determines whether to prune Docker container backups after each execution or not. The very last backup is always kept.                                                                                           | `true`/`false`                                         |
| `container_backups_retention_days` | Specifies the number of days for retaining container backups. The very last backup is always kept, regardless of its age!                                                                                        | `7`                                                    |
| `log_retention_days`               | Sets the number of days to keep log entries.                                                                                                                                                                     | `7`                                                    |
| `checkContainerStateTimeout`       | The duration in seconds to wait before performing a one-time check to determine if a Docker container has been successfully started.                                                                             | `120`                                                  |
| `mail_recipients`                  | A comma seperated list with e-mail addresses for notifications.                                                                                                                                                  | `"notify@mydomain.com,my.mail@gmail.com"`              |
| `mail_subject`                     | Any subject for your notification mails.                                                                                                                                                                         | `"Docker Container Update Report from $(hostname)"`    |
| `mail_from`                        | The from-address the notification mails will sent from.                                                                                                                                                          | `"notify@mydomain.com"`                                |
| `mail_notification_level`          | Level 1 informs you about available major updates, even if no updates have been made by this script. Level 2 just informs abaout available updates only if other updates have been made by this script.          | `1`/`2`                                                |
 
## Testing environment(s)
### Operating Systems
- CentOS Stream 9
- Qnap QTS
 
### Docker Containers
- aalbng/glpi:10.0.9
- adguard/adguardhome:v0.107.40
- checkmk/check-mk-raw:2023.10.24
- dpage/pgadmin4:7.8
- juanluisbaptiste/postfix:1.7.1
- linuxserver/dokuwiki:2023-04-04a-ls186
- linuxserver/plex:1.32.6
- linuxserver/sabnzbd:4.1.0
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
- redis:7.2.2
- thingsboard/tb-postgres:3.5.1
- vaultwarden/server:1.29.2
