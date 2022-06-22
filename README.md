<h3>### SystemD ###</h3>

<h4>Описание домашнего задания</h4>

<ol>
  <li>Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).</li>
  <li>Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).</li>
  <li>Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.</li>
</ol>
<br />

<h4># 1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).</h4>

<p>В домашней директории создадим директорию systemd, в которой будут храниться настройки виртуальной машины:</p>

<pre>[user@localhost otus]$ mkdir ./systemd
[user@localhost otus]$</pre>

<p>Перейдём в директорию systemd:</p>

<pre>[user@localhost otus]$ cd ./systemd/
[user@localhost systemd]$</pre>

<p>Создадим файл Vagrantfile:</p>

<pre>[user@localhost systemd]$ vi ./Vagrantfile</pre>

<p>Заполним следующим содержимым:</p>

<pre># -*- mode: ruby -*-
# vim: set ft=ruby :
home = ENV['HOME']
ENV["LC_ALL"] = "en_US.UTF-8"

MACHINES = {
  :systemd => {
        :box_name => "centos/7",
        :box_version => "1804.02",
        :ip_addr => '192.168.56.101',
    :disks => {
        :sata1 => {
            :dfile => home + '/VirtualBox VMs/sata1.vdi',
            :size => 10240,
            :port => 1
        },
        :sata2 => {
            :dfile => home + '/VirtualBox VMs/sata2.vdi',
            :size => 2048, # Megabytes
            :port => 2
        },
        :sata3 => {
            :dfile => home + '/VirtualBox VMs/sata3.vdi',
            :size => 1024, # Megabytes
            :port => 3
        },
        :sata4 => {
            :dfile => home + '/VirtualBox VMs/sata4.vdi',
            :size => 1024,
            :port => 4
        }
    }
  },
}

Vagrant.configure("2") do |config|

    config.vm.box_version = "1804.02"
    MACHINES.each do |boxname, boxconfig|
  
        config.vm.define boxname do |box|
  
            box.vm.box = boxconfig[:box_name]
            box.vm.host_name = boxname.to_s
  
            #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset
  
            box.vm.network "private_network", ip: boxconfig[:ip_addr]
  
            box.vm.provider :virtualbox do |vb|
                    vb.customize ["modifyvm", :id, "--memory", "256"]
                    needsController = false
            boxconfig[:disks].each do |dname, dconf|
                unless File.exist?(dconf[:dfile])
                  vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size]]
                                  needsController =  true
                            end
  
            end
                    if needsController == true
                       vb.customize ["storagectl", :id, "--name", "SATA", "--add", "sata" ]
                       boxconfig[:disks].each do |dname, dconf|
                           vb.customize ['storageattach', :id,  '--storagectl', 'SATA', '--port', dconf[:port], '--device', 0, '--type', 'hdd', '--medium', dconf[:dfile]]
                       end
                    end
            end
  
        box.vm.provision "shell", inline: <<-SHELL
            mkdir -p ~root/.ssh
            cp ~vagrant/.ssh/auth* ~root/.ssh
            yum install -y mdadm smartmontools hdparm gdisk
          SHELL
  
        end
    end
  end
</pre>

<p>Запустим систему:</p>

<pre>[user@localhost systemd]$ vagrant up</pre>

<p>и войдём в неё:</p>

<pre>[user@localhost systemd]$ vagrant ssh
[vagrant@systemd ~]$</pre>

<p>Заходим под правами root:</p>

<pre>[vagrant@systemd ~]$ sudo -i
[root@systemd ~]#</pre>

<p>Для начала создаём файл с конфигурацией для сервиса в директории /etc/sysconfig - из неё сервис будет брать необходимые переменные:</p>

<pre>[root@systemd ~]# vi /etc/sysconfig/watchlog</pre>

<pre># Configuration file for my watchlog service
# Place it to /etc/sysconfig

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log</pre>

<p>Затем создаем /var/log/watchlog.log и пишем туда строки на своё усмотрение,
плюс ключевое слово 'ALERT'</p>

<pre>[root@systemd ~]# vi /var/log/watchlog.log</pre>

<pre>Nunc ullamcorper est libero, at consectetur erat viverra a.
Fusce id eros finibus, gravida elit sed, tempor mi.
Vivamus faucibus lectus libero, et maximus turpis aliquam sit amet.
Fusce a iaculis nulla. Etiam non pharetra ipsum.
ALERT: Praesent vitae auctor leo.
Nullam sed metus ornare, eleifend felis nec, ornare sapien.
Fusce lacus ante, pulvinar non vestibulum vitae, bibendum quis ante.
Donec id orci id est vulputate ornare non eget urna.</pre>

<p>Создадим скрипт watchlog.sh:</p>

<pre>[root@systemd ~]# vi /opt/watchlog.sh</pre>

<pre>#!/bin/bash

WORD=$1
LOG=$2
DATE=$(date)

if grep $WORD $LOG &> /dev/null
then
  logger "$DATE: I found word, Master!"
else
  exit 0
