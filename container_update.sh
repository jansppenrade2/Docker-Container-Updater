#!/bin/bash
#
#  Docker Container Updater
#
#  VERSION
#  2023.11.13-0
#
#  CHANGELOG
#  2023.11.16-0, janseppenrade2: Changed versioning
#  2023.11.13-0, janseppenrade2: Various bug fixes, regex filter creation optimization (create_regex_filter()) and improvements to major version recognition
#  2023.11.08-0, janseppenrade2: Reduced timeout for test mode, various bug fixes
#  2023.11.07-0, janseppenrade2: Bugfix in sorting list of available image tags from docker hub
#  2023.10.26-0, janseppenrade2: Bugfix in container startup validation; Disabled image download in test mode
#  2023.10.25-0, janseppenrade2: Bugfix in the order of Docker run parameters (tmpfs was missplaced); Added extended container startup validation; reduced value of $container_backups_retention_days from 14 to 7 as default
#  2023.10.24-0, janseppenrade2: Added Tmpfs option
#  2023.10.23-0, janseppenrade2: Improved regex filter creation (create_regex_filter())
#  2023.10.21-1, janseppenrade2: Released
#  2023.10.21-0, janseppenrade2: Renamed some variables and optimized it's descriptions
#  2023.10.18-0, janseppenrade2: Fixed a bug that prevented pruning docker container backups
#  2023.10.18-0, janseppenrade2: Fixed a bug that caused container updates even if there is no update available
#  2023.10.17-1, janseppenrade2: Added possibility to prune containers
#  2023.10.17-0, janseppenrade2: Several bugfixes
#  2023.10.07-0, janseppenrade2: Created
#
#  DESCRIPTION
#  This script is designed to automate the process of updating running and paused Docker container images while preserving their configurations. It also provides the option to specify exceptions by listing container names in the ignored_containers variable.
#  It's important to note that only inter-major updates are automated; major updates must be performed manually for security reasons. For example, if a container is running version 2.1.0, updates to versions 2.1.1 and 2.2.0 will be handled by this script.
#  If an update to version 3.0.0 is available, the script will inform you in the logs but not handle this update.
#  To run pre or post-installation scripts for specific containers, place these scripts in the same directory as this script (container_update.sh) and name them "container_update_post_script_<container_name>.sh" or "container_update_pre_script_<container_name>.sh."
#
#  HOW TO USE THIS SCRIPT
#  1. Place this script in your Docker server's file system.
#  2. Make it executable with the command "chmod +x </path/to/this/script/container_update.sh>".
#  3. For a fully automated experience, create a cron job to run this script periodicly.
#
#  HINT
#  For security reasons this script is executed with enabled test mode by default. As soon as you reviewed your log file created by this script after testing it on your system, which I higly recommend(!), you can disable the testmode by editing the variable "test_mode".
#
#  CUSTOMIZABLE VARIABLES
#  test_mode:                           Determines whether the script runs in test mode to prevent unwanted system changes (true/false).
#  docker_executable_path:              Points to the location of the Docker executable on your system.
#  ignored_containers:                  An array storing container names to be ignored by the script. (E.g.: ("MyContainer1" "MyContainer2" "MyContainer3") )
#  prune_images:                        Specifies whether to prune Docker images after each execution (true/false).
#  prune_container_backups:             Determines whether to prune Docker container backups after each execution or not (true/false). The very last backup is always kept, regardless of its age!
#  container_backups_retention_days:    Specifies the number of days for retaining container backups. The very last backup is always kept, regardless of its age!
#  log_retention_days:                  Sets the number of days to keep log entries.
#  checkContainerStateTimeout:          The duration in seconds to wait before performing a one-time check to determine if a Docker container has been successfully started.
#
#  TTESTING ENVIRONMENT(S)
#  Tested on the following operating systems with standard Docker installations:
#  - CentOS Stream 9
#  - Qnap QTS
#  
#  Tested with the following docker container images/tags:
#  - aalbng/glpi:10.0.9
#  - adguard/adguardhome:v0.107.40
#  - checkmk/check-mk-raw:2023.10.24
#  - dpage/pgadmin4:7.8
#  - juanluisbaptiste/postfix:1.7.1
#  - linuxserver/dokuwiki:2023-04-04a-ls186
#  - linuxserver/plex:1.32.6
#  - linuxserver/sabnzbd:4.1.0
#  - linuxserver/swag:2.7.2
#  - linuxserver/webtop:ubuntu-kde
#  - mariadb:11.1.2
#  - nextcloud:27.1.2
#  - ocsinventory/ocsinventory-docker-image:2.12
#  - odoo:16.0
#  - onlyoffice/documentserver:7.5.0
#  - osixia/openldap:1.5.0
#  - osixia/phpldapadmin:0.9.0
#  - phpmyadmin/phpmyadmin:5.2.1
#  - portainer/portainer-ee:2.19.1
#  - postgres:15.4
#  - redis:7.2.2
#  - thingsboard/tb-postgres:3.5.1
#  - vaultwarden/server:1.29.2




