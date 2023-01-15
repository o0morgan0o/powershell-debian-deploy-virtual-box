
function Configure-FileServerDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId
    )

    $FILE_SERVER_IP_ADDRESS = "192.168.58.20"
    $SUBNET = "192.168.58.0"
    $SUBNET_MASK = "255.255.255.0"
    $MACHINE_PORT = 2223

    # create backups of config files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/network/interfaces /etc/network/interfaces.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ls -la /etc/network/"

    # =================================================================================================================
    # set hostnames
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static eas-srv-fmail" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --pretty eas-srv-fmail" 

    # =================================================================================================================
    # set ip configuration
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '# set enp0s8' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
allow-hotplug enp0s8
iface enp0s8 inet static
address $FILE_SERVER_IP_ADDRESS
network $SUBNET
netmask $SUBNET_MASK
dns-nameservers $DHCP_IP_ADDRESS 8.8.8.8
dns-search eas.lan
' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/network/interfaces" 
    # check command
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/network/interfaces" 
    # restart network
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ifdown enp0s8;sudo ifup enp0s8"; 

    # =================================================================================================================
    # set up ftp server
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt install proftpd -y"
    # create backup of config file
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/proftpd/proftpd.conf /etc/proftpd/proftpd.conf.bak"
    # We send the configuration via SCP and we move to the correct destination
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\proftpd.conf -Destination ~ -Verbose -AcceptKey
    # We move and overwrite the proftpd.conf file
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/proftpd.conf /etc/proftpd/proftpd.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/proftpd/proftpd.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/proftpd/proftpd.conf"
    # Restart du service proftpd
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service proftpd restart"
    # Création ftpgroup
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo addgroup ftpgroup"
    # Création du user qui servira le share
    # On crée un user de façon silencieuse, en passant le mot de passe en paramètre
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents/eas"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents/eas/evenements"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents/eas/evenements/old"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents/eas/evenements/2021"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents/eas/fiches-jeux"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/documents/Partenaires"
    # Second arborescence
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois/photos"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois/photos/old"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois/photos/2021"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois/videos"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois/videos/old"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /home/ftpshare/tournois/videos/2021"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo adduser ftpshare -shell /bin/false -home /home/ftpshare -ingroup ftpgroup -gecos `"`" -disabled-password -q"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown -R ftpshare:ftpgroup /home/ftpshare"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown -R ftpshare:ftpgroup /home/ftpshare"
    # We add users allowed to the ftpgroup
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo usermod -a -G ftpgroup admin"

    # =================================================================================================================
    # setup mail server
    # =================================================================================================================
    # Preparation
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get update -y"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y apache2 "
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y php7.4"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y mariadb-server"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y php7.4-mysql"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y php7.4-curl"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y php7.4-mbstring"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y php7.4-imap"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y php7.4-xml"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y tree"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y mailutils"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service apache2 restart"
    # We install postfix quietly thanks to debconf-set-selections 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'postfix postfix/mailname string smtp.eas.lan' | sudo debconf-set-selections"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'postfix postfix/main_mailer_type string `"Internet Site`"' | sudo debconf-set-selections"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y postfix"
    # installation of dovecot
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-managesieved"
    # Creation of group and user mail-handler
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo groupadd -g 888 mail-handler"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo useradd -g mail-handler -u 888 mail-handler -d /var/mail-handler -m"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/group | grep mail-handler"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/passwd | grep mail-handler"
    # Equivalent of mysql_secure_installation
    $ROOT_PASSWORD = "Admin123"
    # $sqlCommand = "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"
    $sqlCommand += "DELETE FROM mysql.user WHERE User='';"
    $sqlCommand += "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    $sqlCommand += "DROP DATABASE IF EXISTS test; "
    $sqlCommand += "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `"${sqlCommand}`""
    # Creation of the postfix database
    $sqlCommand = ""
    $sqlCommand = "CREATE DATABASE postfix;"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `"${sqlCommand}`""
    $sqlCommand = "CREATE USER 'mailuser'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `"${sqlCommand}`""
    $sqlCommand = "GRANT SELECT ON ``postfix``.* TO ``mailuser``@``localhost``;"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `'${sqlCommand}`'"
    $sqlCommand = "CREATE USER 'postfix'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `"${sqlCommand}`""
    $sqlCommand = "GRANT ALL PRIVILEGES ON ``postfix``.* TO ``postfix``@``localhost`` ;"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `'${sqlCommand}`'"
    # flush privileges
    $sqlCommand = "FLUSH PRIVILEGES;"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mysql -e `"${sqlCommand}`""
    # download and install of postfixadmin
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "wget -O postfixadmin.tgz https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-3.3.10.tar.gz"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "tar -zxvf postfixadmin.tgz"
    # rename
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv postfixadmin-postfixadmin-3.3.10 postfixadmin"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv postfixadmin /srv/"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ln -s /srv/postfixadmin /var/www/html/postfixadmin"
    # creation of postfixadmin config file
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo touch /srv/postfixadmin/config.local.php"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
<?php
$CONF['database_type'] = 'mysqli';
$CONF['database_host'] = 'localhost';
$CONF['database_name'] = 'postfix';
$CONF['database_user'] = 'postfix';
$CONF['database_password'] = '$ROOT_PASSWORD';
$CONF['configured'] = true;
?>
' | sudo tee /srv/postfixadmin/config.local.php"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /srv/postfixadmin/config.local.php"
    # création templates_c
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /srv/postfixadmin/templates_c"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown  -R www-data /srv/postfixadmin/templates_c/"




}