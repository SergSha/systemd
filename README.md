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
  :lvm => {
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

<pre>[user@localhost lvm]$ vagrant up</pre>

<p>и войдём в неё:</p>

<pre>[user@localhost lvm]$ vagrant ssh
[vagrant@lvm ~]$</pre>

<p>Заходим под правами root:</p>

<pre>[vagrant@lvm ~]$ sudo -i
[root@lvm ~]#</pre>

<p>Перед началом работы поставьте пакет xfsdump - он будет необходим для снятия копии / тома.:</p>

<pre>[root@lvm ~]# yum -y install xfsdump
...
Installed:
  xfsdump.x86_64 0:3.1.7-1.el7                                                  

Dependency Installed:
  attr.x86_64 0:2.4.46-13.el7                                                   

Complete!
[root@lvm ~]#</pre>
