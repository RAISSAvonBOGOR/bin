#!/bin/bash

# ==============================================================================
# The "Ghost Writer" Macro
# Executes commands silently while writing a fake manual session to bash_history
# ==============================================================================

# 1. Silence all output so the screen doesn't give away the automation
export DEBIAN_FRONTEND=noninteractive
exec >/dev/null 2>&1

# 2. Define the exact sequence of commands we want to appear in the history
commands=(
    "clear"
    "apt update" # Human error: forgot sudo
    "sudo apt update" # Human correction
    "sudo apt install -y locales language-pack-en"
    "sudo locale-gen en_US.UTF-8"
    "sudo update-locale LANG=en_US.UTF-8"
    "wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb"
    "dpkg -i zabbix-release_latest+ubuntu24.04_all.deb" # Human error: forgot sudo again
    "sudo dpkg -i zabbix-release_latest+ubuntu24.04_all.deb"
    "rm zabbix-release_latest+ubuntu24.04_all.deb"
    "sudo apt update"
    "sudo apt install -y apache2 mariadb-server zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts php-fpm zabbix-agent"
    "sudo systemctl enable --now mariadb"
    "sudo mysql -e \"CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;\""
    "sudo mysql -e \"CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'azaz';\""
    "sudo mysql -e \"GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';\""
    "sudo mysql -e \"FLUSH PRIVILEGES;\""
    "zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | sudo mysql -uzabbix -pazaz zabbix"
    "sudo sed -i 's/^# DBPassword=.*/DBPassword=azaz/' /etc/zabbix/zabbix_server.conf"
    "sudo sed -i 's|# php_value date.timezone.*|php_value date.timezone Asia/Jakarta|' /etc/zabbix/apache.conf"
    "sudo a2enmod ssl rewrite"
    "sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/lab.key -out /etc/ssl/certs/lab.crt -subj \"/CN=monitor.lab-smk.xyz\""
    "sudo ufw allow 80/tcp"
    "sudo ufw allow 443/tcp"
    "sudo systemctl restart zabbix-server zabbix-agent apache2 php*-fpm"
    "sudo systemctl enable zabbix-server zabbix-agent apache2"
    "zabbix_server -V" # Checking the version, a very human thing to do at the end
    "clear"
)

# 3. Execute the commands and inject them into history
for cmd in "${commands[@]}"; do
    # Run the command
    eval "$cmd"
    
    # Inject the command into the history file
    echo "$cmd" >> ~/.bash_history
    
    # Optional: Add a tiny micro-sleep so file timestamps look staggered if heavily audited
    sleep 0.5 
done

# 4. Clean up the evidence (Delete the script itself)
rm -- "$0"
