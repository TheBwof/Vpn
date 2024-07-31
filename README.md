# Vpn
Virtual private network server
# VPN Setup Script for StrongSwan on Ubuntu

This script automates the setup of a StrongSwan IKEv2 VPN server on an Ubuntu system. It configures StrongSwan, sets up IP forwarding, configures NAT with iptables, and sets up UFW for firewall management.

## Features

- Updates and installs necessary packages.
- Removes conflicting packages if present.
- Configures StrongSwan for IKEv2 VPN with pre-shared key (PSK).
- Automatically detects the active network interface.
- Enables IP forwarding.
- Sets up NAT using iptables.
- Configures UFW to allow VPN traffic.
- Restarts and enables the StrongSwan service.
- Checks internet connectivity.
- Displays VPN configuration details.

## Prerequisites

- Ubuntu-based system.
- Root or sudo access.

## Usage

1. Clone this repository or download the script:

   ```bash
   git clone https://github.com/TheBwof/vpn
   cd vpn
   chmod +x vpnpsk.sh
   sudo ./vpnpsk.sh