# GLOBAL VARIABLES

    # Fixed variables. Customization not needed.
    datetime=$(date +%Y-%m-%d_%H-%M)                                        # This variable is used to create timestamps for log entries and other time-related operations. You don't need to customize this.
    scriptdir="$(dirname "$(readlink -f "$0")")"                            # This variable uses the `readlink` and `dirname` commands to determine the directory containing the script file. You don't need to customize this.
    logfile="$scriptdir/logs/`basename "$0"`.log"                           # This variable specifies the path to the log file. It combines the `scriptdir` with the name of the script file and appends a `.log` extension. Log entries generated by the script are written to this file. You can customize it to change the log file path.
    pidfile="$scriptdir/`basename "$0"`.pid"                                # This variable specifies the path to the PID (Process ID) file. It is used to store the Process ID of the currently running script instance, preventing multiple instances from running simultaneously.
    
    # CUSTOMIZABLE VARIABLES
    test_mode=true
    docker_executable_path=""
    ignored_containers=()
    prune_images=true
    prune_container_backups=true
    container_backups_retention_days=7
    log_retention_days=7
    checkContainerStateTimeout=120

# HERE THE MAGIC BEGINS

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
                    if [ -n "$name" ]; then
                        docker_run_cmd+=" --name=$(quote "$name")"
                    fi

                # Hostname
                    hostname=$(echo "$container_config" | jq -r '.[0].Config.Hostname')
                    if [ -n "$hostname" ]; then
                        docker_run_cmd+=" --hostname=$(quote "$hostname")"
                    fi

                # Get the network mode
                    network=$(echo "$container_config" | jq -r '.[0].HostConfig.NetworkMode')
                    if [ "$network" != "default" ]; then
                        docker_run_cmd+=" --network=$(quote "$network")"
                    fi

                # Get the restart policy
                    restart_policy=$(echo "$container_config" | jq -r '.[0].HostConfig.RestartPolicy.Name')
                    if [ "$restart_policy" != "no" ]; then
                        docker_run_cmd+=" --restart=$restart_policy"
                    fi

                # PublishAllPorts
                    PublishAllPorts=$(echo "$container_config" | jq -r '.[0].HostConfig.PublishAllPorts')
                    if [ "$PublishAllPorts" != "false" ]; then
                        docker_run_cmd+=" --publish-all"
                    fi

                # Mac address
                    mac_address=$(echo "$container_config" | jq -r '.[0].Config.MacAddress')
                    if [ -n "$mac_address" ]; then
                        docker_run_cmd+=" --mac-address=$mac_address"
                    fi

                # IPv4 address
                    ipv4_address=$(echo "$container_config" | jq -r '.[0].NetworkSettings.Networks.'$network'.IPAMConfig.IPv4Address')
                    if [ -n "$ipv4_address" ] && [ "$ipv4_address" != "null" ]; then
                        docker_run_cmd+=" --ip=$ipv4_address"
                    fi

                # IPv6 address
                    ipv6_address=$(echo "$container_config" | jq -r '.[0].NetworkSettings.Networks.'$network'.IPAMConfig.IPv6Address')
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
                                    image_tag_major_version_docker_hub=$(echo "$image_tag_docker_hub" | cut -d'.' -f1)
                                    if [ "$image_tag_major_version_docker_hub" == "$image_tag_major_version" ]; then
                                        filtered_image_tags_docker_hub+=("$image_tag_docker_hub")
                                    fi
                                done

                        WriteLog "INFO" "  Comparing currently used image tag with latest available on docker hub..."
                            if [ -n "${image_tags_sorted_docker_hub[0]}" ]; then
                                image_tag_major_version_docker_hub=$(echo "${image_tags_sorted_docker_hub[0]}" | cut -d'.' -f1)
                                if [[ $image_tag_major_version_docker_hub == $image_tag_major_version ]]; then
                                    major_version_update_available=false
                                    WriteLog "INFO" "    There is no new major version available for ${image_name}. (Local:$image_tag_major_version == Online:$image_tag_major_version_docker_hub)"
                                else
                                    inter_major_version_update_available=true
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
                                                    bash "$script"
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
                                                                WriteLog "INFO" "    The container $name has been started since $elapsed_time seconds. This assumes everything worked well during the startup."
                                                            else
                                                                WriteLog "ERROR" "    The container $name has been started since just $elapsed_time seconds. This assumes something went wrong during the startup."
                                                                containerStartupError=true
                                                            fi
                                                        else
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
                                                else
                                                    script="$scriptdir/container_update_post_script_$name.sh"
                                                    if [ -e "$script" ]; then
                                                        WriteLog "INFO" "  Executing post script $script..."
                                                            if [ "$test_mode" == false ]; then
                                                                chmod +x "$script"
                                                                bash "$script"
                                                            fi
                                                    fi
                                                fi
                                            fi
                                    else
                                        WriteLog "ERROR" "    Failed to pull image."
                                    fi

                                    if [ "$state_paused" == "true" ]; then
                                        WriteLog "INFO" "  Pausing docker container..."
                                            ${docker_executable_path}docker pause $name
                                    fi
                            else
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
                                                    bash "$script"
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
                                                                WriteLog "INFO" "    The container $name has been started since $elapsed_time seconds. This assumes everything worked well during the startup."
                                                            else
                                                                WriteLog "ERROR" "    The container $name has been started since just $elapsed_time seconds. This assumes something went wrong during the startup."
                                                                containerStartupError=true
                                                            fi
                                                        else
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
                                                else
                                                    script="$scriptdir/container_update_post_script_$name.sh"
                                                    if [ -e "$script" ]; then
                                                        WriteLog "INFO" "  Executing post script $script..."
                                                            if [ "$test_mode" == false ]; then
                                                                chmod +x "$script"
                                                                bash "$script"
                                                            fi
                                                    fi
                                                fi
                                            fi
                                    else
                                        WriteLog "ERROR" "    Failed to pull image."
                                    fi

                                    if [ "$state_paused" == "true" ]; then
                                        WriteLog "INFO" "  Pausing docker container..."
                                            ${docker_executable_path}docker pause $name
                                    fi
                            else
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