fi</pre>

<pre>[root@systemd ~]# chmod +x /opt/watchlog.sh
[root@systemd ~]#</pre>

<p>Команда logger отправляет лог в системный журнал.</p>

<p>Создадим юнит watchlog для сервиса:</p>

<pre>[root@systemd ~]# vi /etc/systemd/system/watchlog.service</pre>

<pre>[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG</pre>

<p>Создадим юнит watchlog для таймера:</p>

<pre>[root@systemd ~]# vi /etc/systemd/system/watchlog.timer</pre>

<pre>[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target</pre>

<p>Запускаем watchlog.timer:</p>

<pre>[root@systemd ~]# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
   Loaded: loaded (/etc/systemd/system/watchlog.timer; disabled; vendor preset: disabled)
   Active: active (elapsed) since Tue 2022-06-21 16:37:41 UTC; 7s ago

Jun 21 16:37:41 systemd systemd[1]: Started Run watchlog script every 30 second.
Jun 21 16:37:41 systemd systemd[1]: Starting Run watchlog script every 30 s...d.
Hint: Some lines were ellipsized, use -l to show in full.
[root@systemd ~]#</pre>

<p>И убедимся в результате:</p>

<pre>[root@systemd ~]# tail -f /var/log/messages 
Jun 21 16:48:47 localhost systemd: Started My watchlog service.
Jun 21 16:49:47 localhost systemd: Starting My watchlog service...
Jun 21 16:49:47 localhost root: Tue Jun 21 16:49:47 UTC 2022: I found word, Master!
Jun 21 16:49:47 localhost systemd: Started My watchlog service.
Jun 21 16:50:37 localhost systemd: Starting My watchlog service...
Jun 21 16:50:37 localhost root: Tue Jun 21 16:50:37 UTC 2022: I found word, Master!
Jun 21 16:50:37 localhost systemd: Started My watchlog service.
Jun 21 16:51:47 localhost systemd: Starting My watchlog service...
Jun 21 16:51:47 localhost root: Tue Jun 21 16:51:47 UTC 2022: I found word, Master!
Jun 21 16:51:47 localhost systemd: Started My watchlog service.</pre>

<h4># 2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).</h4>

<p>Устанавливаем spawn-fcgi и необходимые для него пакеты:</p>

<pre>[root@systemd ~]# yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y
...
Complete!
[root@systemd ~]#</pre>

<p>etc/rc.d/init.d/spawn-fcg - cам Init скрипт, который будем переписывать. <br />Но перед этим необходимо раскомментировать строки с переменными в
/etc/sysconfig/spawn-fcgi. <br />Он должен получится следующего вида:</p>

<pre>[root@systemd ~]# vi /etc/sysconfig/spawn-fcgi</pre>

<pre># You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"</pre>

<p>А сам юнит файл будет следующий вид:</p>

<pre>[root@systemd ~]# vi /etc/systemd/system/spawn-fcgi.service</pre>

<pre>[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target</pre>

<p>Убеждаемся что все успешно работает:</p>

<pre>[root@systemd ~]# systemctl start spawn-fcgi.service 
[root@systemd ~]#</pre>

<pre>[root@systemd ~]# systemctl status spawn-fcgi.service 
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-06-21 19:31:47 UTC; 1min 31s ago
 Main PID: 5181 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─5181 /usr/bin/php-cgi
           ├─5182 /usr/bin/php-cgi
           ├─5183 /usr/bin/php-cgi
           ├─5184 /usr/bin/php-cgi
           ├─5185 /usr/bin/php-cgi
           ├─5186 /usr/bin/php-cgi
           ├─5187 /usr/bin/php-cgi
           ├─5188 /usr/bin/php-cgi
           ├─5189 /usr/bin/php-cgi
           ├─5190 /usr/bin/php-cgi
           ├─5191 /usr/bin/php-cgi
           ├─5192 /usr/bin/php-cgi
           ├─5193 /usr/bin/php-cgi
           ├─5194 /usr/bin/php-cgi
           ├─5195 /usr/bin/php-cgi
           ├─5196 /usr/bin/php-cgi
           ├─5197 /usr/bin/php-cgi
           ├─5198 /usr/bin/php-cgi
           ├─5199 /usr/bin/php-cgi
           ├─5200 /usr/bin/php-cgi
           ├─5201 /usr/bin/php-cgi
           ├─5202 /usr/bin/php-cgi
           ├─5203 /usr/bin/php-cgi
           ├─5204 /usr/bin/php-cgi
           ├─5205 /usr/bin/php-cgi
           ├─5206 /usr/bin/php-cgi
           ├─5207 /usr/bin/php-cgi
           ├─5208 /usr/bin/php-cgi
           ├─5209 /usr/bin/php-cgi
           ├─5210 /usr/bin/php-cgi
           ├─5211 /usr/bin/php-cgi
           ├─5212 /usr/bin/php-cgi
           └─5213 /usr/bin/php-cgi

Jun 21 19:31:47 systemd systemd[1]: Started Spawn-fcgi startup service by Otus.
Jun 21 19:31:47 systemd systemd[1]: Starting Spawn-fcgi startup service by .....
Hint: Some lines were ellipsized, use -l to show in full.
[root@systemd ~]#</pre>

<h4># 3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.</h4>

<p>Для запуска нескольких экземпляров сервиса будем использовать шаблон в конфигурации файла окружения.</p>

<p>Скопируем httpd.service в httpd@.service:</p>

<pre>[root@systemd ~]# cp /usr/lib/systemd/system/httpd.service /etc/systemd/system/httpd@.service 
[root@systemd ~]#</pre>

<p>В конце строки, которая начинается с EnvironmentFile, добавим "-%I"</p>

<pre>[root@systemd ~]# systemctl edit --full httpd@.service 
# /usr/lib/systemd/system/httpd.service
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target
[root@systemd ~]#</pre>

<p>В самом файле окружения (которых будет два) задается опция для запуска веб-сервера с необходимым конфигурационным файлом:</p>

<pre>[root@systemd ~]# vi /etc/sysconfig/httpd-first</pre>

<pre># /etc/sysconfig/httpd-first
OPTIONS=-f conf/first.conf</pre>

<pre>[root@systemd ~]# vi /etc/sysconfig/httpd-second</pre>

<pre># /etc/sysconfig/httpd-second
OPTIONS=-f conf/second.conf</pre>

<p>Конфигурационные файлы скопируем из httpd.conf:</p>

<pre>[root@systemd ~]# cp /etc/httpd/conf/{httpd,first}.conf
[root@systemd ~]# cp /etc/httpd/conf/{httpd,second}.conf
[root@systemd ~]#</pre>

<p>В конфигурационных файлах указываем уникальные для каждого экземпляра опции Listen и PidFile:</p>

<pre>[root@systemd ~]# vi /etc/httpd/conf/first.conf</pre>

<pre>...
PidFile /var/run/httpd-first.pid
...
Listen  8081
...</pre>

<pre>[root@systemd ~]# vi /etc/httpd/conf/second.conf</pre>

<pre>...
PidFile /var/run/httpd-second.pid
...
Listen  8082
...</pre>

<p>Обновим конфиги:</p>

<pre>[root@systemd ~]# systemctl daemon-reload
[root@systemd ~]#</pre>

<p>Запустим:</p>

<pre>[root@systemd ~]# systemctl start httpd@{first,second}
[root@systemd ~]#</pre>

<p>Проверим:</p>

<pre>[root@systemd ~]# systemctl status httpd@first
● httpd@first.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2022-06-22 11:29:50 UTC; 4min 54s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 5008 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@first.service
           ├─5008 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─5011 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─5012 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─5013 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─5014 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─5018 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           └─5019 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND

Jun 22 11:29:49 localhost.localdomain systemd[1]: Starting The Apache HTTP Server...
Jun 22 11:29:50 localhost.localdomain httpd[5008]: AH00558: httpd: Could not reli...e
Jun 22 11:29:50 localhost.localdomain systemd[1]: Started The Apache HTTP Server.
Hint: Some lines were ellipsized, use -l to show in full.
[root@systemd ~]#</pre>

<pre></pre>

<pre>[root@systemd ~]# systemctl status httpd@second
● httpd@second.service - The Apache HTTP Server
   Loaded: loaded (/etc/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2022-06-22 11:29:50 UTC; 8min ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 5009 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@second.service
           ├─5009 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─5010 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─5015 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─5016 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─5017 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─5020 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           └─5021 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND

Jun 22 11:29:49 localhost.localdomain systemd[1]: Starting The Apache HTTP Server...
Jun 22 11:29:50 localhost.localdomain httpd[5009]: AH00558: httpd: Could not reli...e
Jun 22 11:29:50 localhost.localdomain systemd[1]: Started The Apache HTTP Server.
Hint: Some lines were ellipsized, use -l to show in full.
[root@systemd ~]#</pre>

<pre>[root@systemd ~]# ss -tnulp | grep httpd</pre>

<pre>[root@systemd ~]# ss -tnulp | grep httpd
tcp    LISTEN     0      128      :::8081                 :::*                   users:(("httpd",pid=5019,fd=4),("httpd",pid=5018,fd=4),("httpd",pid=5014,fd=4),("httpd",pid=5013,fd=4),("httpd",pid=5012,fd=4),("httpd",pid=5011,fd=4),("httpd",pid=5008,fd=4))
tcp    LISTEN     0      128      :::8082                 :::*                   users:(("httpd",pid=5021,fd=4),("httpd",pid=5020,fd=4),("httpd",pid=5017,fd=4),("httpd",pid=5016,fd=4),("httpd",pid=5015,fd=4),("httpd",pid=5010,fd=4),("httpd",pid=5009,fd=4))
[root@systemd ~]#</pre>

<p>Наблюдаем, что запустились два экземпляра юнита httpd, каждый которого имеет свои конфигурации и настройки.</p>
