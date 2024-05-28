# Docker Container Updater

For the lazier and automation-loving nerds (like myself), constantly updating Docker containers can be a tedious chore. Enter the Docker Container Updater to save the day. It handles updates without relying on the "latest" tag or sticking to the current image tag, which might cause you to miss important updates. Instead, it plays by your rules!

## Features

- **🔄 Automated Container Updates**: Effortlessly update all your Docker containers on your host under your own conditions.
- **🧠 Smart Update Detection**: This script creates a regex filter based on the currently used image tag and scans Docker Hub for any available updates. It automatically analyzes the version numbers specified in the image tags and identifies major, minor, patch, and build updates. It also handles simple digest updates automatically.
- **⚙️ Customizable and Conditional Update Rules**: Define highly precise update rules for each individual container.
- **🔁 Standard Update Sequence**: Updates follow the standard sequence: first digest, build, patch, minor, and then major updates. No updates are skipped.
- **🛠️ Backup and Rollback**: Backups of your containers are created before updates. If an update fails, the change is rolled back and the old container is restarted.
- **📧 Notifications**: Stay informed with detailed email and telegram reports
- **📜 Pre- and Post-Scripts Integration**: Integrate your own pre- and post-scripts to perform actions such as backing up configuration files or databases before any update and making adjustments to the container configuration after any update.

> The default configuration has **test mode enabled**. Safety first 😉! After you've run your first test, checked for errors, and reviewed the generated Docker run commands, you can disable test mode in your configuration file *(see below)*.

## Installation / Update

