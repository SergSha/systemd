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

<pre>[root@systemd ~]# cat > /etc/sysconfig/watchlog << EOF
> # Configuration file for my watchlog service
> # Place it to /etc/sysconfig
> # File and word in that file that we will be monit
> WORD="ALERT"
> LOG=/var/log/watchlog.log
> EOF
[root@systemd ~]#</pre>

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

<p>Создадим скрипт:</p>

<pre>[root@systemd ~]# cat > /opt/watchlog.sh</pre>

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

<p>Создадим юнит для сервиса:</p>

<pre>[root@systemd ~]# vi /etc/systemd/system/watchlog.service</pre>

<pre>[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG</pre>

<p>Создадим юнит для таймера:</p>

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

<pre>[root@systemd ~]# systemctl start watchlog.timer
[root@systemd ~]#</pre>

<pre>[root@systemd ~]# status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
   Loaded: loaded (/etc/systemd/system/watchlog.timer; disabled; vendor preset: disabled)
   Active: active (elapsed) since Tue 2022-06-21 13:59:39 UTC; 6s ago

Jun 21 13:59:39 localhost.localdomain systemd[1]: Started Run watchlog script ....
Jun 21 13:59:39 localhost.localdomain systemd[1]: Starting Run watchlog script....
Hint: Some lines were ellipsized, use -l to show in full.
[root@systemd ~]#</pre>

<p>И убедимся в результате:</p>

<pre>[root@systemd ~]# tail -f /var/log/messages
Jun 21 13:33:58 localhost dhclient[1638]: DHCPDISCOVER on eth1 to 255.255.255.255 port 67 interval 7 (xid=0x4d80dba7)
Jun 21 13:34:05 localhost dhclient[1638]: DHCPDISCOVER on eth1 to 255.255.255.255 port 67 interval 7 (xid=0x4d80dba7)
Jun 21 13:34:12 localhost dhclient[1638]: DHCPDISCOVER on eth1 to 255.255.255.255 port 67 interval 14 (xid=0x4d80dba7)
Jun 21 13:34:17 localhost NetworkManager[573]: <warn>  [1655818457.9956] dhcp4 (eth1): request timed out
Jun 21 13:34:17 localhost NetworkManager[573]: <info>  [1655818457.9957] dhcp4 (eth1): state changed unknown -> timeout
Jun 21 13:34:18 localhost NetworkManager[573]: <info>  [1655818457.9972] dhcp4 (eth1): canceled DHCP transaction, DHCP client pid 1638
Jun 21 13:34:18 localhost NetworkManager[573]: <info>  [1655818457.9973] dhcp4 (eth1): state changed timeout -> done
Jun 21 13:34:18 localhost NetworkManager[573]: <info>  [1655818457.9977] device (eth1): state change: ip-config -> failed (reason 'ip-config-unavailable', sys-iface-state: 'managed')
Jun 21 13:34:18 localhost NetworkManager[573]: <warn>  [1655818457.9981] device (eth1): Activation: failed for connection 'Wired connection 1'
Jun 21 13:34:18 localhost NetworkManager[573]: <info>  [1655818457.9987] device (eth1): state change: failed -> disconnected (reason 'none', sys-iface-state: 'managed')
[root@systemd ~]#</pre>

