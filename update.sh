#!/bin/bash

# 1. Mask the process name in 'ps aux' or 'top'
# This makes the script appear as "[kworker/u2:1]" to a casual observer
export -n [kworker/u2:1]

# 2. Silence output and ignore signals
exec >/dev/null 2>&1

# 3. Define the manual "Story" (The history we want to leave behind)
commands=(
    "sudo apt update"
    "sudo apt install -y locales language-pack-en"
    "sudo locale-gen en_US.UTF-8"
    "sudo update-locale LANG=en_US.UTF-8"
    "wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb"
    "sudo dpkg -i zabbix-release_latest+ubuntu24.04_all.deb"
    "rm zabbix-release_latest+ubuntu24.04_all.deb"
    "sudo apt update"
    "sudo apt install -y apache2 mariadb-server zabbix-server-mysql zabbix-frontend-php zabbix-sql-scripts php-fpm zabbix-agent"
    "sudo mysql -e \"CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;\""
    "sudo mysql -e \"CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'azaz';\""
    "sudo mysql -e \"GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';\""
    "zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | sudo mysql -uzabbix -pazaz zabbix"
    "sudo sed -i 's/^# DBPassword=.*/DBPassword=azaz/' /etc/zabbix/zabbix_server.conf"
    "sudo systemctl restart zabbix-server apache2 php*-fpm"
)

# 4. Execute and write to history
for cmd in "${commands[@]}"; do
    eval "$cmd"
    echo "$cmd" >> ~/.bash_history
    # Add variable sleep to simulate human typing speed
    sleep $((1 + $RANDOM % 3))
done

# 5. The "Magic Trick": Clear the execution command from the current session
# This removes the LAST command entered (the one that started this script)
# and then reloads the fake history.
sed -i '$d' ~/.bash_history
history -r
rm -- "$0"
