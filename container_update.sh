#!/bin/bash
#
# DOCKER CONTAINER UPDATER
# Automatic Docker Container Updater Script
#
# ## Version
# 2024.04.05-0
#
# ## Changelog
# 2024.04.05-0, janseppenrade2: Released.
# 2024.04.05-c, janseppenrade2: Removed test environment information from script.
# 2024.04.05-b, janseppenrade2: Added support for port bindings and capabilities like "NET_ADMIN" etc.
# 2024.04.05-a, janseppenrade2: Optimized logging.
# 2024.04.04-b, janseppenrade2: Released
# 2024.04.04-a, janseppenrade2: Fixed a bug allowing null values in some command parameters, causing an error in the execution of a Docker Run command.
# 2024.04.04-0, janseppenrade2: Resolved an issue that resulted in an empty mail report in case of any failed container update.
# 2024.02.13-0, janseppenrade2: Post-scripts will now be executed even after a failed container start/update.
# 2024.02.03-0, janseppenrade2: Added support for reading the output of sub-scripts (pre- and post-scripts).
# 2023.12.14-0, janseppenrade2: Released.
# 2023.11.22-d, janseppenrade2: Fixed a bug occurring when a Docker network name contains dots.
# 2023.11.22-c, janseppenrade2: Bugfix in the sendmail command (path variable was not provided).
# 2023.11.22-b, janseppenrade2: Optimized logging.
# 2023.11.22-a, janseppenrade2: Optimized email sending - A single email will now be sent for each recipient. Also, the variable for recipients is now an array.
# 2023.11.19-0, janseppenrade2: Overhauled variable description.
# 2023.11.18-c, janseppenrade2: Optimized email message.
# 2023.11.18-b, janseppenrade2: Added hint to notification mail in test mode.
# 2023.11.18-a, janseppenrade2: Bugfix with notification level.
# 2023.11.17-0, janseppenrade2: Optimized logging, added support for mail notifications via the sendmail command.
# 2023.11.16-0, janseppenrade2: Changed versioning.
# 2023.11.13-0, janseppenrade2: Various bug fixes, optimization of regex filter creation (create_regex_filter()), and improvements to major version recognition.
# 2023.11.08-0, janseppenrade2: Reduced timeout for test mode, various bug fixes.
# 2023.11.07-0, janseppenrade2: Bugfix in sorting list of available image tags from Docker Hub.
# 2023.10.26-0, janseppenrade2: Bugfix in container startup validation; Disabled image download in test mode.
# 2023.10.25-0, janseppenrade2: Bugfix in the order of Docker run parameters (tmpfs was misplaced); Added extended container startup validation; reduced value of $container_backups_retention_days from 14 to 7 as default.
# 2023.10.24-0, janseppenrade2: Added Tmpfs option.
# 2023.10.23-0, janseppenrade2: Improved regex filter creation (create_regex_filter()).
# 2023.10.21-1, janseppenrade2: Released.
# 2023.10.21-0, janseppenrade2: Renamed some variables and optimized their descriptions.
# 2023.10.18-0, janseppenrade2: Fixed a bug that prevented pruning Docker container backups.
# 2023.10.18-0, janseppenrade2: Fixed a bug that caused container updates even if there is no update available.
# 2023.10.17-1, janseppenrade2: Added possibility to prune containers.
# 2023.10.17-0, janseppenrade2: Several bug fixes.
# 2023.10.07-0, janseppenrade2: Created.
# 
# ## Description
# This script is designed to automate the process of updating running and paused Docker container images while preserving their configurations. It also provides the option to specify exceptions by listing container names in the `ignored_containers` variable.
# It's important to note that only inter-major updates are automated; major updates must be performed manually for security reasons. For example, if a container is running version 2.1.0, updates to versions 2.1.1 and 2.2.0 will be handled by this script. If an update to version 3.0.0 is available, the script will inform you in the logs but not handle this update.
# To run pre or post-installation scripts for specific containers, place these scripts in the same directory as `container_update.sh` and name them `container_update_post_script_<container_name>.sh` or `container_update_pre_script_<container_name>.sh`.
# To receive notifications by e-mail, Postfix must be installed and configured on the host, as this script uses the "sendmail" command to send e-mails.
# 
# ## How to use this script
# 1. Place this script in your Docker server's file system.
# 2. Make it executable with the command `chmod +x </path/to/container_update.sh>`.
# 3. For a fully automated experience, create a cron job to run this script periodically.
# 
# ## Hint
# For security reasons, this script is executed with enabled test mode by default. As soon as you review your log file created by this script after testing it on your system in "<scriptpath>\logs\container_update.sh.log", which I highly recommend(!), you can disable the test mode by editing the variable `test_mode`.
# 
# ## Customizable variables
# 
# | Variable                           | Description                                                                                                                                                                                                      | Example Values                                         |
# | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
# | `test_mode`                        | Determines whether the script runs in test mode to prevent unwanted system changes.                                                                                                                              | `true`/`false`                                         |
# | `docker_executable_path`           | Points to the location of the docker executable on your system.                                                                                                                                                  | `"/usr/bin/"`                                          |
# | `sendmail_executable_path`         | Points to the location of the sendmail executable on your system.                                                                                                                                                | `"/usr/sbin/"`                                         |
# | `ignored_containers`               | An array storing container names to be ignored by the script.                                                                                                                                                    | `("MyContainer1" "MyContainer2" "MyContainer3")`       |
# | `prune_images`                     | Specifies whether to prune Docker images after each execution.                                                                                                                                                   | `true`/`false`                                         |
# | `prune_container_backups`          | Determines whether to prune Docker container backups after each execution or not. The very last backup is always kept.                                                                                           | `true`/`false`                                         |
# | `container_backups_retention_days` | Specifies the number of days for retaining container backups. The very last backup is always kept, regardless of its age!                                                                                        | `7`                                                    |
# | `log_retention_days`               | Sets the number of days to keep log entries.                                                                                                                                                                     | `7`                                                    |
# | `checkContainerStateTimeout`       | The duration in seconds to wait before performing a one-time check to determine if a Docker container has been successfully started.                                                                             | `120`                                                  |
# | `mail_recipients`                  | An array storing the recipient's email addresses for notifications.                                                                                                                                              | `("notify@mydomain.com" "my.mail@gmail.com")`          |
# | `mail_subject`                     | Any subject for your notification mails.                                                                                                                                                                         | `"Docker Container Update Report from $(hostname)"`    |
# | `mail_from`                        | The from-address the notification mails will sent from.                                                                                                                                                          | `"notify@mydomain.com"`                                |
# | `mail_notification_level`          | Level 1 informs you about available major updates, even if no updates have been made by this script. Level 2 just informs abaout available updates only if other updates have been made by this script.          | `1`/`2`                                                |


