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

    # Select transport type (tcpmux or ws)
    echo "Please choose the transport type:"
    echo "1) tcpmux"
    echo "2) ws"
    read -p "Enter your choice (1 or 2): " transport_choice

    if [ "$transport_choice" == "1" ]; then
        transport="tcp"
    elif [ "$transport_choice" == "2" ]; then
        transport="ws"
    else
        echo "Invalid transport type selected. Exiting."
        exit 1
    fi

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
transport = "$transport"
token = "$token"
keepalive_period = 15
nodelay = false
channel_size = 2048
connection_pool = 7

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
transport = "$transport"
token = "$token"
keepalive_period = 15
nodelay = false
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

# Rest of the script (edit, uninstall, update functions) remains unchanged
# Keeping edit, uninstall, and update functions intact as requested.

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
