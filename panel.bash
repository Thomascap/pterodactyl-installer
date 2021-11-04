apt update

FQDN=`hostname --ip-address`
URL="http://${FQDN}"
USE_SSL=false
EMAIL="pterodactyl@mynode.nl"
MYSQL_USER="pterodactyl"
MYSQL_PASSWORD="rwbAiPZ3iv"
MYSQL_DATABASE="panel"
MYSQL_USER_PANEL="pterodactyl"
MYSQL_PASSWORD_PANEL="rwbAiPZ3iv"
USER_EMAIL="admin@gmail.com"
USER_USERNAME="admin"
USER_FIRSTNAME="admin"
USER_LASTNAME="admin"
USER_PASSWORD="rwbAiPZ3iv"

# Pas alle url's aan

# Example Dependency Installation
# -------------------------------
# Add "add-apt-repository" command
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
# Add additional repositories for PHP, Redis, and MariaDB
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:chris-lea/redis-server
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
# Update repositories list
apt update
# Add universe repository if you are on Ubuntu 18.04
apt-add-repository universe
# Install Dependencies
apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

# Installing Composer
# -------------------
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Download Files
# --------------
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Installation
# ------------
# Database Configuration
mysql -u root -e "CREATE USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';"
mysql -u root -e "CREATE DATABASE ${MYSQL_DATABASE};"
mysql -u root -e "GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "CREATE USER '${MYSQL_USER_PANEL}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD_PANEL}';"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER_PANEL}'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"
cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force

# Environment Configuration
# -------------------------
if [ "$USE_SSL" == true ]; then
php artisan p:environment:setup --author=$EMAIL --url=https://$FQDN --timezone=Europe/Amsterdam --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass=null --redis-port=6379  --settings-ui=true
elif [ "$USE_SSL" == false ]; then
php artisan p:environment:setup --author=$EMAIL --url=http://$FQDN --timezone=Europe/Amsterdam --cache=redis --session=redis --queue=redis --redis-host=127.0.0.1 --redis-pass=null --redis-port=6379  --settings-ui=true
fi
php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=$MYSQL_DATABASE --username=$MYSQL_USER --password=$MYSQL_PASSWORD

# Database Setup
# --------------
y | php artisan migrate --seed --force

# Add The First User
# --------------
php artisan p:user:make --email=$USER_EMAIL --username=$USER_USERNAME --name-first=$USER_FIRSTNAME --name-last=$USER_LASTNAME --password=$USER_PASSWORD --admin=1

# Set Permissions
# ---------------
chown -R www-data:www-data /var/www/pterodactyl/*

# Queue Listeners
# ---------------
# Crontab Configuration
cronjob="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
(crontab -u root -l; echo "$cronjob" ) | crontab -u root -
# Create Queue Worker
curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/Thomascap/pterodactyl-installer/main/pteroq.service
sudo systemctl enable --now redis-server
sudo systemctl enable --now pteroq.service

# Stop & Remove Apache2
# ----------------------
systemctl stop apache2
apt -y remove apache2

# Creating SSL Certificates
# -------------------------
sudo apt update
sudo apt install -y certbot
sudo apt install -y python3-certbot-nginx
# Creating a Certificate
if [ "$USE_SSL" == true ]; then
certbot certonly -d ${FQDN} --non-interactive --agree-tos -m ${EMAIL}
elif [ "$USE_SSL" == false ]; then
echo ""
fi

# Webserver Configuration
# -----------------------
if [ "$USE_SSL" == true ]; then
curl -o /etc/nginx/sites-available/pterodactyl.conf https://raw.githubusercontent.com/Thomascap/pterodactyl-installer/main/pterodactyl-ssl.conf
sed -i -e "s/<domain>/${FQDN}/g" /etc/nginx/sites-available/pterodactyl.conf
elif [ "$USE_SSL" == false ]; then
curl -o /etc/nginx/sites-available/pterodactyl.conf https://raw.githubusercontent.com/Thomascap/pterodactyl-installer/main/pterodactyl.conf
sed -i -e "s/<domain>/${FQDN}/g" /etc/nginx/sites-available/pterodactyl.conf
fi
# Enabling Configuration
sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
systemctl restart nginx


