#!/bin/bash

# Disable selinux
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
setenforce 0

#---------- Part 1. watchlog setup ---------

# Copy files
cp /vagrant/files/watchlog /etc/sysconfig/
cp /vagrant/files/watchlog.log /var/log/
cp /vagrant/files/watchlog.sh /opt/
cp /vagrant/files/watchlog.service /etc/systemd/system/
cp /vagrant/files/watchlog.timer /etc/systemd/system/

# Modify script to execute
chmod +x /opt/watchlog.sh

# Start and enable autostart watchlog service
systemctl start watchlog.timer
systemctl enable watchlog.timer
systemctl start watchlog.service
systemctl enable watchlog.service

#---------- Part 2. spawn-fcgi setup ---------

# Required packages installation
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y

# Modify config file
sed -i "s/#SOCKET=/SOCKET=/; s/#OPTIONS=/OPTIONS=/" /etc/sysconfig/spawn-fcgi

# Start and enable autostart spawn-fcgi service
systemctl start spawn-fcgi
systemctl enable spawn-fcgi

#---------- Part 3. httpdsetup ---------

# Copy and modify httpd service
cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@.service && sed -i "s!EnvironmentFile=/etc/sysconfig/httpd!EnvironmentFile=/etc/sysconfig/httpd-%I!" /etc/systemd/system/httpd@.service

# Create environment files for start web server with config files
echo -e "# /etc/sysconfig/httpd-first\nOPTIONS=-f conf/first.conf" > /etc/sysconfig/httpd-first
echo -e "# /etc/sysconfig/httpd-second\nOPTIONS=-f conf/second.conf" > /etc/sysconfig/httpd-second

# Copy and modify httpd config files
cp /etc/httpd/conf/{httpd,first}.conf && sed -i "s!Listen 80!Listen 8081!" /etc/httpd/conf/first.conf && echo "PidFile /var/run/httpd-first.pid" >> /etc/httpd/conf/first.conf
cp /etc/httpd/conf/{httpd,second}.conf && sed -i "s!Listen 80!Listen 8082!" /etc/httpd/conf/second.conf && echo "PidFile /var/run/httpd-second.pid" >> /etc/httpd/conf/second.conf

# Reload service config
systemctl daemon-reload

# Start and enable autostart httpd services
systemctl start httpd@{first,second}
systemctl enable httpd@{first,second}


