#!/bin/bash

# Function to install backhaul
install_backhaul() {
    echo "Installing backhaul..."

    # Initial setup for installing backhaul
    mkdir -p backhaul
    cd backhaul

    wget https://github.com/Musixal/Backhaul/releases/download/v0.1.1/backhaul_linux_amd64.tar.gz -O backhaul_linux.tar.gz
    tar -xf backhaul_linux.tar.gz
    rm backhaul_linux.tar.gz LICENSE README.md
    chmod +x backhaul
    mv backhaul /usr/bin/backhaul

    # Go back to the previous directory
    cd ..

    # Get server location from the user
    read -p "Is this server located in Iran? (y/n): " location 

    # If the server is located in Iran
    if [ "$location" == "y" ]; then
        echo "This server is located in Iran, applying settings for Iran..."

        # Get the number of foreign servers
        read -p "How many foreign servers do you have? " num_servers

        # Loop for each foreign server
        for ((i=1; i<=num_servers; i++))
        do
            echo "Configuring foreign server number $i..."

            # Get tunnel port for the foreign server
            read -p "Enter the tunnel port number for foreign server $i: " tunnelport

            # Get token for the foreign server
            read -p "Please enter the token for foreign server $i: " token

            # Get mux_session value for the foreign server
            read -p "Please enter the mux_session value for foreign server $i: " mux_session

            # Choose how to input ports (individually or range)
            read -p "Do you want to enter the ports manually or as a range? (m/r): " method

            if [ "$method" == "m" ]; then
                # Get the list of ports from the user as a comma-separated string
                read -p "Please enter all the ports as a comma-separated list (e.g., 2020,2021,2027): " port_list_input

                # Create an array from the comma-separated list
                IFS=',' read -r -a ports_array <<< "$port_list_input"

                # Initialize an empty array to store formatted ports
                ports_list=()

                # Loop through the array and format each port
                for port in "${ports_array[@]}"
                do
                    ports_list+=("\"$port=$port\"")
                done

            elif [ "$method" == "r" ]; then
                # Get the port range from the user
                read -p "Please enter the start port: " start_port
                read -p "Please enter the end port: " end_port

                # Create an array to store the ports
                ports_list=()

                # Generate ports based on the range and add them to the array with double quotes
                for ((port=start_port; port<=end_port; port++))
                do
                    ports_list+=("\"$port=$port\"")
                done

            else
                echo "Invalid input method. Please enter 'm' for manually or 'r' for range."
                exit 1
            fi

            # Convert the array to a string with appropriate separators for the config file
            ports_string=$(IFS=,; echo "${ports_list[*]}")

            # Create a config file for the Iran server with settings for each foreign server
            sudo tee /root/backhaul/config_$i.toml > /dev/null <<EOL
[server]
bind_addr = "0.0.0.0:$tunnelport"
transport = "tcp"
token = "$token"
keepalive_period = 20
nodelay = false
channel_size = 2048
connection_pool = 8
mux_session = $mux_session

ports = [ 
$ports_string
]
EOL

            # Create a service file for the foreign server with a specific number (i)
            sudo tee /etc/systemd/system/backhaul_$i.service > /dev/null <<EOL
[Unit]
Description=Backhaul Reverse Tunnel Service for Server $i
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/backhaul -c /root/backhaul/config_$i.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOL

            # Reload systemd, enable and start the service
            sudo systemctl daemon-reload
            sudo systemctl enable backhaul_$i.service
            sudo systemctl start backhaul_$i.service
            sudo systemctl status backhaul_$i.service
        done

    # If the server is located outside Iran
    else
        echo "This server is located outside Iran, applying settings for outside..."

        # Get the IP of the Iran server from the user
        read -p "Please enter the IP address of the Iran server: " ip_iran

        # Get the foreign server index
        read -p "Which foreign server is this in relation to the Iran server? " server_index

        # Get tunnel port for the foreign server
        read -p "Enter the tunnel port number for foreign server $server_index: " tunnelport

        # Get token for the foreign server
        read -p "Please enter the token for foreign server $server_index: " token

        # Get mux_session value for the foreign server
        read -p "Please enter the mux_session value for foreign server $server_index: " mux_session

        # Create a config file for the foreign server with the given index
        sudo tee /root/backhaul/config_$server_index.toml > /dev/null <<EOL
[client]
remote_addr = "$ip_iran:$tunnelport"
transport = "tcp"
token = "$token"
keepalive_period = 20
nodelay = false
retry_interval = 1
mux_session = $mux_session
EOL

        # Create a service file for the foreign server with the given index
        sudo tee /etc/systemd/system/backhaul_$server_index.service > /dev/null <<EOL
[Unit]
Description=Backhaul Reverse Tunnel Service for Server $server_index
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/backhaul -c /root/backhaul/config_$server_index.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOL

        # Reload systemd, enable and start the service
        sudo systemctl daemon-reload
        sudo systemctl enable backhaul_$server_index.service
        sudo systemctl start backhaul_$server_index.service
        sudo systemctl status backhaul_$server_index.service
    fi
}

