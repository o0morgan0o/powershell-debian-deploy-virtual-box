
function Configure-DHCPDNSServerDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId,
        [Parameter(Mandatory=$true)][String]$DHCP_IP_ADDRESS
    )

    # variables
    $DEFAULT_LEASE_TIME = 3600 * 24
    $MAX_LEASE_TIME = 3600 * 24 * 3
    $SUBNET = "192.168.58.0"
    $SUBNET_MASK = "255.255.255.0"
    $DHCP_RANGE_START = "192.168.58.50"
    $DHCP_RANGE_END = "192.168.58.220"
    $DHCP_OPTION_ROUTER = "192.168.58.1"
    $MAIL_IP_ADDRESS = "192.168.58.20"
    $MAIL_LAST_BYTE_IP_ADDRESS = "20"
    $CLIENT_01_IP_ADDRESS_RESERVED = "192.168.58.110"
    $EAS_DOMAIN = "eas.lan"
    $MACHINE_PORT = "2222"

    # create backups of config files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/network/interfaces /etc/network/interfaces.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ls -la /etc/network/"

    # set hostnames
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static eas-srv-dd" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --pretty eas-srv-dd" 

    # =================================================================================================================
    # set ip configuration
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
    # set enp0s8
    allow-hotplug enp0s8
    iface enp0s8 inet static
    address $DHCP_IP_ADDRESS
    network $SUBNET
    netmask $SUBNET_MASK
    dns-nameservers $DHCP_IP_ADDRESS 8.8.8.8
    dns-search $EAS_DOMAIN
    ' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/network/interfaces"
    # check command
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/network/interfaces" 
    # set etc/hosts
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
    127.0.0.1       localhost
    127.0.1.1       eas-srv-dd.eas.lan eas-srv-dd
    ' | sudo tee /etc/hosts"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/hosts"

    

    # restart network
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ifdown enp0s8;sudo ifup enp0s8"; 

    # =================================================================================================================
    # setup dhcp server
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get install isc-dhcp-server -y"; 
    # copy configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak" ; 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak" ; 
    # set isc-dhcp-server to listen on enp0s8
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'INTERFACESv4=`"enp0s8`"' | sudo tee /etc/default/isc-dhcp-server" ;
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/default/isc-dhcp-server" ;
    # set isc-dhcp-server configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
    option domain-name `"eas.lan`";
    option domain-name-servers 8.8.8.8;
    default-lease-time $DEFAULT_LEASE_TIME;
    max-lease-time $MAX_LEASE_TIME;
    ddns-update-style none;
    authoritative;

    # subnet config
    subnet $SUBNET netmask $SUBNET_MASK {
        range $DHCP_RANGE_START $DHCP_RANGE_END;
        option routers $DHCP_OPTION_ROUTER;
        option domain-name-servers $DHCP_IP_ADDRESS;
        option domain-name `"$EAS_DOMAIN`";

        # Reservation DHCP for client-01
        host post-matthieu {
            hardware ethernet $NIC_MAC_ADDRESS_CLIENT_01_SPLITED;
            fixed-address $CLIENT_01_IP_ADDRESS_RESERVED;
        }
    }
    ' | sudo tee /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/dhcp/dhcpd.conf" 
    # restart dhcp server
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service isc-dhcp-server restart" 

    # =================================================================================================================
    # setup DNS Server
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt install bind9 -y" 
    # copy configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/bind/named.conf.default-zones /etc/bind/named.conf.default-zones.bak"
    # set named.conf.options
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
options {
    directory `"/var/cache/bind`";
    forwarders {
        $DHCP_IP_ADDRESS;
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
    auth-nxdomain no;    # conform to RFC1035
    version none;
    forward only;
};
' | sudo tee  /etc/bind/named.conf.options"
    # check configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo named-checkconf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service bind9 restart"
    # set named.conf.local
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
zone `"eas.lan`" {
    type master;
    file `"/etc/bind/db.eas.lan`";
    allow-query { any; };
};

zone `"192.168.58.in-addr.arpa`" {
    type master;
    file `"/etc/bind/db.192`";
    allow-query { any; };
};
' | sudo tee -a /etc/bind/named.conf.local"


    # =================================================================================================================
    # Copy of DNS Zones
    # Zone eas.lan
    # =================================================================================================================
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\dnszones\db.eas.lan -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix ~/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/{{DHCP_IP_ADDRESS}}/$DHCP_IP_ADDRESS/g' ~/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/{{MAIL_IP_ADDRESS}}/$MAIL_IP_ADDRESS/g' ~/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/{{MAIL_LAST_BYTE_IP_ADDRESS}}/$MAIL_LAST_BYTE_IP_ADDRESS/g' ~/db.eas.lan"
    # move and set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/db.eas.lan /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/bind/db.eas.lan"

    # =================================================================================================================
    # Copy of DNS Zones
    # Zone 192.168.58.in-addr.arpa
    # =================================================================================================================
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MACHINE_PORT -Path .\confs\dnszones\db.192 -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix ~/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo sed -i 's/{{MAIL_LAST_BYTE_IP_ADDRESS}}/$MAIL_LAST_BYTE_IP_ADDRESS/g' ~/db.192"
    # move and set permissions
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv -f ~/db.192 /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/bind/db.192"

    # check configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo named-checkconf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service bind9 restart"

    Set-Resolv -DNS_IP_ADDRESS $DHCP_IP_ADDRESS


    # =================================================================================================================
    # setup Security (Firewall)
    # =================================================================================================================
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt install ufw -y" 
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ufw allow 22/tcp" 
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ufw allow bind9" 
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ufw allow 20/tcp" 
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ufw allow 21/tcp" 
}