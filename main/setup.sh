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

# Update and install necessary packages
sudo apt-get update
if [[ $? -ne 0 ]]; then
    echo "Failed to update package list. Please check your network connection and try again."
    exit 1
fi

sudo apt-get upgrade -y
if [[ $? -ne 0 ]]; then
    echo "Failed to upgrade packages. Please check your network connection and try again."
    exit 1
fi

# Set DNS
sudo bash -c 'cat > /etc/resolv.conf' <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

# Create /etc/rc.local for auto execution after reboot
sudo bash -c 'cat > /etc/rc.local' <<EOF
#!/bin/bash
bash ~/setup.sh
exit 0
EOF
sudo chmod +x /etc/rc.local

# Install dependencies
sudo apt-get install -y wget curl gnupg2 software-properties-common
if [[ $? -ne 0 ]]; then
    echo "Failed to install dependencies. Please check your network connection and try again."
    exit 1
fi

# Download and install Xray-core
xray_dir="/var/lib/marzban/xray-core"
if [[ -d "$xray_dir" ]]; then
    sudo rm -rf "$xray_dir"
fi
mkdir -p "$xray_dir"
wget -O "$xray_dir/xray-linux-64.zip" https://github.com/XTLS/xray-core/releases/latest/download/Xray-linux-64.zip
if [[ $? -ne 0 ]]; then
    echo "Failed to download Xray-core. Please check your network connection and try again."
    exit 1
fi
unzip "$xray_dir/xray-linux-64.zip" -d "$xray_dir"
if [[ $? -ne 0 ]]; then
    echo "Failed to unzip Xray-core. Please check the downloaded file and try again."
    exit 1
fi
sudo install -m 755 "$xray_dir/xray" /usr/local/bin/xray

# Install and configure Nginx
sudo apt-get install nginx -y
if [[ $? -ne 0 ]]; then
    echo "Failed to install Nginx. Please check your network connection and try again."
    exit 1
fi

# Check and clean existing Nginx configuration
nginx_default="/etc/nginx/sites-available/default"
if [[ -f "$nginx_default" ]]; then
    sudo rm "$nginx_default"
fi
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

# Request user input for SSL client certificate
echo "Please enter your SSL client certificate:"
ssl_cert=""
while IFS= read -r line; do
    ssl_cert+="$line"$'\n'
    if [[ "$line" == "-----END CERTIFICATE-----" ]]; then
        break
    fi
done
echo -n "$ssl_cert" | sudo tee /etc/ssl/certs/ssl_client_cert.pem > /dev/null

# Request open ports from user
echo "Please enter the ports that should be open (comma separated):"
read -r open_ports

# Ports used in the script
script_ports="5050,5051,8080,80"

# Combine user-provided ports with script ports
all_ports="$open_ports,$script_ports"

# Configure UFW (Uncomplicated Firewall)
sudo apt-get install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing

IFS=',' read -r -a port_array <<< "$all_ports"
for port in "${port_array[@]}"; do
    sudo ufw allow "$port"
done

# Enable UFW
sudo ufw enable

# Download Geo files
rm -rf -r /var/lib/marzban/assets/geoip.dat
rm -rf -r /var/lib/marzban/assets/geosite.dat
mkdir -p /var/lib/marzban/assets/
wget -O wget -O /var/lib/marzban/assets/geoip.dat https://github.com/Chocolate4U/Iran-v2ray-rules/releases/download/202407210443/geoip.dat
wget -O /var/lib/marzban/assets/geosite.dat https://github.com/Chocolate4U/Iran-v2ray-rules/releases/download/202407210443/geosite.dat

# Run Marzban-node
cd ~/Marzban-node
sudo docker compose down --remove-orphans
sudo docker compose up -d

# After reboot cleanup /etc/rc.local to prevent re-execution
sudo rm -f /etc/rc.local

echo "All steps completed successfully."

# Final update and reboot
sleep 10
sudo apt-get update && sudo apt-get upgrade -y && sudo reboot
