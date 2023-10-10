# OpenVPN Setup Script

This repository contains a bash script (`setup.sh`) for setting up an OpenVPN server and generating a client configuration file (.ovpn).

## Requirements

- The script requires root privileges to run.
- The script requires 'jq' for JSON parsing. If 'jq' is not installed, the script will prompt you to install it.
- If you choose to install OpenVPN in Docker, Docker must be installed. If Docker is not installed, the script will prompt you to install it.

## Usage

To run the script, clone this repository and execute the script:

```
git clone https://github.com/adamgerges/openvpn-boilerplate.git
cd openvpn-boilerplate
sudo bash setup.sh
```

The script will prompt you for various details to name the .ovpn file. The details include the country code, country name, server name, continent name, whether the server is torrent enabled, password protected, residential enabled, obfuscated enabled, DDoS enabled, the connection type (TCP or UDP), and the version of the .ovpn file. The script then moves the client.ovpn file to the home directory and renames it according to the details you provide.

## Note

This script is intended for Ubuntu 20.04. It may work on other versions of Ubuntu or other Linux distributions, but this has not been tested.