**Here are three methods for running this script:**
1. [Directly on your Docker host](#1-directly-on-your-host)
2. [Using the official Docker image](#2-using-the-official-docker-image)
   - [Docker CLI](#docker-cli)
   - [Docker Compose](#docker-compose)
4. [Cloning this repository and building your own container](#3-build-your-own-docker-container)
   
### 1. Directly on your host

1. On your Docker host, navigate to the directory where the script `container_update.sh` should be downloaded.
2. Download `container_update.sh` and make it executable _(this can be done manually or using the following command)_
   ```bash
   wget --header='Accept: application/vnd.github.v3.raw' -O container_update.sh https://api.github.com/repos/jansppenrade2/Docker-Container-Updater/contents/container_update.sh?ref=main && chmod +x ./container_update.sh
   ```
3. Execute the script with root privileges *(the first run will be in **test mode** and will also create the default configuration file)*
4. Customize the default configuration according to your specific requirements *(see below)*
5. Create a cron job for this script *(after testing 🫠)*

### 2. Using the official Docker image

> At this point, I would like to express my gratitude to @Keonik1 for his invaluable assistance! 🎉

#### Docker CLI

##### Example Command with Persistent Data

```bash
docker run  -d \
            --name=Docker-Container-Updater \
            --hostname=Docker-Container-Updater \
            --restart=always \
            --privileged \
            --tty \
            --mount type=bind,source=<YOUR_LOCAL_PRE_SCRIPTS_PATH>,target=/usr/local/etc/container_update/pre-scripts \
            --mount type=bind,source=<YOUR_LOCAL_POST_SCRIPTS_PATH>,target=/usr/local/etc/container_update/post-scripts \
            --mount type=bind,source=<YOUR_LOCAL_LOGS_PATH>,target=/opt/docker_container_updater/logs \
            --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
            --mount type=bind,source=/etc/localtime,target=/etc/localtime:ro \
            --env DCU_TEST_MODE=true \
            --env DCU_UPDATE_RULES='*[0.1.1-1,true] Docker-Container-Updater[0.0.0-0,false]' \
            --env DCU_CRONTAB_EXECUTION_EXPRESSION='30 2 * * *' \
            --env DCU_CONFIG_FILE=/opt/docker_container_updater/container_update.ini \
            --env DCU_PRE_SCRIPTS_FOLDER=/opt/docker_container_updater/pre-scripts \
            --env DCU_POST_SCRIPTS_FOLDER=/opt/docker_container_updater/post-scripts \
            --env DCU_PRUNE_IMAGES=true \
            --env DCU_PRUNE_CONTAINER_BACKUPS=true \
            --env DCU_CONTAINER_BACKUPS_RETENTION=7 \
            --env DCU_CONTAINER_BACKUPS_KEEP_LAST=1 \
            --env DCU_CONTAINER_UPDATE_VALIDATION_TIME=120 \
            --env DCU_DOCKER_HUB_API_URL='https://registry.hub.docker.com/v2' \
            --env DCU_DOCKER_HUB_API_IMAGE_TAGS_PAGE_SIZE_LIMIT=100 \
            --env DCU_DOCKER_HUB_API_IMAGE_TAGS_PAGE_CRAWL_LIMIT=10 \
            --env DCU_DOCKER_HUB_IMAGE_MINIMUM_AGE=21600 \
            --env DCU_LOG_FILEPATH=/opt/docker_container_updater/logs/container_update.log \
            --env DCU_LOG_LEVEL=INFO \
            --env DCU_LOG_RETENTION=7 \
            --env DCU_MAIL_NOTIFICATIONS_ENABLED=false \
            --env DCU_MAIL_NOTIFICATION_MODE=sendmail \
            --env DCU_MAIL_FROM='' \
            --env DCU_MAIL_RECIPIENTS='' \
            --env DCU_MAIL_SUBJECT='Docker Container Update Report from $(hostname)' \
            --env DCU_TELEGRAM_NOTIFICATIONS_ENABLED=false \
            --env DCU_TELEGRAM_BOT_TOKEN='' \
            --env DCU_TELEGRAM_CHAT_ID='' \
            --env DCU_TELEGRAM_RETRY_INTERVAL=10 \
            --env DCU_TELEGRAM_RETRY_LIMIT=2 \
            janjk/docker-container-updater:latest
```

##### Docker Compose

1. Download the docker-compose-example.yaml
2. Rename `docker-compose-example.yaml` to `docker-compose.yaml`
   ```bash
   mv ./docker-compose-example.yaml ./docker-compose.yaml
   ```
3. Customize your `docker-compose.yaml`
4. run  `docker-compose up -d`

### 3. Build your own Docker container

1. Clone this repository and navigate to it's folder
   ```bash
   git clone https://github.com/jansppenrade2/Docker-Container-Updater.git
   cd Docker-Container-Updater/
   ```
2. Build the container
   ```bash
   docker build -t docker_container_updater:latest -f ./DOCKERFILE .
   ```
   Or build a corporate proxy:
   ```bash
   docker build -t docker_container_updater:latest \
   --build-arg http_proxy=http://172.17.0.1:3128 \ 
   --build-arg https_proxy=http://172.17.0.1:3128 \ 
   -f ./DOCKERFILE .
   ```
3. Rename `docker-compose-example.yaml` to `docker-compose.yaml`
   ```bash
   mv ./docker-compose-example.yaml ./docker-compose.yaml
   ```
5. Customize your `docker-compose.yaml`
6. Start the setup with the command `docker compose up -d`.
7. Update the setup with:
   ```bash
   docker compose down
   docker compose pull
   docker compose up -d
   ```

## Configuration

The Docker Container Updater utilizes a configuration file, by default located at `/usr/local/etc/container_update/container_update.ini`. This file contains all the settings and parameters necessary for the script to run. You have the flexibility to tailor the configuration file to your specific needs when executing the script directly on your Docker host. Alternatively, when opting to utilize Docker container, you can simply add the corresponding environment variables.

| Config File Parameter                                  | Docker Environment Variable                      | Description                                                                                                                                           | Default Value                                                 | Possible Values                                           |
|--------------------------------------------------------|--------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|-----------------------------------------------------------|
| [general]  test_mode                                   | DCU_TEST_MODE                                    | Enables or disables test mode                                                                                                                         | `true`                                                        | `true`, `false`                                           |
| [general]  prune_images                                | DCU_PRUNE_IMAGES                                 | Automatically prune unused images                                                                                                                     | `true`                                                        | `true`, `false`                                           |
| [general]  prune_container_backups                     | DCU_PRUNE_CONTAINER_BACKUPS                      | Automatically prune old container backups                                                                                                             | `true`                                                        | `true`, `false`                                           |
| [general]  container_backups_retention                 | DCU_CONTAINER_BACKUPS_RETENTION                  | Number of days to retain container backups                                                                                                            | `7`                                                           | Any positive integer                                      |
| [general]  container_backups_keep_last                 | DCU_CONTAINER_BACKUPS_KEEP_LAST                  | Number of last container backups to keep regardless of retention time                                                                                 | `1`                                                           | Any positive integer                                      |
| [general]  container_update_validation_time            | DCU_CONTAINER_UPDATE_VALIDATION_TIME             | Time in seconds to validate if a container runs successfully after an update                                                                          | `120`                                                         | Any positive integer                                      |
| [general]  update_rules                                | DCU_UPDATE_RULES                                 | Rules for updating containers (see detailed explanation below)                                                                                        | `*[0.1.1-1,true]` `Docker-Container-Updater[0.0.0-0,false]`   | Custom rules (seperated by space)                         |
| [general]  docker_hub_api_url                          | DCU_DOCKER_HUB_API_URL                           | URL for the Docker Hub API                                                                                                                            | `https://registry.hub.docker.com/v2`                          | Any valid URL                                             |
| [general]  docker_hub_api_image_tags_page_size_limit   | DCU_DOCKER_HUB_API_IMAGE_TAGS_PAGE_SIZE_LIMIT    | Number of tags to fetch per page from Docker Hub                                                                                                      | `100`                                                         | Positive integer (1-100)                                  |
| [general]  docker_hub_api_image_tags_page_crawl_limit  | DCU_DOCKER_HUB_API_IMAGE_TAGS_PAGE_CRAWL_LIMIT   | Number of pages to crawl for tags from Docker Hub                                                                                                     | `10`                                                          | Any positive integer                                      |
| [general]  docker_hub_image_minimum_age                | DCU_DOCKER_HUB_IMAGE_MINIMUM_AGE                 | Minimum age in seconds threshold for a newly pulled Docker image                                                                                      | `21600`                                                       | Any positive integer                                      |
| [general]  pre_scripts_folder                          | DCU_PRE_SCRIPTS_FOLDER                           | Folder containing pre-update scripts                                                                                                                  | `/usr/local/etc/container_update/pre-scripts`                 | Any valid directory path                                  |
| [general]  post_scripts_folder                         | DCU_POST_SCRIPTS_FOLDER                          | Folder containing post-update scripts                                                                                                                 | `/usr/local/etc/container_update/post-scripts`                | Any valid directory path                                  |
| [paths]    tput                                        |                                                  | Path to the `tput` command                                                                                                                            | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    gawk                                        |                                                  | Path to the `gawk` command                                                                                                                            | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    cut                                         |                                                  | Path to the `cut` command                                                                                                                             | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    docker                                      |                                                  | Path to the `docker` command                                                                                                                          | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    grep                                        |                                                  | Path to the `grep` command                                                                                                                            | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    jq                                          |                                                  | Path to the `jq` command                                                                                                                              | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    sed                                         |                                                  | Path to the `sed` command                                                                                                                             | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    wget                                        |                                                  | Path to the `wget` command                                                                                                                            | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    sort                                        |                                                  | Path to the `sort` command                                                                                                                            | *(automatically detected by script)*                          | Any valid file path                                       |
| [paths]    sendmail                                    |                                                  | Path to the `sendmail` command                                                                                                                        | *(automatically detected by script)*                          | Any valid file path                                       |
| [log]      filePath                                    | DCU_LOG_FILEPATH                                 | Path to the log file                                                                                                                                  | `/var/log/container_update.log`                               | Any valid file path                                       |
| [log]      level                                       | DCU_LOG_LEVEL                                    | Log level                                                                                                                                             | `INFO`                                                        | `DEBUG`, `INFO`, `WARN`, `ERROR`                          |
| [log]      retention                                   | DCU_LOG_RETENTION                                | Number of days to retain log file entries                                                                                                             | `7`                                                           | Any positive integer                                      |
| [mail]     notifications_enabled                       | DCU_MAIL_NOTIFICATIONS_ENABLED                   | Enable or disable email notifications                                                                                                                 | `false`                                                       | `true`, `false`                                           |
| [mail]     mode                                        | DCU_MAIL_NOTIFICATION_MODE                       | Mode of sending emails  (currently only sendmail is supported)                                                                                        | `sendmail`                                                    | `sendmail`                                                |
| [mail]     from                                        | DCU_MAIL_FROM                                    | Email address for sending notifications                                                                                                               |                                                               | Any valid email address                                   |
| [mail]     recipients                                  | DCU_MAIL_RECIPIENTS                              | Space-separated list of recipient email addresses                                                                                                     |                                                               | Any valid email addresses (seperated by space)            |
| [mail]     subject                                     | DCU_MAIL_SUBJECT                                 | Subject of the notification email                                                                                                                     | `Docker Container Update Report from <hostname>`              | Any valid string                                          |
| [telegram] notifications_enabled                       | DCU_TELEGRAM_NOTIFICATIONS_ENABLED               | Enable or disable telegram notifications                                                                                                              | `false`                                                       | `true`, `false`                                           |
| [telegram] retry_limit                                 | DCU_TELEGRAM_RETRY_LIMIT                         | Number of retry attempts for sending a message                                                                                                        | 2                                                             | Any positive integer                                      |
| [telegram] retry_interval                              | DCU_TELEGRAM_RETRY_INTERVAL                      | Time interval between retry attempts (in seconds)                                                                                                     | 10                                                            | Any positive integer                                      |
| [telegram] chat_id                                     | DCU_TELEGRAM_CHAT_ID                             | Unique identifier for the target chat or user                                                                                                         |                                                               | A single valid chat ID                                    |
| [telegram] bot_token                                   | DCU_TELEGRAM_BOT_TOKEN                           | Access token for the Telegram Bot API                                                                                                                 |                                                               | A single valid Telegram Bot token                         |
|                                                        | DCU_CRONTAB_EXECUTION_EXPRESSION                 | Crontab expression when script to execute the update process automatically. You can use [this site](https://crontab.cronhub.io/) to create expression |                                                               | Any valid crontab expression                              |
|                                                        | DCU_CONFIG_FILE                                  | Path to ini config file inside container. **Do not save this as persistence!**                                                                        |                                                               | Any valid file path                                       |


### Update Rules

The `update_rules` parameter allows you to define the update behavior for your containers. The default rule is `*[0.1.1-1,true]`, which means:

- `*`: Applies to all containers.
- `0.1.1-1`: Specifies the update policy, where each number represents:
  - `0`: Major updates *(0 means no major updates, 1 means allow major updates to the next available, 2 means always stay one version behind the latest major release, and so on)*
  - `1`: Minor updates *(0 means no minor updates, 1 means allow minor updates to the next available, 2 means always stay one version behind the latest minor release, and so on)*
  - `1`: Patch updates *(0 means no patch updates, 1 means allow patch updates to the next available, 2 means always stay one version behind the latest patch release, and so on)*
  - `1`: Build updates *(0 means no build updates, 1 means allow build updates to the next available, 2 means always stay one version behind the latest build release, and so on)*
- `true`: Indicates that digest updates are allowed.

You can customize these rules for each container by specifying different patterns and update policies separated by spaces.

#### Basic Rule Example

```
update_rules=*[0.1.1-1,true] mycontainer[1.0.0-1,true] another[0.0.1-1,false] further[2.1.1-1,true]
```

> This example configuration means:
>
> - All containers are allowed to apply only minor, patch, build, and digest updates.
> - The container named `mycontainer` is allowed to apply major, build, and digest updates.
> - The container named `another` is allowed to apply only patch and build updates.
> - The container named `further` is allowed to apply build updates only when the latest release is two versions higher *(e.g., if Nextcloud releases version 29.0.0 and your Nextcloud is on version 27.0.0, an update to version 28.0.0 will be performed)*.

#### Precise Rule Examples

You can also create more specific rule sets that allow, for example, major updates for a container if at least one patch has been released for that major version.
In the rules, 'M' stands for Major, 'm' for Minor, 'p' for Patch, and 'b' for Build.

```
mycontainer[1&(p>1).1.1-1,true]
```

> This rule allows major updates for the container `mycontainer` if at least one patch version greater than 1 has been released for this major version.

```
mycontainer[0.1(b>2).1-1,true]
```

> This rule allows minor updates for the container `mycontainer` if the build version is greater than 2.

These precise rules provide granular control over the update behavior of specific containers based on various conditions such as patch versions, build versions, and more.

**Hint**: These rules do not affect the order in which updates are installed! An update is never skipped.

### Pre- and Post-Scripts

To give you more control, you can integrate pre- and post-scripts. These are created by default in the directories `/usr/local/etc/container_update/pre-scripts` and `/usr/local/etc/container_update/post-scripts`, and they must be named after the container. These are standard shell scripts that you can create and customize as needed. For example, you can create backups of databases, configuration files, etc., before updating a container, and make adjustments such as customized branding or changes to file permissions after the update. Essentially, you can tailor these scripts to your specific needs. The output of these scripts is redirected to the log located in `/var/log/container_update.log` by default, so you have all logs in one place.

### Notifications

#### E-Mail Notifications

To receive e-mail notifications, you need to install and configure Sendmail (as only Sendmail is supported).

#### Telegram Notifications

To receive Telegram notifications, you first need to obtain a Chat ID and a Bot Token, which you should enter in the configuration file.

## Having Trouble?
If you encounter any issues while executing this script, please provide the following information:
- A full log in debug mode *(ensure sensitive data is replaced)*
- A `docker container inspect` of one or more affected containers *(ensure sensitive data is replaced)*
- A `docker image inspect` of one or more images *(ensure sensitive data is replaced)*

---