# GLOBAL VARIABLES

    # FIXED VARIABLES (do not edit)
    datetime=$(date +%Y-%m-%d_%H-%M)                                        # This variable is used to create timestamps for log entries and other time-related operations. You don't need to customize this.
    scriptdir="$(dirname "$(readlink -f "$0")")"                            # This variable uses the `readlink` and `dirname` commands to determine the directory containing the script file. You don't need to customize this.
    logfile="$scriptdir/logs/`basename "$0"`.log"                           # This variable specifies the path to the log file. It combines the `scriptdir` with the name of the script file and appends a `.log` extension. Log entries generated by the script are written to this file. You can customize it to change the log file path.
    pidfile="$scriptdir/`basename "$0"`.pid"                                # This variable specifies the path to the PID (Process ID) file. It is used to store the Process ID of the currently running script instance, preventing multiple instances from running simultaneously.
    mail_message_file="$scriptdir/`basename "$0"`.msg"                      # This variable specifies the path to the temporary created mail message file.
    mail_report_available=false                                             # Used to generate a mail report. You don't need to customize this.
    mail_report_available_major_updates=""                                  # Used to generate a mail report. You don't need to customize this.
    mail_report_updated_to_new_image_tags=""                                # Used to generate a mail report. You don't need to customize this.
    mail_report_updated_to_new_image_digest=""                              # Used to generate a mail report. You don't need to customize this.
    mail_report_update_to_new_image_failed=""                               # Used to generate a mail report. You don't need to customize this.

    
    # CUSTOMIZABLE VARIABLES
    test_mode=true
    docker_executable_path="/usr/bin/"
    sendmail_executable_path="/usr/sbin/"
    ignored_containers=()
    prune_images=true
    prune_container_backups=true
    container_backups_retention_days=7
    log_retention_days=7
    checkContainerStateTimeout=120
    mail_from=""
    mail_recipients=()
    mail_subject="Docker Container Update Report from $(hostname)"
    mail_notification_level=1

###################################
###### HERE THE MAGIC BEGINS ######
###################################

# Determine if PID-File already exists
    sleep $((RANDOM % 20)) # Required for some QNAP NAS systems to prevent simultaneous executions triggered by cron.
    if test -f "$pidfile"; then
        echo -e "${color_red}$pidfile already exists. Exiting..."
        exit 0
    fi

# Indicate that this script is currently running
    echo $$ > "$pidfile"

# Creating logfile directory
    mkdir -p "$scriptdir/logs"

# Logging function
    WriteLog () {
        level=$1
        message=$2

        echo "[$(date +%Y/%m/%d\ %H:%M:%S)] ${level} ${message}" | tee -a "$logfile"
    }
    WriteLog "INFO" "Execution has been started"

# Function to quote strings
    quote() {
        local quoted="$1"
        echo "$quoted" | sed 's/"/\\"/g'
    }

# Function to add settings to the 'docker run' command
    add_setting() {
        local key="$1"
        local value="$2"
        if [ -n "$value" ]; then
            echo -n " -e $key=$(quote "$value")"
        fi
    }

