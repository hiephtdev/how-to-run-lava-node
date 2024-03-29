#!/bin/bash

echo -e "\e[1;33m"
echo "    __    __  __   __    _____   _______  _____    _____  __          __ _    _    ____  "
echo "   |  \  /  |\  \ /  /  / ____| |__   __||_   _|  / ____| \ \        / /| |  | |  / __ \ "
echo "   |   \/   | \  V  /  | (___      | |     | |   | |       \ \  /\  / / | |__| | | |  | |"
echo "   | |\  /| |  \   /    \___ \     | |     | |   | |        \ \/  \/ /  |  __  | | |  | |"
echo "   | | \/ | |   | |     ____) |    | |    _| |_  | |____     \  /\  /   | |  | | | |__| |"
echo "   |_|    |_|   |_|    |_____/     |_|   |_____|  \_____|     \/  \/    |_|  |_|  \____/ "
echo -e "\e[0m"
sleep 2;

# set vars

echo -e "\e[1;33m1. Updating packages... \e[0m" && sleep 1;
# update
sudo apt update -y

echo -e "\e[1;33m2. Creating tem folder... \e[0m" && sleep 1;
# Create the temp dir for the installation
temp_folder=$(mktemp -d) && cd $temp_folder


echo -e "\e[1;33m3. Installing dependencies... \e[0m" && sleep 1;
# packages
sudo apt install -y unzip logrotate git jq sed wget curl coreutils systemd

# Check
if command -v go &> /dev/null; then
    echo -e "\e[1;33m Go is already installed."
else
    # Download
    go_package_url="https://go.dev/dl/go1.20.5.linux-amd64.tar.gz"
    go_package_file_name=${go_package_url##*\/}
    
    # Download GO
    wget -q $go_package_url
    
    # Unpack the GO installation file
    sudo tar -C /usr/local -xzf $go_package_file_name
    
    # Environment adjustments
    echo "export PATH=\$PATH:/usr/local/go/bin" >>~/.profile
    echo "export PATH=\$PATH:\$(go env GOPATH)/bin" >>~/.profile
    source ~/.profile
    
    echo -e "\e[1;33m Go has been installed."
fi

# Download the installation setup configuration
echo -e "\e[1;33m4. Download the installation setup configuration... \e[0m" && sleep 1;
git clone https://github.com/lavanet/lava-config.git
cd lava-config/testnet-2
# Read the configuration from the file
# Note: you can take a look at the config file and verify configurations
source setup_config/setup_config.sh

echo "Lava config file path: $lava_config_folder"
mkdir -p $lavad_home_folder
mkdir -p $lava_config_folder
cp default_lavad_config_files/* $lava_config_folder

# Copy the genesis.json file to the Lava config folder
cp genesis_json/genesis.json $lava_config_folder/genesis.json

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0 
mkdir -p $lavad_home_folder/cosmovisor/genesis/bin/

# Set and create the lavad binary path
echo -e "\e[1;33m5. Set and create the lavad binary path... \e[0m" && sleep 1;
required_upgrade_name="v0.21.1.2"
# Download the genesis binary to the lava path
wget -O  $lavad_home_folder/cosmovisor/genesis/bin/lavad "https://github.com/lavanet/lava/releases/download/$required_upgrade_name/lavad-$required_upgrade_name-linux-amd64"
chmod +x $lavad_home_folder/cosmovisor/genesis/bin/lavad


# Set the environment variables
if ! grep -q "export DAEMON_NAME=lavad" ~/.profile; then
    echo "# Setup Cosmovisor" >> ~/.profile
    echo "export DAEMON_NAME=lavad" >> ~/.profile
    echo "export CHAIN_ID=lava-testnet-2" >> ~/.profile
    echo "export DAEMON_HOME=$HOME/.lava" >> ~/.profile
    echo "export DAEMON_ALLOW_DOWNLOAD_BINARIES=true" >> ~/.profile
    echo "export DAEMON_LOG_BUFFER_SIZE=512" >> ~/.profile
    echo "export DAEMON_RESTART_AFTER_UPGRADE=true" >> ~/.profile
    echo "export UNSAFE_SKIP_BACKUP=true" >> ~/.profile
fi
source ~/.profile

# Initialize the chain
$lavad_home_folder/cosmovisor/genesis/bin/lavad init \
my-node \
--chain-id lava-testnet-2 \
--home $lavad_home_folder \
--overwrite
cp genesis_json/genesis.json $lava_config_folder/genesis.json

# create service
echo -e "\e[1;33m6. Create service... \e[0m" && sleep 1;
sudo tee /etc/systemd/system/cosmovisor.service > /dev/null <<EOF
[Unit]
Description=Cosmovisor daemon
After=network-online.target
[Service]
Environment="DAEMON_NAME=lavad"
Environment="DAEMON_HOME=${HOME}/.lava"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"
Environment="UNSAFE_SKIP_BACKUP=true"
User=$USER
ExecStart=${HOME}/go/bin/cosmovisor run start --home=$lavad_home_folder --p2p.seeds $seed_node
Restart=always
RestartSec=3
LimitNOFILE=infinity
LimitNPROC=infinity
[Install]
WantedBy=multi-user.target
EOF

echo -e "\e[1;33m7. Starting service... \e[0m" && sleep 1;
# start service
sudo systemctl daemon-reload
sudo systemctl enable cosmovisor
sudo systemctl start cosmovisor

echo -e "\e[1;33m=============== SETUP FINISHED ===================\e[0m"
echo -e "\e[1;33mView the logs from the running service, use: journalctl -f -u cosmovisor.service\e[0m"
echo -e "\e[1;33mCheck if the node is running, enter: sudo systemctl status cosmovisor.service\e[0m"
echo -e "\e[1;33mStop your Lavad node, use: sudo systemctl stop cosmovisor.service\e[0m"
echo -e "\e[1;33mStart your Lavad node, enter: sudo systemctl start cosmovisor.service\e[0m"
echo -e "\e[1;33mAfter modifying the lavad.service file, reload the service using: sudo systemctl daemon-reload\e[0m"
echo -e "\e[1;33mRestart the service, use: sudo systemctl restart cosmovisor.service\e[0m"
