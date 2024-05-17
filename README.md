# Docker Container Auto-Update Script

🎉 This script is completely redesigned for enhanced performance, providing a better overview and more reliability. Crafted with lots of love and a touch of magic, this script makes your Docker life easier and more efficient.

## Features

- **Automated Container Updates**: Effortlessly update all your Docker containers on your host under your own conditions.
- **Smart Update Detection**: Automatically identifies Major, Minor, Patch, Build, and Digest updates.
- **Customizable Update Rules**: Define unique update behaviors for each container. For example, allow only digest updates for one container, patch updates for another, or even full major updates.
- **Conditional Updates**: Set conditions for major updates, such as requiring at least one patch version for the new major version to be released before updating.
- **Standard Update Sequence**: Updates follow the standard sequence: digest, build, patch, minor, and then major updates.
- **Backup and Rollback**: Backups of your containers are created before updates. If an update fails, the change is rolled back and the old container is restarted.
- **Email Notifications**: Stay informed with detailed email reports (requires sendmail to be installed and configured).
- **Pre- and Post-Scripts Integration**: Integrate your own pre- and post-scripts to perform actions such as backing up configuration files or databases before any update and making adjustments to the container configuration after any update.

Oh, and just a heads-up — I'm still just a script kiddy and can't be held responsible for any mishaps. That's why the default configuration has test mode enabled. Safety first!
After you've run your first test, checked for errors, and reviewed the Docker run commands, you can disable test mode in the configuration (see below).

## Installation

1. Download this script to your Docker host
2. Make it executable
3. Run it with root

## Configuration

The Docker Container Auto-Update script uses a configuration file, which is by default located at `/usr/local/etc/container_update/container_update.ini`. This file contains all the settings and parameters necessary for the script to run. You can customize the configuration file according to your requirements by editing it and entering the desired values.

| Section     | Parameter                                   | Description                                                                                                   | Default Value                                             | Possible Values                                           |
|-------------|---------------------------------------------|---------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------|
| general     | test_mode                                   | Enables or disables test mode                                                                                 | `true`                                                    | `true`, `false`                                           |
| general     | prune_images                                | Automatically prune unused images                                                                             | `true`                                                    | `true`, `false`                                           |
| general     | prune_container_backups                     | Automatically prune old container backups                                                                     | `true`                                                    | `true`, `false`                                           |
| general     | container_backups_retention                 | Number of days to retain container backups                                                                    | `7`                                                       | Any positive integer                                      |
| general     | container_backups_keep_last                 | Number of last container backups to keep regardless of retention time                                         | `1`                                                       | Any positive integer                                      |
| general     | container_update_validation_time            | Time in seconds to validate if a container runs successfully after an update                                  | `120`                                                     | Any positive integer                                      |
| general     | update_rules                                | Rules for updating containers (see detailed explanation below)                                                | `*[0.1.1-1,true]`                                         | Custom rules (seperated by space)                         |
| general     | docker_hub_api_url                          | URL for the Docker Hub API                                                                                    | `https://registry.hub.docker.com/v2`                      | Any valid URL                                             |
| general     | docker_hub_api_image_tags_page_size_limit   | Number of tags to fetch per page from Docker Hub                                                              | `100`                                                     | Positive integer (1-100)                                  |
| general     | docker_hub_api_image_tags_page_crawl_limit  | Number of pages to crawl for tags from Docker Hub                                                             | `10`                                                      | Any positive integer                                      |
| general     | pre_scripts_folder                          | Folder containing pre-update scripts                                                                          | `/usr/local/etc/container_update/pre-scripts`             | Any valid directory path                                  |
| general     | post_scripts_folder                         | Folder containing post-update scripts                                                                         | `/usr/local/etc/container_update/post-scripts`            | Any valid directory path                                  |
| paths       | tput                                        | Path to the `tput` command                                                                                    | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | gawk                                        | Path to the `gawk` command                                                                                    | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | cut                                         | Path to the `cut` command                                                                                     | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | docker                                      | Path to the `docker` command                                                                                  | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | grep                                        | Path to the `grep` command                                                                                    | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | jq                                          | Path to the `jq` command                                                                                      | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | sed                                         | Path to the `sed` command                                                                                     | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | wget                                        | Path to the `wget` command                                                                                    | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | sort                                        | Path to the `sort` command                                                                                    | *(automatically detected by script)*                      | Any valid file path                                       |
| paths       | sendmail                                    | Path to the `sendmail` command                                                                                | *(automatically detected by script)*                      | Any valid file path                                       |
| log         | filePath                                    | Path to the log file                                                                                          | `/var/log/container_update.log`                           | Any valid file path                                       |
| log         | level                                       | Log level                                                                                                     | `DEBUG`                                                   | `DEBUG`, `INFO`, `WARN`, `ERROR`                          |
| log         | retention                                   | Number of days to retain log file entries                                                                     | `7`                                                       | Any positive integer                                      |
| mail        | notifications_enabled                       | Enable or disable email notifications                                                                         | `false`                                                   | `true`, `false`                                           |
| mail        | mode                                        | Mode of sending emails  (currently only sendmail is supported)                                                | `sendmail`                                                | `sendmail`                                                |
| mail        | from                                        | Email address for sending notifications                                                                       |                                                           | Any valid email address                                   |
| mail        | recipients                                  | Comma-separated list of recipient email addresses                                                             |                                                           | Any valid email addresses (seperated by space)            |
| mail        | subject                                     | Subject of the notification email                                                                             | `Docker Container Update Report from <hostname>`          | Any valid string                                          |
---

