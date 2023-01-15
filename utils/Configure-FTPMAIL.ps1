
function Configure-FileServerDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId,
        [Parameter(Mandatory=$true)][String]$DNS_IP_ADDRESS
    )

    $FILE_SERVER_IP_ADDRESS = "192.168.58.20"
    $SUBNET = "192.168.58.0"
    $SUBNET_MASK = "255.255.255.0"
    $MACHINE_PORT = 2223
    $POSTFIXADMIN_PASSWORD = "Admin123"
    $ROOT_PASSWORD = "Admin123"

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
    # Set resolv.conf
    # =================================================================================================================
    Set-Resolv -DNS_IP_ADDRESS $DNS_IP_ADDRESS

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
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y postfix-mysql"
    # installation of dovecot
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install -y dovecot-mysql dovecot-imapd dovecot-pop3d dovecot-managesieved"
    # Creation of group and user mail-handler
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo groupadd -g 888 mail-handler"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo useradd -g mail-handler -u 888 mail-handler -d /var/mail-handler -m"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/group | grep mail-handler"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/passwd | grep mail-handler"
    # Equivalent of mysql_secure_installation
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
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ln -s /srv/postfixadmin/public /var/www/html/postfixadmin"
    # création templates_c
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /srv/postfixadmin/templates_c"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown  -R www-data /srv/postfixadmin/templates_c/"

    # we transfer template configuration via scp
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\postfixadmin\config.local.php -Destination ~ -Verbose -AcceptKey
    # we move config.local.php in correct folder
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f config.local.php /srv/postfixadmin/config.local.php"
    # we manually set up a temp php file for postfixadmin
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "touch ~/temp.php"
    # we create a file that we will execute with php
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '<?php echo password_hash(`"$POSTFIXADMIN_PASSWORD`", PASSWORD_DEFAULT); ?> ' | sudo tee ~/temp.php"
    # we execute the file with php and save the result in a temp file
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo -n `$(php ~/temp.php) > ~/TMP_SETUP_PASS"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '$ROOT_PASSWORD' | tee ~/TMP_USER_PASS"
    # we temporary give permissions on file config.local.php
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown admin:admin /srv/postfixadmin/config.local.php"
    # we replace the placeholders with the correct values. we use a script for that
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\postfixadmin\password_replacer_script.sh -Destination ~ -Verbose -AcceptKey
    # we give permissions to execute to our script
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chmod +x ~/password_replacer_script.sh"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "~/password_replacer_script.sh"
    # we remove temp files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo rm -rf ~/temp.php"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo rm -rf ~/TMP_*"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo rm -rf ~/password_replacer_script.sh"
    # restore root permission no config.local.php
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /srv/postfixadmin/config.local.php"
    # END OF POSTFIX ADMIN INSTALLATION
    # ====================================================================================================
    # NOW : User can setup its administrator by going to http://<ip>/postfixadmin/public/setup.php
    # ====================================================================================================
    
    # postfix configuration
    # we copy file mysql-virtual-mailbox-domains.cf
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\postfixadmin\mysql-virtual-mailbox-domains.cf -Destination ~ -Verbose -AcceptKey
    # We replace content of password
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sed -i 's/{{MAIL_USER_PASS}}/$POSTFIXADMIN_PASSWORD/g' ~/mysql-virtual-mailbox-domains.cf"
    # We move the file at its correct place
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/mysql-virtual-mailbox-domains.cf /etc/postfix/mysql-virtual-mailbox-domains.cf"
    # reset permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/postfix/mysql-virtual-mailbox-domains.cf"
    # activation of the configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo postconf -e virtual_mailbox_domains=mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf"
    # search of domain eas.lan


    # ====================================================================================================
    # Dovecot configuration - 10-auth.conf
    # ====================================================================================================
    # we do backup of docevot 10-auth.conf
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.bak"
    # we change seting in /etc/dovecot/conf.d/10-auth.conf to allow plain login
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/auth_mechanisms = plain/auth_mechanisms = plain login/g' /etc/dovecot/conf.d/10-auth.conf"
    # we comment line auth-system
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/!include auth-system.conf.ext//g' /etc/dovecot/conf.d/10-auth.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/!include auth-system.conf.ext/#!include auth-system.conf.ext/g' /etc/dovecot/conf.d/10-auth.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/#!include auth-sql.conf.ext/!include auth-sql.conf.ext/g' /etc/dovecot/conf.d/10-auth.conf"
    # we remove contents for clarifications and we remove empty lines
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i -e '/^#/d' /etc/dovecot/conf.d/10-auth.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i -e '/^$/d' /etc/dovecot/conf.d/10-auth.conf"
    # set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/dovecot/conf.d/10-auth.conf"

    # ====================================================================================================
    # Dovecot configuration - aut-sql.conf.ext
    # ====================================================================================================
    # we do backup of docevot 10-auth.conf
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/auth-sql.conf.ext.bak"
    # we copy the config file via scp and replace the original
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\dovecot\auth-sql.conf.ext -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/auth-sql.conf.ext /etc/dovecot/conf.d/auth-sql.conf.ext"
    # set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/dovecot/conf.d/auth-sql.conf.ext"

    # ====================================================================================================
    # Dovecot configuration - 10-mail.conf
    # ====================================================================================================
    # we do backup of docevot 10-mail.conf
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.bak"
    # we remplace the mail_location option in the configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's#mail_location = mbox:~/mail:INBOX=/var/mail/%u#mail_location = maildir:/var/mail-handler/%d/%n/Maildir#g' /etc/dovecot/conf.d/10-mail.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo echo 'mail_uid = 888' | sudo tee -a /etc/dovecot/conf.d/10-mail.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo echo 'mail_gid = 888' | sudo tee -a /etc/dovecot/conf.d/10-mail.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo echo 'first_valid_uid = 888' | sudo tee -a /etc/dovecot/conf.d/10-mail.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo echo 'last_valid_uid = 888' | sudo tee -a /etc/dovecot/conf.d/10-mail.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/dovecot/conf.d/10-mail.conf"
    # set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/dovecot/conf.d/10-mail.conf"

    # ====================================================================================================
    # Dovecot configuration - 10-master.conf
    # ====================================================================================================
    # we do backup of docevot 10-master.conf
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.bak"
    # we copy the config file via scp and replace the original
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\dovecot\10-master.conf -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/10-master.conf /etc/dovecot/conf.d/10-master.conf"
    # set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/dovecot/conf.d/10-master.conf"
    
    # ====================================================================================================
    # Dovecot configuration - dovecot-sql.conf.ext
    # ====================================================================================================
    # we do backup of docevot-sql.conf.ext
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/dovecot/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext.bak"
    # we copy the config file via scp and replace the original
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\dovecot\dovecot-sql.conf.ext -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's#{{MAIL_USER_PASS}}#$ROOT_PASSWORD#g' ~/dovecot-sql.conf.ext"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext"
    # set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/dovecot/dovecot-sql.conf.ext"

    # ====================================================================================================
    # Dovecot configuration - dovecot.conf
    # ====================================================================================================
    # we change rights on devecot.conf  (launched as user mail-handler)
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chgrp mail-handler /etc/dovecot/dovecot.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chmod g+r /etc/dovecot/dovecot.conf"
    
    # Finally we restart dovecot service
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service dovecot restart"

    # ====================================================================================================
    # Postfix Link with dovecot
    # ====================================================================================================
    # we do backup of /etc/postfix/master.cf
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.bak"
    # we copy the config file via scp and replace the original
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\postfix\master.cf -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix ~/master.cf"
    # we want to append the content of the file after /etc/postfix/master.cf.bak
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat ~/master.cf | sudo tee -a /etc/postfix/master.cf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "rm -rf ~/master.cf"
    # set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/postfix/master.cf"

    # we relaunc postfix service
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service postfix restart"
    # we apply the modifications
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo postconf -e virtual_transport=dovecot"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo postconf -e dovecot_destination_recipient_limit=1"


    # ====================================================================================================
    # RainLoop installation
    # ====================================================================================================
    # creation of dedicated folder
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mkdir /var/www/html/rainloop" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo wget -O /var/www/html/rainloop/installer.php https://repository.rainloop.net/installer.php" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo php /var/www/html/rainloop/installer.php" 
    # rainloop need some access rights
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo find /var/www/html/rainloop/ -type d -exec chmod 755 {} \;" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo find /var/www/html/rainloop/ -type f -exec chmod 644 {} \;" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown -R www-data:www-data /var/www/html/rainloop/" 
    # copy apache2 config for rainloop via scp  
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\apache2\rainloop.conf -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/rainloop.conf /etc/apache2/sites-available/rainloop.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/apache2/sites-available/rainloop.conf"
    # reset correct permission
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/apache2/sites-available/rainloop.conf"
    # activation of site via a2ensite
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo a2ensite rainloop.conf"
    # restart apache2
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service apache2 restart"




}