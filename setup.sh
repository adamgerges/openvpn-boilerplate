#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Ensure curl is installed
if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    apt update && apt install -y curl
fi

# Ensure jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "jq is not installed."
    read -p "Do you want to install jq? (yes/no): " install_jq
    if [[ $install_jq == "yes" ]]; then
        apt update && apt install -y jq
    else
        echo "jq is required for this script to run. Exiting."
        exit 1
    fi
fi

# Obtain the server's public IP address
export PUBLIC_IP=$(curl -s ipinfo.io/ip)

# Fetch details from ipinfo.io based on the server's public IP
LOCATION_INFO=$(curl -s ipinfo.io/$PUBLIC_IP)
COUNTRY_CODE=$(echo "$LOCATION_INFO" | jq -r .country)
COUNTRY_NAME=$(echo "$LOCATION_INFO" | jq -r .country)
SERVER_NAME=$(echo "$LOCATION_INFO" | jq -r .city)

# Map country code to continent (simplified)
declare -A CONTINENTS
CONTINENTS=( ["US"]="North America" ["CA"]="North America" ["FR"]="Europe" ["GB"]="Europe" ["AU"]="Australia" ["CN"]="Asia" ["IN"]="Asia" )
CONTINENT_NAME=${CONTINENTS[$COUNTRY_CODE]}

read -p "Do you want to install OpenVPN in Docker? (yes/no): " install_in_docker

if [[ $install_in_docker == "yes" ]]; then
    # Docker installation logic
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed."
        read -p "Do you want to install Docker? (yes/no): " install_docker
        if [[ $install_docker == "yes" ]]; then
            apt update
            apt install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
            add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
            apt update
            apt install -y docker-ce
        else
            echo "Docker is required for this script to run. Exiting."
            exit 1
        fi
    fi
    
    docker pull kylemanna/openvpn
    OVPN_DATA="openvpn_data"
    docker volume create --name $OVPN_DATA
    docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://$PUBLIC_IP
    docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
    docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn

else
    # Non-Docker installation logic
    apt-get install -y expect
    cat > automate_openvpn.sh << 'EOF'
#!/usr/bin/expect -f

set timeout -1

spawn sudo bash openvpn-install.sh

expect "Enter New CA Key Passphrase:" { send "MyPassphrase\r" }
expect "Re-Enter New CA Key Passphrase:" { send "MyPassphrase\r" }
expect "Common Name (eg: your user, host, or server name) [Easy-RSA CA]:" { send "$env(PUBLIC_IP)\r" }

expect eof
EOF
    chmod +x automate_openvpn.sh
    wget https://git.io/vpn -O openvpn-install.sh
    if [ -f "openvpn-install.sh" ]; then
        ./automate_openvpn.sh
        echo "max-clients 10000" >> /etc/openvpn/server/server.conf
        echo "duplicate-cn" >> /etc/openvpn/server/server.conf
        sudo systemctl restart openvpn-server@server
        rm automate_openvpn.sh
    else
        echo "Failed to download the OpenVPN installation script. Exiting."
        exit 1
    fi
fi

# Prompt user for .ovpn naming
read -p "Enter ISO country code (default: $COUNTRY_CODE): " icocountrycode
icocountrycode=${icocountrycode:-$COUNTRY_CODE}

read -p "Enter country name (default: $COUNTRY_NAME): " countryName
countryName=${countryName:-$COUNTRY_NAME}

read -p "Enter server name (default: $SERVER_NAME): " serverName
serverName=${serverName:-$SERVER_NAME}

read -p "Enter continent name (default: $CONTINENT_NAME): " continentName
continentName=${continentName:-$CONTINENT_NAME}

read -p "Is the server torrent enabled? (t/n, default: t) " torrentEnabled
torrentEnabled=${torrentEnabled:-t}

read -p "Is the server password protected? (p/n, default: n) " passwordEnabled
passwordEnabled=${passwordEnabled:-n}

read -p "Is the server residential enabled? (r/n, default: n) " residentialEnabled
residentialEnabled=${residentialEnabled:-n}

read -p "Is the server obfuscated enabled? (o/n, default: o) " obfuscatedEnabled
obfuscatedEnabled=${obfuscatedEnabled:-o}

read -p "Is the server DDoS enabled? (d/n, default: d) " ddosEnabled
ddosEnabled=${ddosEnabled:-d}

read -p "Is the server a TCP or UDP connection? (tcp/udp, default: udp) " connectionType
connectionType=${connectionType:-udp}

read -p "Enter the version of this .ovpn file (default: 1): " version
version=${version:-1}

filename="${icocountrycode}.${countryName}.${serverName}.${continentName}.${torrentEnabled}.${passwordEnabled}.${residentialEnabled}.${obfuscatedEnabled}.${ddosEnabled}.${connectionType}.${version}.ovpn"
mv /etc/openvpn/client/client.ovpn ~/"$filename"
echo "The OpenVPN configuration file has been saved as ~/$filename"
