#  Docker Container Updater
#
#  VERSION
#  0.8
#
#  CHANGELOG
#  2023-10-23 (v0.8), janseppenrade2: Improved regex filter creation (create_regex_filter())
#  2023-10-21 (v0.7), janseppenrade2: Released
#  2023-10-21 (v0.6), janseppenrade2: Renamed some variables and optimized it's descriptions
#  2023-10-18 (v0.5), janseppenrade2: Fixed a bug that prevented pruning docker container backups
#  2023-10-18 (v0.4), janseppenrade2: Fixed a bug that caused container updates even if there is no update available
#  2023-10-17 (v0.3), janseppenrade2: Added possibility to prune containers
#  2023-10-17 (v0.2), janseppenrade2: Several bugfixes
#  2023-10-07 (v0.1), janseppenrade2: Created
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
#  FUNCTIONALITY
#  1.  The script begins by checking if a previous instance is running to prevent multiple instances from running simultaneously.
#  2.  It creates a log file for recording execution details.
#  3.  Functions are defined to quote strings and add settings to the docker run command.
#  4.  The script collects Docker container IDs and iterates through them.
#  5.  It gathers information about each container, such as its image, name, network settings, and environment variables.
#  6.  The script checks for available updates within the same major version, and if an update is available, it pulls the new image and updates the container. If docker run command fails, all changes will be reverted and the old container iwll be started again.
#  7.  Container pre and post-installation scripts are executed, if available.
#  8.  Container backups and image pruning can be performed.
#  9.  The script truncates the log file to retain only recent entries.
#  10. It concludes the execution and removes the process ID file.
#
#  CUSTOMIZABLE VARIABLES
#  test_mode:                           Determines whether the script runs in test mode to prevent unwanted system changes (true/false).
#  docker_executable_path:              Points to the location of the Docker executable on your system.
#  ignored_containers:                  An array storing container names to be ignored by the script.
#  prune_images:                        Specifies whether to prune Docker images after each execution (true/false).
#  prune_container_backups:             Determines whether to prune Docker container backups after each execution (true/false).
#  container_backups_retention_days:    Specifies the number of days for retaining container backups.
#  log_retention_days:                  Sets the number of days to keep log entries.
#
#  TTESTING ENVIRONMENT(S)
#  Tested on the following operating systems with standard Docker installations:
#  - CentOS Stream 9
#  - Qnap QTS
#  
#  Tested with the following docker container images/tags:
#  - aalbng/glpi:10.0.9
#  - adguard/adguardhome:v0.107.40
#  - dpage/pgadmin4:7.8
#  - linuxserver/dokuwiki:2023-04-04a-ls186
#  - linuxserver/plex:1.32.6
#  - linuxserver/sabnzbd:4.1.0
#  - linuxserver/swag:2.7.1
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
#  - redis:7.2.2 2023-10-20
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
    container_backups_retention_days=14
    log_retention_days=7

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

        # Loop through the input string
        for ((i=0; i<${#input}; i++)); do
            char="${input:$i:1}"
            # Check if the character is a digit
            if [[ "$char" =~ [0-9] ]]; then
                regex_filter="${regex_filter}[0-9]"
            else
                regex_filter="${regex_filter}${char}"
            fi
        done

        echo "^$regex_filter$"
    }

# Informing about test mode
    if [ "$test_mode" == true ]; then
        WriteLog "INFO" "Test mode is enabled. No changes will be made to your system except for downloading new Docker images."
        WriteLog "INFO" "  You have 20 seconds to terminate this execution if needed."
        sleep 20
    fi

# Getting docker container IDs
    container_ids=($(docker ps -q))

# Computing docker containers - one by one
    for container_id in "${container_ids[@]}"; do
        ignored=false
        image_tags=()
        image_tags_sorted_docker_hub=()
        filtered_image_tags_docker_hub=()
        image_tag_major_version_docker_hub=""
        docker_run_cmd="${docker_executable_path}docker run -d"
        image_same_version_update_available=true
        regex_filter=""

        WriteLog "INFO" "Processing container $container_id"
        WriteLog "INFO" "  Requesting configuration details of $container_id"
            container_config=$(docker inspect "$container_id")

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

            # The image name on which the container is based
                image_name=$(echo "$container_config" | jq -r '.[0].Config.Image' | cut -d':' -f1)
                docker_run_cmd+=" $image_name"
                
            # RepoDigests
                #image_RepoDigest=$(docker image inspect -f '{{.RepoDigests}}' ${image_id} | awk -F: '{print $2}' | sed 's/]//') # Not working with multi values
                image_RepoDigest=$(docker image inspect -f '{{.RepoDigests}}' ${image_id} | tr ' ' ',' | sed 's/\[\|\]//g' | sed 's#'"$image_name"'@sha256:##g') # This writes single and multi values to the variable

            # The image tag on which the container is based
                image_tag=$(echo "$container_config" | jq -r '.[0].Config.Image' | cut -d':' -f2)

            # The major version of the image given in the image tag
                image_tag_major_version=$(echo $image_tag | cut -d'.' -f1)
            
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
                            #image_tags_sorted_docker_hub=($(printf "%s\n" "${image_tags[@]}" | tr '.' '\t' | sort -rnk1,1 -k2,2 -k3,3 | tr '\t' '.')) # Caused multiple values in a single array element
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
                            image_RepoDigest_docker_hub=$(curl -s "https://registry.hub.docker.com/v2/repositories/${image_name}/tags/${image_tag}" | jq -r '.digest' | awk -F: '{print $2}')
                        else
                            image_RepoDigest_docker_hub=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/${image_name}/tags/${image_tag}" | jq -r '.digest' | awk -F: '{print $2}')
                        fi

                        if [ -n "${image_RepoDigest_docker_hub[0]}" ]; then
                            IFS=','
                            read -ra image_RepoDigest_values <<< "$image_RepoDigest"
                            for image_RepoDigest_value in "${image_RepoDigest_values[@]}"; do
                                if [[ ${image_RepoDigest_docker_hub[0]} == $image_RepoDigest_value ]]; then
                                    image_same_version_update_available=false
                                    WriteLog "INFO" "    Currently used image is up to date. Nothing to do. (Local:$image_RepoDigest_value == Online:${image_RepoDigest_docker_hub[0]})"
                                    break
                                fi
                            done

                            if [[ "$image_same_version_update_available" == true ]]; then
                                WriteLog "INFO" "    Currently used image is outdated and needs to be updated. (Local:$image_RepoDigest <> Online:${image_RepoDigest_docker_hub[0]})"
                            fi
                        else
                            image_same_version_update_available=false
                            WriteLog "INFO" "    No online image tags found."
                        fi

                    if [ "$inter_major_version_update_available" == true ]; then
                        docker_run_cmd+=":${filtered_image_tags_docker_hub[0]}"

                        WriteLog "INFO" "  Pulling new image (${filtered_image_tags_docker_hub[0]})..."
                            ${docker_executable_path}docker pull ${image_name}:${filtered_image_tags_docker_hub[0]}

                            if [ $? -eq 0 ]; then
                                WriteLog "INFO" "    Image successfully pulled"
                                
                                script="$scriptdir/container_update_pre_script_$name.sh"
                                if [ -e "$script" ]; then
                                    WriteLog "INFO" "  Executing pre script $script..."
                                        chmod +x "$script"
                                        bash "$script"
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
                                        eval "$docker_run_cmd"

                                        if [ $? -ne 0 ]; then
                                            WriteLog "ERROR" "  Faild to start docker container. Rolling back changes..."
                                                WriteLog "INFO" "  Stopping new container"
                                                    ${docker_executable_path}docker stop ${name}
                                                WriteLog "INFO" "  Removing new container"
                                                    ${docker_executable_path}docker rm -fv ${name}
                                                WriteLog "INFO" "  Restoring start up policy..."
                                                    ${docker_executable_path}docker update $container_id --restart $restart_policy
                                                WriteLog "INFO" "  Renaming old instance back to it's original name..."
                                                    ${docker_executable_path}docker rename $container_id ${name}
                                                WriteLog "INFO" "  Starting old instance..."
                                                    ${docker_executable_path}docker start $container_id
                                        else
                                            script="$scriptdir/container_update_post_script_$name.sh"
                                            if [ -e "$script" ]; then
                                                WriteLog "INFO" "  Executing post script $script..."
                                                    chmod +x "$script"
                                                    bash "$script"
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
                    elif [ "$image_same_version_update_available" == true ]; then
                        docker_run_cmd+=":$image_tag"

                        WriteLog "INFO" "  Pulling new image (${filtered_image_tags_docker_hub[0]})..."
                            ${docker_executable_path}docker pull ${image_name}:${filtered_image_tags_docker_hub[0]}

                            if [ $? -eq 0 ]; then
                                WriteLog "INFO" "    Image successfully pulled"
                                
                                script="$scriptdir/container_update_pre_script_$name.sh"
                                if [ -e "$script" ]; then
                                    WriteLog "INFO" "  Executing pre script $script..."
                                        chmod +x "$script"
                                        bash "$script"
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
                                        eval "$docker_run_cmd"

                                        if [ $? -ne 0 ]; then
                                            WriteLog "ERROR" "  Faild to start docker container. Rolling back changes..."
                                                WriteLog "INFO" "  Stopping new container"
                                                    ${docker_executable_path}docker stop ${name}
                                                WriteLog "INFO" "  Removing new container"
                                                    ${docker_executable_path}docker rm -fv ${name}
                                                WriteLog "INFO" "  Restoring start up policy..."
                                                    ${docker_executable_path}docker update $container_id --restart $restart_policy
                                                WriteLog "INFO" "  Renaming old instance back to it's original name..."
                                                    ${docker_executable_path}docker rename $container_id ${name}
                                                WriteLog "INFO" "  Starting old instance..."
                                                    ${docker_executable_path}docker start $container_id
                                        else
                                            script="$scriptdir/container_update_post_script_$name.sh"
                                            if [ -e "$script" ]; then
                                                WriteLog "INFO" "  Executing post script $script..."
                                                    chmod +x "$script"
                                                    bash "$script"
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
