#!/bin/bash

# ==============================================================================
# Ultimate Zabbix Installation Script (Refined & Fixed)
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION ---
DB_PASS="azaz"
DOMAIN="monitor.lab-smk.xyz"
TIMEZONE="Asia/Jakarta"
LOG_FILE="/var/log/zabbix_install.log"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# Ensure Root
[[ $EUID -ne 0 ]] && error "Run as root!"

# ==============================================================================
# 1. PRE-FLIGHT & LOCALE FIX (Fixes the en_US error)
# ==============================================================================
log "Preparing system environment..."
apt-get update -qq
apt-get install -y -qq locales language-pack-en

log "Generating and setting en_US.UTF-8 locale..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# ==============================================================================
# 2. OS DETECTION & REPO SETUP
# ==============================================================================
OS_VERSION=$(lsb_release -rs)
log "Detected Ubuntu $OS_VERSION. Configuring Zabbix Repository..."

if [[ "$OS_VERSION" == "24.04" ]]; then
    # Zabbix 7.0 LTS for Noble
    Z_REPO="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb"
elif [[ "$OS_VERSION" == "22.04" ]]; then
    # Zabbix 6.0 LTS for Jammy
    Z_REPO="https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu22.04_all.deb"
else
    error "Unsupported OS version."
fi

wget -q "$Z_REPO" -O /tmp/zabbix-repo.deb
dpkg -i /tmp/zabbix-repo.deb
apt-get update -qq

# ==============================================================================
# 3. INSTALLATION
# ==============================================================================
log "Installing Apache, MariaDB, and Zabbix Components..."
apt-get install -y -qq apache2 mariadb-server php-mysql php-fpm \
    zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf \
    zabbix-sql-scripts zabbix-agent snmpd

# ==============================================================================
# 4. DATABASE SETUP
# ==============================================================================
log "Configuring MariaDB..."
systemctl enable --now mariadb

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EOF

# Check if DB is empty before importing
if ! mysql -uzabbix -p"${DB_PASS}" -e "use zabbix; select * from users;" >/dev/null 2>&1; then
    log "Importing Zabbix Schema (this takes a moment)..."
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p"${DB_PASS}" zabbix
else
    warn "Database tables already exist. Skipping import."
fi

# ==============================================================================
# 5. CONFIGURATION FILES
# ==============================================================================
log "Applying Zabbix Server configurations..."
sed -i "s/^# DBPassword=.*/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf

log "Setting PHP Timezone in Apache/Zabbix config..."
# We update the Zabbix-specific PHP config for Apache
sed -i "s|# php_value date.timezone.*|php_value date.timezone ${TIMEZONE}|" /etc/zabbix/apache.conf

# ==============================================================================
# 6. APACHE VHOST & SSL
# ==============================================================================
log "Configuring Apache VirtualHost..."
a2enmod ssl rewrite > /dev/null 2>&1

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/lab.key -out /etc/ssl/certs/lab.crt \
    -subj "/CN=${DOMAIN}" 2>/dev/null

cat > /etc/apache2/sites-available/monitor.conf <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>

<VirtualHost *:443>
    ServerName ${DOMAIN}
    DocumentRoot /usr/share/zabbix
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/lab.crt
    SSLCertificateKeyFile /etc/ssl/private/lab.key
    
    <Directory "/usr/share/zabbix">
        Options FollowSymLinks
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
EOF

a2dissite 000-default.conf zabbix.conf > /dev/null 2>&1 || true
a2ensite monitor.conf > /dev/null 2>&1

# ==============================================================================
# 7. FINALIZING
# ==============================================================================
log "Setting Firewall and restarting services..."
ufw allow 80,443,10050,10051/tcp > /dev/null 2>&1

# Restart everything to ensure Locales and Configs are loaded
systemctl restart zabbix-server zabbix-agent apache2 php*-fpm
systemctl enable zabbix-server zabbix-agent apache2

log "DONE! Your Zabbix is ready."
log "URL: https://${DOMAIN}"
log "Default Login: Admin / zabbix"