# Function to edit backhaul configuration
edit_backhaul() {
    echo "---------------------------------"
    echo "  Backhaul Edit Menu"
    echo "---------------------------------"
    echo "1) Edit Token"
    echo "2) Edit Mux Session"
    echo "3) Add Ports"
    echo "4) Remove Ports"
    echo "5) Return to Main Menu"
    echo "---------------------------------"

    read -p "Please choose an option: " edit_option

    case $edit_option in
        1)
            edit_token
            ;;
        2)
            edit_mux_session
            ;;
        3)
            add_ports
            ;;
        4)
            remove_ports
            ;;
        5)
            return
            ;;
        *)
            echo "Invalid option, returning to Main Menu."
            ;;
    esac
}

# Function to edit token
edit_token() {
    read -p "Enter the number of the server you want to edit the token for: " server_number
    read -p "Enter the new token: " new_token

    # Modify the token in the server configuration file
    sed -i "s/token = .*/token = \"$new_token\"/" /root/backhaul/config_$server_number.toml
    echo "Token updated successfully for server $server_number."

    # Reload and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart backhaul_$server_number.service
}

# Function to edit mux_session
edit_mux_session() {
    read -p "Enter the number of the server you want to edit the mux_session for: " server_number
    read -p "Enter the new mux_session value: " new_mux_session

    # Modify the mux_session in the server configuration file
    sed -i "s/mux_session = .*/mux_session = $new_mux_session/" /root/backhaul/config_$server_number.toml
    echo "Mux session updated successfully for server $server_number."

    # Reload and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart backhaul_$server_number.service
}

# Function to add ports
add_ports() {
    read -p "Enter the number of the server you want to add ports to: " server_number
    read -p "Enter the new ports as a comma-separated list (e.g., 2025,2026): " new_ports

    # Convert the new ports into the appropriate format
    IFS=',' read -r -a new_ports_array <<< "$new_ports"
    formatted_ports=()

    for port in "${new_ports_array[@]}"; do
        formatted_ports+=("\"$port=$port\"")
    done

    # Read the existing ports from the config file
    existing_ports=$(grep -oP '(?<=ports = \[).*(?=\])' /root/backhaul/config_$server_number.toml)

    # Remove any trailing commas or spaces from the existing ports
    existing_ports=$(echo "$existing_ports" | sed 's/^[ ,]*//;s/[ ,]*$//')

    # Combine the existing ports with the new ones (if existing ports are not empty)
    if [ -n "$existing_ports" ]; then
        all_ports="$existing_ports,$(IFS=,; echo "${formatted_ports[*]}")"
    else
        all_ports=$(IFS=,; echo "${formatted_ports[*]}")
    fi

    # Update the config file with the merged ports
    sed -i "/ports = \[/c\ports = [${all_ports}," /root/backhaul/config_$server_number.toml

    echo "Ports added successfully to server $server_number."

    # Reload and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart backhaul_$server_number.service
}