### Update Rules

#### Basic Rules

The `update_rules` parameter allows you to define the update behavior for your containers. The default rule is `*[0.1.1-1,true]`, which means:

- `*`: Applies to all containers.
- `0.1.1-1`: Specifies the update policy, where each number represents:
  - `0`: Major updates (0 means no major updates, 1 means allow major updates to the next available, 2 means always stay one version behind the latest major release, and so on)
  - `1`: Minor updates (0 means no minor updates, 1 means allow minor updates to the next available, 2 means always stay one version behind the latest minor release, and so on)
  - `1`: Patch updates (0 means no patch updates, 1 means allow patch updates to the next available, 2 means always stay one version behind the latest patch release, and so on)
  - `1`: Build updates (0 means no build updates, 1 means allow build updates to the next available, 2 means always stay one version behind the latest build release, and so on)
- `true`: Indicates that digest updates are allowed.

You can customize these rules for each container by specifying different patterns and update policies separated by spaces.

##### Basic Rule Example 1

```
update_rules=*[0.1.1-1,true] mycontainer[1.0.0-1,true] another[0.0.1-1,false] further[2.1.1-1,true]
```

This example configuration means:

- All containers are allowed only minor, patch, build, and digest updates.
- The container named `mycontainer` is allowed to install major, build, and digest updates.
- The container named `another` is allowed to install only patch and build updates.
- The container named `further` is allowed to install build updates only when the latest release is two versions higher *(e.g., if Nextcloud releases version 29.0.0 and your Nextcloud is on version 27.0.0, an update to version 28.0.0 will be performed)*.

By configuring these rules, you can finely control how each container is updated according to your specific requirements.


#### More Precise Rules

You can also create more specific rule sets that allow, for example, major updates for a container if at least one patch has been released for that major version.

##### Precise Rule Examples

In the rules, 'M' stands for Major, 'm' for Minor, 'p' for Patch, and 'b' for Build.

```
mycontainer[1&(p>1).1.1-1,true]
```

This rule allows major updates for the container `mycontainer` if at least one patch version greater than 1 has been released for the major version.

```
mycontainer[0.1(b>2).1-1,true]
```

This rule allows minor updates for the container `mycontainer` if the build version is greater than 2.

These precise rules provide granular control over the update behavior of specific containers based on various conditions such as patch versions, build versions, and more.
