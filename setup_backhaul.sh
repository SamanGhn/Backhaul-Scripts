#!/bin/bash

# Function to install backhaul
install_backhaul() {
    echo "Installing backhaul..."

    # Initial setup for installing backhaul
    mkdir -p backhaul
    cd backhaul

    wget https://github.com/Musixal/Backhaul/releases/download/v0.3.0/backhaul_linux_amd64.tar.gz -O backhaul_linux.tar.gz
    tar -xf backhaul_linux.tar.gz
    rm backhaul_linux.tar.gz LICENSE README.md
    chmod +x backhaul
    mv backhaul /usr/bin/backhaul

    # Go back to the previous directory
    cd ..
    
    # (Installation continues as before)
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
    read -p "Enter the number of the server you want to add ports for: " server_number
    read -p "Enter the ports to add (comma-separated, e.g., 2020,2021): " new_ports

    # Convert the input string into a format suitable for the config file
    IFS=',' read -r -a ports_array <<< "$new_ports"
    ports_list=()
    for port in "${ports_array[@]}"; do
        ports_list+=("\"$port=$port\"")
    done
    ports_string=$(IFS=,; echo "${ports_list[*]}")

    # Append new ports to the ports array in the server configuration file
    sed -i "/ports = \[/a $ports_string" /root/backhaul/config_$server_number.toml
    echo "Ports added successfully to server $server_number."

    # Reload and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart backhaul_$server_number.service
}

# Function to remove ports
remove_ports() {
    read -p "Enter the number of the server you want to remove ports from: " server_number
    read -p "Enter the port to remove (only one port at a time): " port_to_remove

    # Remove the specified port from the configuration file
    sed -i "/\"$port_to_remove=$port_to_remove\"/d" /root/backhaul/config_$server_number.toml
    echo "Port $port_to_remove removed from server $server_number."

    # Reload and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart backhaul_$server_number.service
}

# Function to uninstall backhaul
uninstall_backhaul() {
    echo "Uninstalling backhaul..."
    # (Uninstallation code remains the same)
}

# Function to update backhaul
update_backhaul() {
    echo "Updating backhaul..."
    # (Update code remains the same)
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
