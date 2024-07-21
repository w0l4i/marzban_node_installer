#!/bin/bash

# Welcome message
echo "------------------------------------------"
echo "Welcome to the Xanmod Kernel and Marzban Node Setup Script!"
echo "------------------------------------------"
echo "This script will install the Xanmod kernel, configure your system,"
echo "and set up the Marzban Node with Docker and Nginx."
echo "Please ensure you run this script as root."
echo "------------------------------------------"
echo "Prepared and customized by w0l4i for personal use to install and set up"
echo "Marzban Node along with Nginx, Xanmod kernel, BBR v3, and various"
echo "system and kernel optimizations for optimal performance."
echo "------------------------------------------"

# Ensure we are running the script as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if Xanmod kernel is installed
is_xanmod_installed() {
    uname -r | grep -q "xanmod"
}

# Check if Xanmod kernel is installed
if is_xanmod_installed; then
    echo "Xanmod kernel already installed. Proceeding to the next steps..."
else
    echo "Installing Xanmod kernel..."
    sudo wget -qO - https://gitlab.com/afrd.gpg | sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-release.list
    sudo apt update -y

    # Check CPU support level
    cpu_support=$(awk '
    BEGIN {
        while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
        if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
        if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
        if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
        if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
        if (level > 0) { print "CPU supports x86-64-v" level; exit level + 1 }
        exit 1
    }')

    if [[ "$cpu_support" == *"CPU supports x86-64-v3"* ]]; then
        sudo apt update && sudo apt install linux-xanmod-rt-x64v3 -y
    elif [[ "$cpu_support" == *"CPU supports x86-64-v2"* ]]; then
        sudo apt update && sudo apt install linux-xanmod-rt-x64v2 -y
    elif [[ "$cpu_support" == *"CPU supports x86-64-v4"* ]]; then
        sudo apt update && sudo apt install linux-xanmod-rt-x64v4 -y
    elif [[ "$cpu_support" == *"CPU supports x86-64 (LEGACY)"* ]]; then
        sudo apt update && sudo apt install linux-xanmod-x64v1 -y
    else
        echo "Unsupported CPU. Exiting..."
        exit 1
    fi

    echo "Xanmod kernel installed. Rebooting system..."
    sudo reboot
fi

# Check if running Xanmod kernel after reboot
if is_xanmod_installed; then
    echo "Running Xanmod kernel. Proceeding..."
    sudo depmod -a
    sudo bash -c 'cat >> /etc/sysctl.conf' <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF
    sudo sysctl -p
else
    echo "Xanmod kernel not running. Exiting..."
    exit 1
fi

# Install necessary packages
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install curl socat git -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Clone Marzban-node repository
git clone https://github.com/Gozargah/Marzban-node
mkdir /var/lib/marzban-node

cd ~/Marzban-node
rm -rf docker-compose.yml
sudo bash -c 'cat > docker-compose.yml' <<EOF
services:
  marzban-node:
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host
    environment:
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/ssl_client_cert.pem"
      SERVICE_PROTOCOL: "rest"
      XRAY_EXECUTABLE_PATH: "/var/lib/marzban/xray-core/xray"
    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
      - /var/lib/marzban/assets:/usr/local/share/xray
      - /var/lib/marzban:/var/lib/marzban
EOF

# Request user input for ssl_client_cert.pem
echo "Please enter the content for /var/lib/marzban-node/ssl_client_cert.pem:"
read -r ssl_cert_content
echo "$ssl_cert_content" | sudo tee /var/lib/marzban-node/ssl_client_cert.pem > /dev/null

# Start Marzban-node
cd ~/Marzban-node
sudo docker compose down --remove-orphans
sudo docker compose up -d

# Download geo files
mkdir -p /var/lib/marzban/assets/
wget -O /var/lib/marzban/assets/geoip.dat https://github.com/Chocolate4U/Iran-v2ray-rules/releases/download/202407210443/geoip.dat
wget -O /var/lib/marzban/assets/geosite.dat https://github.com/Chocolate4U/Iran-v2ray-rules/releases/download/202407210443/geosite.dat

# Update xray-core
sudo apt install wget unzip -y
mkdir -p /var/lib/marzban/xray-core && cd /var/lib/marzban/xray-core
wget https://github.com/XTLS/xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip
rm Xray-linux-64.zip

# Start Marzban-node again after downloading geo files
cd ~/Marzban-node
sudo docker compose down --remove-orphans
sudo docker compose up -d

# Install and configure Nginx
sudo apt-get install nginx -y
sudo rm -rf /etc/nginx/sites-available/default
sudo bash -c 'cat > /etc/nginx/sites-available/default' <<EOF
server {
    listen 8080 default_server;
    server_name default_server;

    location ~ ^/blogkjhHSJFDHjklhsajdf25432/(.+)/api/?$ {
        proxy_redirect off;
        rewrite .* / break;
        proxy_pass http://127.0.0.1:14000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 80 default_server;
    server_name default_server;

    location ~ ^/login/(.+)/north/?$ {
        proxy_redirect off;
        rewrite .* / break;
        proxy_pass http://127.0.0.1:6000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
sudo systemctl restart nginx

# Final update and reboot
sleep 30
sudo apt-get update && sudo apt-get upgrade -y && sudo reboot

echo "All steps completed successfully."
