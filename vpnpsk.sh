#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages with colors
print_msg() {
    echo -e "\n\033[1;34m=== $1 ===\033[0m"
}

print_success() {
    echo -e "\033[1;32m$1\033[0m"
}

print_error() {
    echo -e "\033[1;31m$1\033[0m"
}

# Update and install necessary packages
print_msg "Updating system and installing packages..."
sudo apt-get update

# Remove conflicting packages if present
if dpkg -l | grep -q 'iptables-persistent'; then
    print_msg "Removing conflicting packages..."
    sudo apt-get remove --purge -y iptables-persistent netfilter-persistent
fi

# Install StrongSwan and UFW
print_msg "Installing StrongSwan and UFW..."
sudo apt-get install -y strongswan strongswan-pki libcharon-extra-plugins ufw

# Automatically detect the active network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$INTERFACE" ]; then
    print_error "No network interface found. Please check your network configuration."
    exit 1
fi

print_msg "Detected network interface: $INTERFACE"

# Prompt for DDNS or public IP and PSK
read -p "Enter your DDNS or public IP address: " DDNS_PUBLIC_IP
read -sp "Enter your PSK key: " PSK_KEY
echo

# Create StrongSwan configuration file
print_msg "Creating StrongSwan configuration file..."
cat << EOF | sudo tee /etc/ipsec.conf
config setup
    uniqueids=never

conn %default
    keyexchange=ikev2
    authby=psk
    ikelifetime=1h
    keylife=20m
    rekeymargin=5m
    keyingtries=1
    compress=yes

conn ikev2-vpn
    left=%any
    leftid=@${DDNS_PUBLIC_IP}
    leftsubnet=0.0.0.0/0
    right=%any
    rightdns=8.8.8.8,8.8.4.4
    rightsourceip=10.10.10.0/24
    auto=add
EOF

# Create StrongSwan secrets file
print_msg "Creating StrongSwan secrets file..."
cat << EOF | sudo tee /etc/ipsec.secrets
: PSK "${PSK_KEY}"
EOF

# Enable IP forwarding
print_msg "Enabling IP forwarding..."
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# Set up NAT with iptables
print_msg "Setting up NAT with iptables..."
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o $INTERFACE -j MASQUERADE
sudo iptables -A FORWARD -s 10.10.10.0/24 -j ACCEPT
sudo iptables -A FORWARD -d 10.10.10.0/24 -j ACCEPT

# Ensure the iptables directory exists and save rules
print_msg "Ensuring /etc/iptables directory exists and saving rules..."
sudo mkdir -p /etc/iptables
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
sudo sh -c "ip6tables-save > /etc/iptables/rules.v6"

# Configure UFW
print_msg "Configuring UFW..."
sudo ufw allow 500/udp
sudo ufw allow 4500/udp
sudo ufw allow OpenSSH
echo "y" | sudo ufw enable

# Restart StrongSwan service
print_msg "Restarting StrongSwan service..."
if systemctl is-active --quiet strongswan; then
    SERVICE="strongswan"
elif systemctl is-active --quiet strongswan-starter; then
    SERVICE="strongswan-starter"
else
    print_error "No active StrongSwan service found. Please verify the installation."
    exit 1
fi

sudo systemctl daemon-reload
sudo systemctl restart $SERVICE
sudo systemctl enable $SERVICE

# Check internet connectivity
print_msg "Checking internet connectivity..."
if curl -s --head http://www.google.com | head -n 1 | grep "200 OK" > /dev/null; then
    print_success "Internet is available."
else
    print_error "Internet is not available. Please check your network settings."
    exit 1
fi

# Display configuration
print_msg "VPN Configuration:"
echo -e "\033[1;33mServer address:\033[0m ${DDNS_PUBLIC_IP}"
echo -e "\033[1;33mPSK key:\033[0m ${PSK_KEY}"

# Final message
print_success "VPN setup complete. Connect using the IKEv2 PSK profile on your device."
