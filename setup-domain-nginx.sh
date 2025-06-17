#!/bin/bash

DOMAIN=$1
NGINX_PORT=81

echo "Cấu hình tên miền $DOMAIN trong WSL..."
echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts

echo "Cài đặt Nginx..."
sudo apt update
sudo apt install -y nginx

echo "Tạo thư mục website..."
sudo mkdir -p /var/www/$DOMAIN
echo "<h1>Chào mừng đến với $DOMAIN</h1>" | sudo tee /var/www/$DOMAIN/index.html

echo "Cấu hình Virtual Host cho Nginx..."
sudo tee /etc/nginx/sites-available/$DOMAIN <<EOL
server {
    listen $NGINX_PORT;
    server_name $DOMAIN;

    root /var/www/$DOMAIN;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

echo "Khởi động lại Nginx..."
sudo systemctl restart nginx

echo "✅ Cấu hình hoàn tất! Truy cập: http://$DOMAIN:$NGINX_PORT"
