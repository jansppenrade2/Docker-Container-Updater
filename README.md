# DOCKER CONTAINER UPDATER

Automatic Docker Container Updater Script
 
## Description

This script is designed to automate the process of updating running and paused Docker container images while preserving their configurations. It also provides the option to specify exceptions by listing container names in the `ignored_containers` variable.

It's important to note that only inter-major updates are automated; major updates must be performed manually for security reasons. For example, if a container is running version 2.1.0, updates to versions 2.1.1 and 2.2.0 will be handled by this script. If an update to version 3.0.0 is available, the script will inform you in the logs but not handle this update.

To run pre or post-installation scripts for specific containers, place these scripts in the same directory as `container_update.sh` and name them `container_update_post_script_<container_name>.sh` or `container_update_pre_script_<container_name>.sh`.

To receive notifications by e-mail, Postfix must be installed and configured on the host, as this script uses the "sendmail" command to send e-mails.
 
## How to use this script
1. Place this script in your Docker server's file system.
2. Make it executable with the command `chmod +x </path/to/container_update.sh>`.
3. For a fully automated experience, create a cron job to run this script periodically.
 
## Hint
For security reasons, this script is executed with enabled test mode by default. As soon as you review your log file created by this script after testing it on your system in "<scriptpath>\logs\container_update.sh.log", which I highly recommend(!), you can disable the test mode by editing the variable `test_mode`.
 
## Customizable variables
 
| Variable                           | Description      | Example Values                                         |
| ---------------------------------- | ---------------- | ------------------------------------------------------ |
| `test_mode`                        | Determines whether the script runs in test mode to prevent unwanted system changes. | `true`/`false` |
| `docker_executable_path`           | Points to the location of the docker executable on your system. | `"/usr/bin/"` |
| `sendmail_executable_path`         | Points to the location of the sendmail executable on your system. | `"/usr/sbin/"` |
| `ignored_containers`               | An array storing container names to be ignored by the script. | `("MyContainer1" "MyContainer2" "MyContainer3")` |
| `prune_images`                     | Specifies whether to prune Docker images after each execution. | `true`/`false` |
| `prune_container_backups`          | Determines whether to prune Docker container backups after each execution or not. The very last backup is always kept. | `true`/`false` |
| `container_backups_retention_days` | Specifies the number of days for retaining container backups. The very last backup is always kept, regardless of its age! | `7` |
| `log_retention_days`               | Sets the number of days to keep log entries. | `7` |
| `checkContainerStateTimeout`       | The duration in seconds to wait before performing a one-time check to determine if a Docker container has been successfully started. | `120` |
| `mail_recipients`                  | An array storing the recipient's email addresses for notifications. | `("notify@mydomain.com" "my.mail@gmail.com")` |
| `mail_subject`                     | Any subject for your notification mails. | `"Docker Container Update Report from $(hostname)"` |
| `mail_from`                        | The from-address the notification mails will sent from. | `"notify@mydomain.com"` |
| `mail_notification_level`          | Level 1 informs you about available major updates, even if no updates have been made by this script. Level 2 just informs abaout available updates only if other updates have been made by this script. | `1`/`2` |
 
## Testing environment(s)
### Operating Systems
- CentOS Stream 9
- Qnap QTS
- UbuntuUbuntu 22.04.3 LTS
 
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