# Function to remove ports
remove_ports() {
    read -p "Enter the number of the server you want to remove ports from: " server_number
    read -p "Enter the ports to remove as a comma-separated list (e.g., 2025,2026): " remove_ports

    IFS=',' read -r -a remove_ports_array <<< "$remove_ports"

    # Read the existing ports from the config file
    existing_ports=$(grep -oP '(?<=ports = \[)[^\]]*' /root/backhaul/config_$server_number.toml)

    # Remove leading/trailing whitespace and commas from existing_ports
    existing_ports=$(echo "$existing_ports" | sed 's/^[ ,]*//;s/[ ,]*$//')

    # Remove specified ports from the existing ports
    for port in "${remove_ports_array[@]}"; do
        existing_ports=$(echo "$existing_ports" | sed "s/\"$port=$port\"//g")
    done

    # Remove extra commas and spaces
    existing_ports=$(echo "$existing_ports" | sed 's/,,*/,/g')
    existing_ports=$(echo "$existing_ports" | sed 's/^[ ,]*//;s/[ ,]*$//')

    # Update the config file with the remaining ports
    sed -i "/ports = \[/c\ports = [ $existing_ports ]" /root/backhaul/config_$server_number.toml
    echo "Ports removed successfully from server $server_number."

    # Reload and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart backhaul_$server_number.service
}

# Function to uninstall backhaul
uninstall_backhaul() {
    echo "Uninstalling backhaul..."

    # Stop and disable all backhaul services
    for service_file in /etc/systemd/system/backhaul_*.service; do
        if [ -f "$service_file" ]; then
            service_name=$(basename "$service_file")
            sudo systemctl stop $service_name
            sudo systemctl disable $service_name
            sudo rm "$service_file"
            echo "Removed service file: $service_file"
            
            # Reload systemd and reset failed services after each service is removed
            sudo systemctl daemon-reload
            sudo systemctl reset-failed
        fi
    done

    # Remove backhaul binary and config files
    if [ -f /usr/bin/backhaul ]; then
        sudo rm /usr/bin/backhaul
        echo "Removed /usr/bin/backhaul"
    fi

    if [ -d /root/backhaul ]; then
        sudo rm -rf /root/backhaul
        echo "Removed /root/backhaul directory"
    fi

    # Reload systemd and reset failed services after all operations are done
    sudo systemctl daemon-reload
    sudo systemctl reset-failed

    echo "Backhaul uninstalled successfully."
}


# Function to update backhaul
update_backhaul() {
    echo "Updating backhaul..."

    # Download the latest version and replace the existing binary
    wget https://github.com/Musixal/Backhaul/releases/download/v0.2.2/backhaul_linux_amd64.tar.gz -O backhaul_linux_update.tar.gz
    tar -xf backhaul_linux_update.tar.gz
    rm backhaul_linux_update.tar.gz LICENSE README.md
    chmod +x backhaul
    sudo mv backhaul /usr/bin/backhaul

    # Reload systemd
    sudo systemctl daemon-reload

    echo "Backhaul updated successfully."
}

# Main menu loop
while true; do
    echo "---------------------------------"
    echo "  Backhaul Management Menu"
    echo "---------------------------------"
    echo "0) Exit"
    echo "1) Install Backhaul"
    echo "2) Edit Backhaul"
    echo "3) Update Backhaul"
    echo "4) Uninstall Backhaul"
    echo "---------------------------------"

    read -p "Please choose an option: " option

    case $option in
        0)
            echo "Exiting..."
            exit 0
            ;;
        1)
            install_backhaul
            ;;
        2)
            edit_backhaul
            ;;
        3)
            update_backhaul
            ;;
        4)
            uninstall_backhaul
            ;;
        *)
            echo "Invalid option, please try again."
            ;;
    esac
done