# Function to replace numbers in a string with matching regex patterns
    create_regex_filter() {
        local input="$1"
        local regex_filter=""

        for ((i=0; i<${#input}; i++)); do
            char="${input:$i:1}"
            
            if [[ "$char" =~ [0-9] ]]; then
                if [[ "$last_char_type" != "integer" ]]; then
                    regex_filter="${regex_filter}[0-9]+"
                    last_char_type="integer"
                fi
            else
                regex_filter="${regex_filter}${char}"
                last_char_type="string"
            fi
        done
        
        echo "^$regex_filter$"
    }

# Informing about test mode
    if [ "$test_mode" == true ]; then
        WriteLog "INFO" "Test mode is enabled. No changes will be made to your system."
        sleep 5
    fi

if ! command -v "${docker_executable_path}docker" &> /dev/null; then
    WriteLog "ERROR" "Command \"${docker_executable_path}docker\" could not be found. Exiting..."
else
    # Getting docker container IDs
        container_ids=($(docker ps -q))

    # Computing docker containers - one by one
        for container_id in "${container_ids[@]}"; do
            docker_run_cmd="${docker_executable_path}docker run -d"
            filtered_image_tags_docker_hub=()
            ignored=false
            image_RepoDigest_docker_hub=""
            image_same_version_update_available=true
            image_tag_major_version_docker_hub=""
            image_tag=""
            image_tags_sorted_docker_hub=()
            image_tags=()
            regex_filter=""

            WriteLog "INFO" "Processing container $container_id"
            WriteLog "INFO" "  Requesting configuration details of $container_id"
                container_config=$(${docker_executable_path}docker inspect "$container_id")

                # ImageID
                    #image_id=$(echo "$container_config" | jq -r '.[0].Image' | sed 's#^/##' | awk -F: '{print $2}' | cut -c 0-12)
                    image_id=$(echo "$container_config" | jq -r '.[0].Image' | sed 's#^/##' | awk -F: '{print $2}' | cut -b 1-13)

                # Name
                    name=$(echo "$container_config" | jq -r '.[0].Name' | sed 's#^/##')
                    if [ -n "$name" ] && [ "$name" != "null" ]; then
                        docker_run_cmd+=" --name=$(quote "$name")"
                    fi

                # Hostname
                    hostname=$(echo "$container_config" | jq -r '.[0].Config.Hostname')
                    if [ -n "$hostname" ] && [ "$hostname" != "null" ]; then
                        docker_run_cmd+=" --hostname=$(quote "$hostname")"
                    fi

                # Capabilities
                    capabilities=$(echo "$container_config" | jq -r '.[0].HostConfig.CapAdd')
                    capabilities_count=$(echo "$capabilities" | jq '. | length')
                    if [ "$capabilities_count" -gt 0 ] && [ -n "$capabilities_count" ]; then
                        for ((i = 0; i < capabilities_count; i++)); do
                            capability_name=$(echo "$capabilities" | jq -r ".[$i]")
                            docker_run_cmd+=" --cap-add=$capability_name"
                        done
                    fi

                # Get the network mode
                    network=$(echo "$container_config" | jq -r '.[0].HostConfig.NetworkMode')
                    if [ "$network" != "default" ] && [ "$network" != "null" ]; then
                        docker_run_cmd+=" --network=$(quote "$network")"
                    fi

                # Get the restart policy
                    restart_policy=$(echo "$container_config" | jq -r '.[0].HostConfig.RestartPolicy.Name')
                    if [ "$restart_policy" != "no" ] && [ "$restart_policy" != "null" ]; then
                        docker_run_cmd+=" --restart=$restart_policy"
                    fi

                # PublishAllPorts
                    PublishAllPorts=$(echo "$container_config" | jq -r '.[0].HostConfig.PublishAllPorts')
                    if [ "$PublishAllPorts" != "false" ]; then
                        docker_run_cmd+=" --publish-all"
                    fi

                # Port Bindings
                    PortBindings=$(echo "$container_config" | jq -r '.[0].HostConfig.PortBindings')
                    PortBindings_count=$(echo "$PortBindings" | jq '. | length')
                    if [ "$PortBindings_count" -gt 0 ] && [ -n "$PortBindings_count" ]; then
                        for ((i = 0; i < PortBindings_count; i++)); do
                            host_port_key_name=$(echo "$PortBindings" | jq -r ". | keys_unsorted | .[$i]")
                            if [[ $host_port_key_name == */* ]]; then
                                host_port=$(echo "$host_port_key_name" | cut -d'/' -f1)
                                protocol=$(echo "$host_port_key_name" | cut -d'/' -f2)
                            else
                                host_port=$host_port_key_name
                                protocol=""
                            fi
                            container_port=$(echo "$PortBindings" | jq -r ".[\"$host_port_key_name\"][0].HostPort")
                            docker_run_cmd+=" -p $container_port:$host_port"
                        done
                    fi

                # Mac address
                    mac_address=$(echo "$container_config" | jq -r '.[0].Config.MacAddress')
                    if [ -n "$mac_address" ] && [ "$mac_address" != "null" ]; then
                        docker_run_cmd+=" --mac-address=$mac_address"
                    fi

                # IPv4 address
                    ipv4_address=$(echo "$container_config" | jq -r ".[0].NetworkSettings.Networks[\"$network\"].IPAMConfig.IPv4Address")
                    if [ -n "$ipv4_address" ] && [ "$ipv4_address" != "null" ]; then
                        docker_run_cmd+=" --ip=$ipv4_address"
                    fi

                # IPv6 address
                    ipv6_address=$(echo "$container_config" | jq -r ".[0].NetworkSettings.Networks[\"$network\"].IPAMConfig.IPv6Address")
                    if [ -n "$ipv6_address" ] && [ "$ipv6_address" != "null" ]; then
                        docker_run_cmd+=" --ip6=$ipv6_address"
                    fi

                # Mounts
                    mounts=$(echo "$container_config" | jq -r '.[0].HostConfig.Mounts')
                    mounts_count=$(echo "$mounts" | jq '. | length')
                    for ((i = 0; i < mounts_count; i++)); do
                        type=$(echo "$mounts" | jq -r ".[$i].Type")
                        source=$(echo "$mounts" | jq -r ".[$i].Source" | sed 's/ /\\ /g')
                        target=$(echo "$mounts" | jq -r ".[$i].Target" | sed 's/ /\\ /g')
                        docker_run_cmd+=" --mount type=$type,source=$source,target=$target"
                    done

                # Environment variables
                    env_vars=$(echo "$container_config" | jq -r '.[0].Config.Env')
                    env_vars_count=$(echo "$env_vars" | jq '. | length')
                    for ((i = 0; i < env_vars_count; i++)); do
                        env_var=$(echo "$env_vars" | jq -r ".[$i]")
                        var_name="${env_var%%=*}"
                        var_value="${env_var#*=}"
                        
                        if [ "$var_name" = "PATH" ]; then
                            break
                        fi

                        docker_run_cmd+=" -e $var_name='$var_value'"
                    done

                # Tmpfs
                    if [[ -n $(echo "$container_config" | jq -r '.[0].HostConfig.Tmpfs') && $(echo "$container_config" | jq -r '.[0].HostConfig.Tmpfs') != "null" ]]; then
                        IFS=''
                        tmpfs_values=($(echo "$container_config" | jq -r '.[0].HostConfig.Tmpfs | to_entries[] | .key + ":" + .value'))
                        for value in "${tmpfs_values[@]}"; do
                            docker_run_cmd+=" --tmpfs $value"
                        done
                    fi

                # The image name on which the container is based
                    image_name=$(echo "$container_config" | jq -r '.[0].Config.Image' | cut -d':' -f1)
                    docker_run_cmd+=" $image_name"
                    
                # RepoDigests
                    #image_RepoDigest=$(docker image inspect -f '{{.RepoDigests}}' ${image_id} | awk -F: '{print $2}' | sed 's/]//') # Not working with multi values
                    image_RepoDigest=$(docker image inspect -f '{{.RepoDigests}}' ${image_id} | tr ' ' ',' | sed 's/\[\|\]//g' | sed 's#'"$image_name"'@sha256:##g') # This writes single and multi values to the variable

                # The image tag on which the container is based
                    image_tag=$(echo "$container_config" | jq -r '.[0].Config.Image' | cut -d':' -f2)

                # The major version of the image given in the image tag
                    image_tag_major_version=$(echo $image_tag | cut -d'.' -f1 | cut -d'-' -f1)
                
                # Pause State
                    state_paused=$(echo "$container_config" | jq -r '.[0].State.Paused' | sed 's#^/##')

                # Check if container is in the ignore list
                    for container_name in "${ignored_containers[@]}"; do
                        if [ "$container_name" = "$name" ]; then
                            ignored=true
                            WriteLog "INFO" "  Container $container_id ($name) is listed in ignore list. Skipping."
                        fi
                    done

                # Searching for available updates within the same major version given in image tag and starting installation process
                    if [ "$ignored" != true ]; then
                        WriteLog "INFO" "    Container name: $name"
                        WriteLog "INFO" "    Currently used image ID: $image_id"
                        WriteLog "INFO" "    Currently used image repo digest(s) (sha256): $image_RepoDigest"
                        WriteLog "INFO" "    Currently used image name: $image_name"
                        WriteLog "INFO" "    Currently used image tag/version: $image_tag"
                        WriteLog "INFO" "    Currently used image major version: $image_tag_major_version"

                        WriteLog "INFO" "  Requesting available image tags..."
                            # Getting a list of available image tags, sorted by version number (decresing)
                                regex_filter=$(create_regex_filter "$image_tag")
                                for page in {0..10}
                                do
                                    if [[ $image_name == *'/'* ]]; then
                                        # image_tags+=( $(wget -q "https://registry.hub.docker.com/v2/repositories/${image_name}/tags?page=${page}" -O - | jq -r '.results[].name' | grep -E '^[0-9.]+$' ) )
                                        image_tags+=( $(wget -q "https://registry.hub.docker.com/v2/repositories/${image_name}/tags?page=${page}" -O - | jq -r '.results[].name' | grep -E "^$regex_filter$" ) )
                                    else
                                        # image_tags+=( $(wget -q "https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags?page=${page}" -O - | jq -r '.results[].name' | grep -E '^[0-9.]+$' ) )
                                        image_tags+=( $(wget -q "https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags?page=${page}" -O - | jq -r '.results[].name' | grep -E "^$regex_filter$" ) )
                                    fi
                                done

                                # Sorting elements
                                    image_tags_sorted_docker_hub=($(printf "%s\n" "${image_tags[@]}" | tr '.' '\t' | sort -rnuk1,1 -k2,2 -k3,3 | tr '\t' '.' | head -n 1))

                            # Getting a list of image tags filtered by currently used major version given in the currently used image tag
                                for image_tag_docker_hub in "${image_tags_sorted_docker_hub[@]}"
                                do
                                    image_tag_major_version_docker_hub=$(echo "$image_tag_docker_hub" | cut -d'.' -f1 | cut -d'-' -f1)
                                    if [ "$image_tag_major_version_docker_hub" == "$image_tag_major_version" ]; then
                                        filtered_image_tags_docker_hub+=("$image_tag_docker_hub")
                                    fi
                                done

                        WriteLog "INFO" "  Comparing currently used image tag with latest available on docker hub..."
                            if [ -n "${image_tags_sorted_docker_hub[0]}" ]; then
                                image_tag_major_version_docker_hub=$(echo "${image_tags_sorted_docker_hub[0]}" | cut -d'.' -f1 | cut -d'-' -f1)
                                if [[ $image_tag_major_version_docker_hub == $image_tag_major_version ]]; then
                                    major_version_update_available=false
                                    WriteLog "INFO" "    There is no new major version available for ${image_name}. (Local:$image_tag_major_version == Online:$image_tag_major_version_docker_hub)"
                                else
                                    inter_major_version_update_available=true
                                    if [[ $mail_notification_level == 1 ]]; then
                                        mail_report_available=true
                                    fi
                                    mail_report_available_major_updates+="<li>$name ($image_name): Current major version is $image_tag_major_version; the latest available is $image_tag_major_version_docker_hub</li>"
                                    WriteLog "INFO" "    There is a new major version available for ${image_name}. This needs to be updated manually. (Local:$image_tag_major_version <> Online:$image_tag_major_version_docker_hub)"
                                fi
                            else
                                major_version_update_available=false
                                WriteLog "INFO" "    No online image tags found."
                            fi

                        WriteLog "INFO" "  Comparing currently used image tag with latest available on docker hub within the same major version ($image_tag_major_version)..."
                            if [ -n "${filtered_image_tags_docker_hub[0]}" ]; then
                                if [[ ${filtered_image_tags_docker_hub[0]} == $image_tag ]]; then
                                    inter_major_version_update_available=false
                                    WriteLog "INFO" "    Currently used image tag is up to date. Nothing to do. (Local:$image_tag == Online:${filtered_image_tags_docker_hub[0]})"
                                else
                                    inter_major_version_update_available=true
                                    mail_report_available=true
                                    WriteLog "INFO" "    Currently used image tag is outdated and needs to be updated. (Local:$image_tag <> Online:${filtered_image_tags_docker_hub[0]})"
                                fi
                            else
                                inter_major_version_update_available=false
                                WriteLog "INFO" "    No online image tags found."
                            fi

                        WriteLog "INFO" "  Comparing currently used image digest with latest available on docker hub..."
                            if [[ $image_name == *'/'* ]]; then
                                # image_RepoDigest_docker_hub=$(curl -s "https://registry.hub.docker.com/v2/repositories/${image_name}/tags/${image_tag}" | jq -r '.digest, .images[].digest' | awk -F: '{print $2}' | tr '\n' ',')
                                image_RepoDigest_docker_hub=$(curl -s "https://registry.hub.docker.com/v2/repositories/${image_name}/tags/${image_tag}" | jq -r '.digest' | awk -F: '{print $2}')
                            else
                                # image_RepoDigest_docker_hub=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags/${image_tag}" | jq -r '.digest, .images[].digest' | awk -F: '{print $2}' | tr '\n' ',')
                                image_RepoDigest_docker_hub=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags/${image_tag}" | jq -r '.digest' | awk -F: '{print $2}')
                            fi

                            if [ -n "$image_RepoDigest_docker_hub" ] && [ "$image_RepoDigest_docker_hub" != "" ]; then
                                IFS=','
                                read -ra image_RepoDigest_values <<< "$image_RepoDigest"

                                for image_RepoDigest_value in "${image_RepoDigest_values[@]}"; do
                                    if [[ $image_RepoDigest_docker_hub == $image_RepoDigest_value ]]; then
                                        image_same_version_update_available=false
                                        WriteLog "INFO" "    Currently used image is up to date. Nothing to do. (Local:$image_RepoDigest_value == Online:$image_RepoDigest_docker_hub)"
                                        break
                                    fi
                                done

                                if [[ "$image_same_version_update_available" == true ]]; then
                                    mail_report_available=true
                                    WriteLog "INFO" "    Currently used image is outdated and needs to be updated. (Local:$image_RepoDigest <> Online:$image_RepoDigest_docker_hub)"
                                fi
                            else
                                image_same_version_update_available=false
                                WriteLog "INFO" "    No digest found for $image_name:$image_tag."
                            fi

                        if [ "$inter_major_version_update_available" == true ]; then
                            
                            if [ -n "${filtered_image_tags_docker_hub[0]}" ]; then
                                docker_run_cmd+=":${filtered_image_tags_docker_hub[0]}"

                                WriteLog "INFO" "  Pulling new image (${filtered_image_tags_docker_hub[0]})..."
                                    if [ "$test_mode" == false ]; then
                                        ${docker_executable_path}docker pull ${image_name}:${filtered_image_tags_docker_hub[0]}
                                        exitCode=$?
                                    else
                                        exitCode=0
                                    fi

                                    if [ $? -eq 0 ]; then
                                        WriteLog "INFO" "    Image successfully pulled"
                                        
                                        script="$scriptdir/container_update_pre_script_$name.sh"
                                        if [ -e "$script" ]; then
                                            WriteLog "INFO" "  Executing pre script $script..."
                                                if [ "$test_mode" == false ]; then
                                                    chmod +x "$script"
                                                    while IFS= read -r line; do
                                                        WriteLog "INFO" "    Output of \"$script\": $line"
                                                    done < <("$script")
                                                fi
                                        fi
                                        
                                        WriteLog "INFO" "  Renaming old instance..."
                                            if [ "$test_mode" == false ]; then
                                                ${docker_executable_path}docker rename ${name} ${name}_bak_${datetime}
                                            fi

                                        WriteLog "INFO" "  Stopping old instance..."
                                            if [ "$test_mode" == false ]; then
                                                ${docker_executable_path}docker stop ${name}_bak_${datetime}
                                            fi

                                        WriteLog "INFO" "  Disabling automatic startup for old instance..."
                                            if [ "$test_mode" == false ]; then
                                                ${docker_executable_path}docker update ${name}_bak_${datetime} --restart no
                                            fi

                                        WriteLog "INFO" "  Executing docker command: $docker_run_cmd"
                                            if [ "$test_mode" == false ]; then
                                                containerStartupError=false
                                                eval "$docker_run_cmd"
                                                if [ $? -ne 0 ]; then
                                                    mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                                    WriteLog "ERROR" "  failed to start docker container."
                                                    containerStartupError=true
                                                else
                                                    WriteLog "INFO" "  Waiting for the duration of $checkContainerStateTimeout seconds to validate the state of $name..."
                                                        sleep $((checkContainerStateTimeout + 2))

                                                    WriteLog "INFO" "  Checking if $name has been started..."
                                                        if docker ps -a --format "{{.Names}}" | grep -wq "$name"; then
                                                            container_start_time=$(echo $(docker inspect --format '{{.State.StartedAt}}' $name) | sed 's/T/ /;s/\..*Z//')
                                                            container_start_seconds=$(date -d "$container_start_time" +%s)
                                                            current_time=$(date -u "+%Y-%m-%d %H:%M:%S")
                                                            current_time_seconds=$(date -d "$current_time" +%s)
                                                            elapsed_time=$((current_time_seconds - container_start_seconds))
                                                            if [ "$elapsed_time" -gt "$checkContainerStateTimeout" ]; then
                                                                mail_report_updated_to_new_image_tags+="<li>$name ($image_name) has been updated from $image_tag to ${filtered_image_tags_docker_hub[0]}</li>"
                                                                WriteLog "INFO" "    The container $name has been started since $elapsed_time seconds. This assumes everything worked well during the startup."
                                                            else
                                                                mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                                                WriteLog "ERROR" "    The container $name has been started since just $elapsed_time seconds. This assumes something went wrong during the startup."
                                                                containerStartupError=true
                                                            fi
                                                        else
                                                            mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                                            WriteLog "ERROR" "    The container $name does not exist."
                                                            containerStartupError=true
                                                        fi
                                                fi

                                                if [ "$containerStartupError" == true ]; then
                                                    WriteLog "WARN" "  Rolling back changes..."
                                                        WriteLog "INFO" "    Stopping new container"
                                                            ${docker_executable_path}docker stop ${name}
                                                        WriteLog "INFO" "    Removing new container"
                                                            ${docker_executable_path}docker rm -fv ${name}
                                                        WriteLog "INFO" "    Restoring start up policy..."
                                                            ${docker_executable_path}docker update $container_id --restart $restart_policy
                                                        WriteLog "INFO" "    Renaming old instance back to it's original name..."
                                                            ${docker_executable_path}docker rename $container_id ${name}
                                                        WriteLog "INFO" "    Starting old instance..."
                                                            ${docker_executable_path}docker start $container_id

                                                    script="$scriptdir/container_update_post_script_$name.sh"
                                                    if [ -e "$script" ]; then
                                                        WriteLog "INFO" "  Executing post script $script..."
                                                            if [ "$test_mode" == false ]; then
                                                                chmod +x "$script"
                                                                while IFS= read -r line; do
                                                                    WriteLog "INFO" "    Output of \"$script\": $line"
                                                                done < <("$script")
                                                            fi
                                                    fi
                                                else
                                                    script="$scriptdir/container_update_post_script_$name.sh"
                                                    if [ -e "$script" ]; then
                                                        WriteLog "INFO" "  Executing post script $script..."
                                                            if [ "$test_mode" == false ]; then
                                                                chmod +x "$script"
                                                                while IFS= read -r line; do
                                                                    WriteLog "INFO" "    Output of \"$script\": $line"
                                                                done < <("$script")
                                                            fi
                                                    fi
                                                fi
                                            fi
                                    else
                                        mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                        WriteLog "ERROR" "    Failed to pull image."
                                    fi

                                    if [ "$state_paused" == "true" ]; then
                                        WriteLog "INFO" "  Pausing docker container..."
                                            ${docker_executable_path}docker pause $name
                                    fi
                            else
                                mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                WriteLog "ERROR" "  Got no image tag for $image_name. Skipping..."
                            fi
                        elif [ "$image_same_version_update_available" == true ]; then

                            if [ -n "$image_tag" ]; then
                                docker_run_cmd+=":$image_tag"

                                WriteLog "INFO" "  Pulling new image ($image_tag)..."
                                    if [ "$test_mode" == false ]; then
                                        ${docker_executable_path}docker pull $image_name:$image_tag
                                        exitCode=$?
                                    else
                                        exitCode=0
                                    fi

                                    if [ $? -eq 0 ]; then
                                        WriteLog "INFO" "    Image successfully pulled"
                                        
                                        script="$scriptdir/container_update_pre_script_$name.sh"
                                        if [ -e "$script" ]; then
                                            WriteLog "INFO" "  Executing pre script $script..."
                                                if [ "$test_mode" == false ]; then
                                                    chmod +x "$script"
                                                    while IFS= read -r line; do
                                                        WriteLog "INFO" "    Output of \"$script\": $line"
                                                    done < <("$script")
                                                fi
                                        fi

                                        WriteLog "INFO" "  Renaming old instance..."
                                            if [ "$test_mode" == false ]; then
                                                ${docker_executable_path}docker rename ${name} ${name}_bak_${datetime}
                                            fi

                                        WriteLog "INFO" "  Stopping old instance..."
                                            if [ "$test_mode" == false ]; then
                                                ${docker_executable_path}docker stop ${name}_bak_${datetime}
                                            fi

                                        WriteLog "INFO" "  Disabling automatic startup for old instance..."
                                            if [ "$test_mode" == false ]; then
                                                ${docker_executable_path}docker update ${name}_bak_${datetime} --restart no
                                            fi

                                        WriteLog "INFO" "  Executing docker command: $docker_run_cmd"
                                            if [ "$test_mode" == false ]; then
                                                containerStartupError=false
                                                eval "$docker_run_cmd"
                                                if [ $? -ne 0 ]; then
                                                    WriteLog "ERROR" "  failed to start docker container."
                                                    containerStartupError=true
                                                else
                                                    WriteLog "INFO" "  Waiting for the duration of $checkContainerStateTimeout seconds to validate the state of $name..."
                                                        sleep $((checkContainerStateTimeout + 2))

                                                    WriteLog "INFO" "  Checking if $name has been started..."
                                                        if docker ps -a --format "{{.Names}}" | grep -wq "$name"; then
                                                            container_start_time=$(echo $(docker inspect --format '{{.State.StartedAt}}' $name) | sed 's/T/ /;s/\..*Z//')
                                                            container_start_seconds=$(date -d "$container_start_time" +%s)
                                                            current_time=$(date -u "+%Y-%m-%d %H:%M:%S")
                                                            current_time_seconds=$(date -d "$current_time" +%s)
                                                            elapsed_time=$((current_time_seconds - container_start_seconds))
                                                            if [ "$elapsed_time" -gt "$checkContainerStateTimeout" ]; then
                                                                mail_report_updated_to_new_image_digest+="<li>$name ($image_name):$image_tag has been updated from $image_RepoDigest to $image_RepoDigest_docker_hub</li>"
                                                                WriteLog "INFO" "    The container $name has been started since $elapsed_time seconds. This assumes everything worked well during the startup."
                                                            else
                                                                mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                                                WriteLog "ERROR" "    The container $name has been started since just $elapsed_time seconds. This assumes something went wrong during the startup."
                                                                containerStartupError=true
                                                            fi
                                                        else
                                                            mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                                            WriteLog "ERROR" "    The container $name does not exist."
                                                            containerStartupError=true
                                                        fi
                                                fi

                                                if [ "$containerStartupError" == true ]; then
                                                    WriteLog "ERROR" "  Rolling back changes..."
                                                        WriteLog "INFO" "    Stopping new container"
                                                            ${docker_executable_path}docker stop ${name}
                                                        WriteLog "INFO" "    Removing new container"
                                                            ${docker_executable_path}docker rm -fv ${name}
                                                        WriteLog "INFO" "    Restoring start up policy..."
                                                            ${docker_executable_path}docker update $container_id --restart $restart_policy
                                                        WriteLog "INFO" "    Renaming old instance back to it's original name..."
                                                            ${docker_executable_path}docker rename $container_id ${name}
                                                        WriteLog "INFO" "    Starting old instance..."
                                                            ${docker_executable_path}docker start $container_id

                                                    script="$scriptdir/container_update_post_script_$name.sh"
                                                    if [ -e "$script" ]; then
                                                        WriteLog "INFO" "  Executing post script $script..."
                                                            if [ "$test_mode" == false ]; then
                                                                chmod +x "$script"
                                                                while IFS= read -r line; do
                                                                    WriteLog "INFO" "    Output of \"$script\": $line"
                                                                done < <("$script")
                                                            fi
                                                    fi
                                                else
                                                    script="$scriptdir/container_update_post_script_$name.sh"
                                                    if [ -e "$script" ]; then
                                                        WriteLog "INFO" "  Executing post script $script..."
                                                            if [ "$test_mode" == false ]; then
                                                                chmod +x "$script"
                                                                while IFS= read -r line; do
                                                                    WriteLog "INFO" "    Output of \"$script\": $line"
                                                                done < <("$script")
                                                            fi
                                                    fi
                                                fi
                                            fi
                                    else
                                        mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                        WriteLog "ERROR" "    Failed to pull image."
                                    fi

                                    if [ "$state_paused" == "true" ]; then
                                        WriteLog "INFO" "  Pausing docker container..."
                                            ${docker_executable_path}docker pause $name
                                    fi
                            else
                                mail_report_update_to_new_image_failed+="<li>$name ($image_name)</li>"
                                WriteLog "ERROR" "  Got no image tag for $image_name. Skipping..."
                            fi
                            
                        fi
                    fi
        done

    # Pruning docker container backups
        if [ "$prune_container_backups" == true ]; then
            WriteLog "INFO" "Pruning container backups older than $container_backups_retention_days days..."
                docker ps -a --format "{{.Names}}" | sort | while read -r container_name; do
                    if [[ "$container_name" == *_bak_* && -z "$(${docker_executable_path}docker ps -q -f name=$container_name)" ]]; then
                        instance_name=$(echo $container_name | sed 's/_bak_.*//')
                        backup_date=$(echo $container_name | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
                        backup_count=$(${docker_executable_path}docker ps -a --filter "name=^${instance_name}_bak_" --filter "status=exited" --format '{{.Names}}' | wc -l)

                        WriteLog "INFO" "  Instance name: $instance_name"
                        WriteLog "INFO" "    Container name:    $container_name"
                        WriteLog "INFO" "    Backup date:       $backup_date"
                        WriteLog "INFO" "    Available backups: $backup_count"

                        if [[ "$backup_date" != "" && "$backup_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && "$backup_count" -gt 1 ]]; then
                            backup_timestamp=$(date -d "$backup_date" +%s)
                            current_timestamp=$(date +%s)
                            days_diff=$(( (current_timestamp - backup_timestamp) / 86400 ))
                            if [ $days_diff -ge $container_backups_retention_days ]; then
                                WriteLog "INFO" "    Removing backed up container $container_name..."
                                    if [ "$test_mode" == false ]; then
                                        ${docker_executable_path}docker rm -fv $container_name
                                    fi
                            else
                                WriteLog "INFO" "    The removal of this container backup is skipped as it is less than $container_backups_retention_days days old."
                            fi
                        else
                            if [[ "$backup_date" == "" ]]; then
                                WriteLog "ERROR" "    No backup date found in containers name."
                            elif ! [[ "$backup_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                                WriteLog "ERROR" "    Backup date given in containers name is invalid. ($backup_date)"
                            elif ! [[ "$backup_count" -gt 1 ]]; then
                                WriteLog "INFO" "    Removing this container backup is prohibited as it is currently the last available one."
                            fi
                        fi
                    fi
                done
        fi

    # Pruning docker images
        if [ "$test_mode" == false ] && [ "$prune_images" == true ]; then
            WriteLog "INFO" "Pruning images..."
                ${docker_executable_path}docker image prune -af
        fi
fi

# Sending mail summary
    if [[ "$mail_report_available" == true && -n "$mail_from" && -n "$mail_recipients" && -n "$mail_subject" ]] || [ "$test_mode" == true ]; then

            for mail_recipient in "${mail_recipients[@]}"; do

                WriteLog "INFO" "Generating HTML email for recipient \"$mail_recipient\"..."
            
                mail_message="From: $mail_from\n"
                mail_message+="To: $mail_recipient\n"
                mail_message+="Subject: $mail_subject\n"
                mail_message+="MIME-Version: 1.0\n"
                mail_message+="Content-Type: text/html; charset=UTF-8\n"
                mail_message+="\n"
                mail_message+="<html>\n"
                    mail_message+="<body>\n"
                        mail_message+="<p>Ahoi Captain.</p>\n"
                        mail_message+="<p> </p>\n"
                        if [ -n "$mail_report_available_major_updates" ]; then
                            mail_message+="<p>This email is to notify you of recent changes and available updates for your Docker containers.</p>\n"
                        else
                            mail_message+="<p>This email is to notify you of recent changes for your Docker containers.</p>\n"
                        fi
                        mail_message+="<p> </p>\n"
                        mail_message+="<div style=\"border: 1px solid #ccc; padding: 15px;\">\n"
                            mail_message+="<p style=\"font-size: 16px;\"><strong>Docker Container Update Report</strong></p>\n"

                            if [ "$test_mode" == true ]; then
                                mail_message+="<p style=\"font-size: 12px;\"><strong>This was just a test. No changes have been made to your system.</strong></p>\n"
                            fi

                            if [ -n "$mail_report_updated_to_new_image_tags" ]; then
                                mail_message+="<p style=\"font-size: 12px;\"><strong>The following containers/images have been updated to a new image tag:</strong></p>\n"
                                mail_message+="<ul style=\"font-size: 11px;\">"
                                    mail_message+="$mail_report_updated_to_new_image_tags"
                                mail_message+="</ul>"
                                mail_message+="\n"
                            fi

                            if [ -n "$mail_report_updated_to_new_image_digest" ]; then
                                mail_message+="<p style=\"font-size: 12px;\"><strong>The following containers/images have been updated while keeping their originally image tag:</strong></p>\n"
                                mail_message+="<ul style=\"font-size: 11px;\">"
                                    mail_message+="$mail_report_updated_to_new_image_digest"
                                mail_message+="</ul>"
                                mail_message+="\n"
                            fi

                            if [ -n "$mail_report_update_to_new_image_failed" ]; then
                                mail_message+="<p style=\"font-size: 12px;\"><strong>The following container/image updates were <span style=\"color: red;\">unsuccessful</span>:</strong></p>\n"
                                mail_message+="<ul style=\"font-size: 11px;\">"
                                    mail_message+="$mail_report_update_to_new_image_failed"
                                mail_message+="</ul>"
                                mail_message+="\n"
                            fi

                            if [ -n "$mail_report_available_major_updates" ]; then
                                mail_message+="<p style=\"font-size: 12px;\"><strong>Major updates are available for manual installation on the following containers/images:</strong></p>\n"
                                mail_message+="<ul style=\"font-size: 11px;\">"
                                    mail_message+="$mail_report_available_major_updates"
                                mail_message+="</ul>"
                                mail_message+="\n"
                            fi
                        mail_message+="</div>\n"
                        mail_message+="<p> </p>\n"
                        mail_message+="\n"
                        mail_message+="<p style=\"font-size: 8px;\"><i>For further information, please have a look into the provided log located in \"$logfile\". If you prefer not to receive these emails, please customize \"$scriptdir/`basename "$0"`\" according to your specific requirements.</i></p>"
                        mail_message+="<p> </p>\n"
                        mail_message+="<p>Best regards.</p>"
                        mail_message+="\n"
                    mail_message+="</body>\n"
                mail_message+="</html>\n"

                WriteLog "INFO" "Saving generated HTML email to \"$mail_message_file\"..."
                    echo -e $mail_message > $mail_message_file
                    
                if command -v "${sendmail_executable_path}sendmail" &> /dev/null; then
                    WriteLog "INFO" "Fireing sendmail command \"${sendmail_executable_path}sendmail -t < $mail_message_file\"..."
                        ${sendmail_executable_path}sendmail -t < $mail_message_file
                else
                    WriteLog "ERROR" "Command \"${sendmail_executable_path}sendmail\" could not be found. Sending email report skipped."
                fi

                if [ "$test_mode" == false ]; then
                    WriteLog "INFO" "Deleting generated HTML email from \"$mail_message_file\"..."
                        rm -f $mail_message_file
                fi
            done
    fi

# Truncating log file
    current_time=$(date +%s)
    # Reading first line of file and skip truncate if its not older than $log_retention_days to reduce time consumption and cpu utilization
    timestamp=$(echo "$(head -n 1 "$logfile")" | awk -F'[][]' '{print $2}')
    timestamp_seconds=$(date -d "$timestamp" +%s)
    difference=$(( (current_time - timestamp_seconds) / 86400 ))
    #echo "[$timestamp] - Difference: $difference days"
    if (( $difference > $log_retention_days )); then
        WriteLog "INFO" "Truncating log file (removing entries older than $log_retention_days days)..."
        while IFS= read -r line; do
            timestamp=$(echo "$line" | awk -F'[][]' '{print $2}')
            timestamp_seconds=$(date -d "$timestamp" +%s)
            difference=$(( (current_time - timestamp_seconds) / 86400 ))
            #echo "[$timestamp] - Difference: $difference days"
            if (( $difference < $log_retention_days )); then
                echo $line >> "$logfile.truncated"
            fi
        done < "$logfile"
        rm -f "$logfile"
        mv "$logfile.truncated" "$logfile"
    fi

# Finalize
    rm "$pidfile"
    WriteLog "INFO" "Execution has been ended properly"
