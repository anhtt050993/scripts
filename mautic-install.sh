#!/bin/bash
echo "Chào mừng bạn đen với script cai dat Mautic.
Vui long tra loi cau hoi sau de tiep tuc!"
sleep 2

read -p "Tuan Anh có đẹp trai không? (yes/no): " answer

if [ "$answer" = "no" ]; then
    echo "Ban không xung dang su dung script này"
    exit 1
elif [ "$answer" = "yes" ]; then
    echo "Ban có dôi mat that tinh tuong
          Mòi ban tiep tuc lam theo huong dan"
else echo "Câu tra? loi không hop le"
exit 1
fi
sleep 2

read -p "Nhap dia chi trang web cua Mautic: " mautic
read -p "Nhap database muon tao cho Mautic: " mautic_db
read -p "Nhap user(mariadb) muon tao de quan ly database Mautic: " mautic_db_user
echo "password default cho user tren la 'password'"
sleep 2
cat <<EOF | sudo tee /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.6/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

cat <<EOF | sudo tee /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
EOF
yum repolist
yum install nginx wget unzip yum-utils net-tools -y
systemctl start nginx
cd /tmp
wget https://github.com/mautic/mautic/releases/download/4.4.9/4.4.9.zip
mkdir -p /usr/share/nginx/mautic
unzip 4.4.9.zip -d /usr/share/nginx/mautic/
sudo tee /etc/nginx/conf.d/mautic.conf > /dev/null <<EOF
server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  $mautic;
        root         /usr/share/nginx/mautic;

        location / {
                try_files \$uri /index.php\$is_args\$args;
        }

        location ~ \\.php$ {
        fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;  # Replace with your PHP-FPM socket path
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_split_path_info ^(.+.php)(/.+)$;
        }
    }
EOF

chown -R nginx:nginx /etc/nginx /usr/share/nginx
yum install epel-release -y
yum install https://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
sudo yum-config-manager --enable remi-php80
sudo yum-config-manager --disable remi-php54
yum install -y  mariadb-server mariadb php php-fpm php-mysqlnd php-gd php-intl php-mbstring php-json php-iconv php-xml php-curl
systemctl start php-fpm
systemctl enable php-fpm
mkdir -p /var/run/php-fpm
sed -i 's/apache/nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/listen =/;listen =/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.group = nobody/listen.group = nginx/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.mode/listen.mode/g' /etc/php-fpm.d/www.conf
sed -i '/9000/a listen = /var/run/php-fpm/php-fpm.sock' /etc/php-fpm.d/www.conf
systemctl start mariadb
mysql -u root -e "CREATE DATABASE $mautic_db;"
mysql -u root <<EOF
CREATE USER '$mautic_db_user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON $mautic_db.* TO '$mautic_db_user'@'localhost';
FLUSH PRIVILEGES;
EOF
systemctl enable nginx
systemctl enable mariadb
systemctl enable php-fpm
chown -R nginx:nginx /var/lib/php
systemctl restart php-fpm
systemctl restart nginx
