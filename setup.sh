#!/usr/bin/env bash

# Replace events.pocketful.info with your domain
read -p "Enter your domain name (events.pocketful.info): " domain
read -p "Enter your email address for Let's Encrypt: " email

# Update configuration files
sed -i "s/events.pocketful.info/$domain/g" pretix.cfg
sed -i "s/events.pocketful.info/$domain/g" docker-compose.yml

# Install required packages
sudo yum update -y
sudo yum install -y docker nginx certbot python3-certbot-nginx
sudo systemctl enable docker nginx
sudo systemctl start docker nginx

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Portainer
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data portainer/portainer-ce:latest

# Create folder structure
sudo mkdir -p /var/pretix-data
sudo chown -R 15371:15371 /var/pretix-data
sudo mkdir -p /var/pgdata

# Setup Nginx
sudo mkdir -p /var/www/certbot
sudo cp nginx/pretix.conf /etc/nginx/conf.d/pretix.conf
sudo sed -i "s/events.pocketful.info/$domain/g" /etc/nginx/conf.d/pretix.conf

# Get SSL certificate
sudo certbot certonly --nginx -d $domain --non-interactive --agree-tos --email $email
sudo certbot renew --dry-run

# Config directory for pretix
sudo mkdir -p /etc/pretix
sudo cp ./pretix.cfg /etc/pretix/pretix.cfg
sudo chown -R 15371:15371 /etc/pretix
sudo chmod 0700 /etc/pretix/pretix.cfg

# Start services
sudo docker-compose up -d
sudo systemctl restart nginx

# Configure firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Create cron job
(sudo crontab -l 2>/dev/null; echo "15,45 * * * * /usr/bin/docker exec pretix.service pretix cron") | sudo crontab -
(sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -