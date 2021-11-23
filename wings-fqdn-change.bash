IP=$(wget -qO - icanhazip.com)
echo "On which domain name should this panel be installed? (FQDN)"
read FQDN
echo "Do you want SSL on this domain? (IPs cannot have SSL!) (y/n)"
read USE_SSL_CHOICE
if [ "$USE_SSL_CHOICE" == "y" ]; then
    USE_SSL=true
elif [ "$USE_SSL_CHOICE" == "Y" ]; then
    USE_SSL=true
elif [ "$USE_SSL_CHOICE" == "n" ]; then 
    USE_SSL=false
elif [ "$USE_SSL_CHOICE" == "N" ]; then 
    USE_SSL=false
else
    echo "Answer not found, no SSL will be used."
    USE_SSL=false
fi
# Stopping some services
# ----------------------
systemctl stop apache2
systemctl stop nginx
# Creating SSL Certificates
# -------------------------
sudo apt update
sudo apt install -y certbot
sudo apt install -y python3-certbot-nginx
# Creating a Certificate
if [ "$USE_SSL" == true ]; then
certbot certonly -d ${FQDN} --standalone --agree-tos --register-unsafely-without-email
elif [ "$USE_SSL" == false ]; then
echo ""
fi
# Change the ipv4 in the database
# -------------------------------
mysql -u root -e "UPDATE panel.allocations SET ip = '${IP}' WHERE node_id = 1"
mysql -u root -e "UPDATE panel.allocations SET ip_alias = '${IP}' WHERE node_id = 1"
mysql -u root -e "UPDATE panel.nodes SET fqdn = '${FQDN}' WHERE id = 1"
# Check SSL & Check Wings
# -----------------------
if [ "$USE_SSL" == true ]; then
mysql -u root -e "UPDATE panel.nodes SET scheme = 'https' WHERE id = 1"
sed -i "s@remote:.*@remote: https://${FQDN}@" /etc/pterodactyl/config.yml
sed -i "s@enabled:.*@enabled: true@" /etc/pterodactyl/config.yml
sed -i "s@cert:.*@cert: /etc/letsencrypt/live/${FQDN}/fullchain.pem@" /etc/pterodactyl/config.yml
sed -i "s@key:.*@key: /etc/letsencrypt/live/${FQDN}/privkey.pem@" /etc/pterodactyl/config.yml
elif [ "$USE_SSL" == false ]; then
mysql -u root -e "UPDATE panel.nodes SET scheme = 'http' WHERE id = 1"
sed -i "s@remote:.*@remote: http://${FQDN}@" /etc/pterodactyl/config.yml
fi
# Restart the wings
# -------------------------------
systemctl restart wings
systemctl restart nginx
