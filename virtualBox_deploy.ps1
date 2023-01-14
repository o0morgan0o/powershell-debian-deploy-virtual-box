# go in vboxmanage location
# Set-Location "C:\Program Files\Oracle\VirtualBox"

$VBoxManageExe = """C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"""
$AdminUser = "admin"
$VM_SOURCE="Debian_Server"
$VM_SRV_DD="eap-srv-dd"
$VM_SRV_FILES="eap-srv-files"


# note help: to output "" in command we escape with \`:
# -Command "echo test-`"($var)`"
# -Command "echo test-$var"

function Delete-VM {
    Param(
        [Parameter(Mandatory=$true)][String]$VMName
    )

    if (Get-VMByName -VMName $VMName) {
        "$VBoxManageExe unregistervm $VMName --delete" | cmd
    }
}

function Stop-VM {
    Param(
        [Parameter(Mandatory=$true)][String]$VMName
    )
    try{
        "$VBoxManageExe controlvm $VMName poweroff" | cmd
    }catch{
        Write-Output "Could not stop VM with name $VMName"
    }
}

function Start-VM {
    Param(
        [Parameter(Mandatory=$true)][String]$VMName
    )
    try{
        "$VBoxManageExe startvm $VMName" | cmd
    }catch{
        Write-Output "Could not start VM with name $VMName"
    }
}

function Get-AllVMs {
    return $vbox.Machines | Select-Object -Property Name, Id, Session-State
}

function Get-VMByName {
    Param(
        [Parameter(Mandatory=$true)][String]$VMName
    )
    $foundMachine = $null
    try {
        $foundMachine = $vbox.FindMachine(($vbox.Machines | where {$_.Name -match $VMName }).id) 
    }
    catch {
        Write-Output "Could not find VM with name $VMName"
    }
    return $foundMachine
}

function New-CloneVM {
    Param(
        [Parameter(Mandatory=$true)][String]$VMSource,
        [Parameter(Mandatory=$true)][String]$VMName,
        [Parameter(Mandatory=$true)][String]$SSHRemotePort,
        [Parameter(Mandatory=$true)][Boolean]$WithNAT,
        [Parameter(Mandatory=$true)][Boolean]$WithHostOnly
    )
    "$VBoxManageExe clonevm $VMSource --name $VMName --register" | cmd
    if( $WithNAT -eq $true){
        # we activate nat network interface on first nic
        "$VBoxManageExe modifyvm $VMName --nic1 nat" | cmd
        "$VBoxManageExe modifyvm $VMName --natpf1 ""guestssh,tcp,,$SSHRemotePort,,22""" | cmd
    }
    if ($WithHostOnly -eq $true) {
        # we activate host only network interface on second nic
        "$VBoxManageExe modifyvm $VMName --nic2 hostonly" | cmd
        "$VBoxManageExe modifyvm $VMName --hostonlyadapter2 ""VirtualBox Host-Only Ethernet Adapter #2""" | cmd
    }
    # "$VBoxManageExe modifyvm $VM_NAME -guestssh,tcp,,$SSHRemotePort,22" | cmd
}

function Get-SRVDDVM {
    $machine = $vbox.FindMachine(($vbox.Machines | where {$_.Name -match $VM_SRV_DD }).id)
    return $machine
}

function Invoke-BashFunction {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId,
        [Parameter(Mandatory=$true)][String]$CommandToExecute,
        [Parameter()][Int16]$Timeout = 10
    )
    $CommandAsString = $CommandToExecute
    Write-Host "COMMAND: $CommandAsString" -ForegroundColor Red -BackgroundColor Yellow
    $result = Invoke-SSHCommand -SessionId $SshSessionId -Command $CommandToExecute -TimeOut $Timeout
    $resultOutput = $result.Output
    $resultStatus = $result.ExitStatus
    Write-Output $resultOutput
    Write-Host "OUTPUT ($resultStatus):" -ForegroundColor Red
    Write-Host ""
}

function Configure-DHCPDNSServerDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId
    )

    # variables
    $DEFAULT_LEASE_TIME = 3600 * 24
    $MAX_LEASE_TIME = 3600 * 24 * 3
    $SUBNET = "192.168.58.0"
    $SUBNET_MASK = "255.255.255.0"
    $DHCP_RANGE_START = "192.168.58.50"
    $DHCP_RANGE_END = "192.168.58.220"
    $DHCP_IP_ADDRESS = "192.168.58.10"
    $DHCP_OPTION_ROUTER = "192.168.58.1"
    $MAIL_IP_ADDRESS = "192.168.58.20"
    $MAIL_LAST_BYTE_IP_ADDRESS = "20"
    $EAS_DOMAIN = "eas.lan"

    # create backups of config files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/network/interfaces /etc/network/interfaces.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ls -la /etc/network/"

    # set hostnames
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static eas-srv-dd.eas.lan" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --pretty eas-srv-dd" 

    # =================================================================================================================
    # set ip configuration
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '# set enp0s8' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'allow-hotplug enp0s8' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'iface enp0s8 inet static' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'address $DHCP_IP_ADDRESS' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'network $SUBNET' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'netmask $SUBNET_MASK' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'dns-nameservers 8.8.8.8 127.0.0.1' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'dns-search $EAS_DOMAIN' | sudo tee -a /etc/network/interfaces" 
    # check command
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/network/interfaces" 

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
    # set isc-dhcp-server configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '' | sudo tee /etc/dhcp/dhcpd.conf" # clear file
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'option domain-name `"eas.lan`";' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'option domain-name-servers 8.8.8.8;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'default-lease-time $DEFAULT_LEASE_TIME;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'max-lease-time $MAX_LEASE_TIME;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'ddns-update-style none;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'authoritative;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    # Set subnet config
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'subnet $SUBNET netmask $SUBNET_MASK {' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   range $DHCP_RANGE_START $DHCP_RANGE_END;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   option routers $DHCP_OPTION_ROUTER;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   option domain-name-servers $DHCP_IP_ADDRESS;' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   option domain-name `"$EAS_DOMAIN`";' | sudo tee -a /etc/dhcp/dhcpd.conf" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '}' | sudo tee -a /etc/dhcp/dhcpd.conf" 
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
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '' | sudo tee /etc/bind/named.conf.options" # clear file
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'options {' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   directory `"/var/cache/bind`";' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   forwarders {' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       $DHCP_IP_ADDRESS;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       8.8.8.8;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       8.8.4.4;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       };' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   dnssec-validation auto;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   auth-nxdomain no;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   version none;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   forward only;' | sudo tee -a /etc/bind/named.conf.options"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '};' | sudo tee -a /etc/bind/named.conf.options"
    # check configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo named-checkconf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service bind9 restart"
    # set named.conf.local
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'zone `"eas.lan`" {' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   type master;' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   file `"/etc/bind/db.eas.lan`";' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   allow-query { any; };' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '};' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'zone `"58.168.192.in-addr.arpa`" {' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   type master;' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '   file `"/etc/bind/db.192`";' | sudo tee -a /etc/bind/named.conf.local"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '};' | sudo tee -a /etc/bind/named.conf.local"
    # set /etc/bind/db.eas.lan
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo touch /etc/bind/db.eas.lan"
    # SOA
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '`$TTL 604800' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@  IN  SOA eas-srv-dd.eas.lan. root.eas.lan. (' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       3           ; Serial' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       604800      ; Refresh' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       86400       ; Retry' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       2419200     ; Expire' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       604800 )    ; Negative Cache TTTl' | sudo tee -a /etc/bind/db.eas.lan"
    # @ Entries
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@      IN  NS  eas-srv-dd.eas.lan.' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@      IN  A  $DHCP_IP_ADDRESS' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@      IN  MX  $MAIL_LAST_BYTE_IP_ADDRESS  smtp' | sudo tee -a /etc/bind/db.eas.lan"
    # A Entries
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'eas-srv-dd         IN  A  $DHCP_IP_ADDRESS' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'eas-srv-files      IN  A  $MAIL_IP_ADDRESS' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'eas-srv-mail       IN  A  $MAIL_IP_ADDRESS' | sudo tee -a /etc/bind/db.eas.lan"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'eas-srv-fmail      IN  A  $MAIL_IP_ADDRESS' | sudo tee -a /etc/bind/db.eas.lan"
    # set /etc/bind/db.192
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo touch /etc/bind/db.192"
    # SOA
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'eas-srv-dd         IN  A  $DHCP_IP_ADDRESS' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '`$TTL 604800' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@  IN  SOA eas-srv-dd.eas.lan. root.eas.lan. (' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       3           ; Serial' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       604800      ; Refresh' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       86400       ; Retry' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       2419200     ; Expire' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '       604800 )    ; Negative Cache TTTl' | sudo tee -a /etc/bind/db.192"
    # @ Entries
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@      IN  NS  eas.lan.' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@      IN  MX  $MAIL_LAST_BYTE_IP_ADDRESS  smtp' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '@      IN  MX  $MAIL_LAST_BYTE_IP_ADDRESS  smtp' | sudo tee -a /etc/bind/db.192"
    # Pointer Entries
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '1      IN      PTR     eas.lan' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '10     IN      PTR     eas-srv-dd.eas.lan' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '10     IN      PTR     eas-srv-dd.eas.lan.' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '$MAIL_LAST_BYTE_IP_ADDRESS     IN      PTR     smtp.eas-srv-mail.eas.lan.' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '$MAIL_LAST_BYTE_IP_ADDRESS     IN      PTR     eas-srv-mail.eas.lan.' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '$MAIL_LAST_BYTE_IP_ADDRESS     IN      PTR     eas-srv-files.eas.lan.' | sudo tee -a /etc/bind/db.192"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '$MAIL_LAST_BYTE_IP_ADDRESS     IN      PTR     fmail.eas.lan.' | sudo tee -a /etc/bind/db.192"
    # check configuration
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo named-checkconf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo service bind9 restart"


    # =================================================================================================================
    # setup /etc/resolv.conf
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '' | sudo tee /etc/resolv.conf"

    # =================================================================================================================
    # setup Security (Firewall)
    # =================================================================================================================
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt install ufw -y" 
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ufw allow bind9" 

    

    
}

function Configure-FileServerDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId
    )

    $FILE_SERVER_IP_ADDRESS = "192.168.58.20"
    $SUBNET = "192.168.58.0"
    $SUBNET_MASK = "255.255.255.0"

    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get update" 
    # Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo apt-get upgrade -y" 
    # create backups of config files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/network/interfaces /etc/network/interfaces.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ls -la /etc/network/"

    # =================================================================================================================
    # set hostnames
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static eas-srv-fmail.eas.lan" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --pretty eas-srv-fmail" 

    # =================================================================================================================
    # set ip configuration
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '# set enp0s8' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'allow-hotplug enp0s8' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'iface enp0s8 inet dhcp' | sudo tee -a /etc/network/interfaces" 
    # check command
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/network/interfaces" 
    # restart network
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ifdown enp0s8;sudo ifup enp0s8"; 

}

# ========================================
# Get-AllVMs 
$vbox = New-Object -ComObject "VirtualBox.virtualBox"
# Get-VMByName -VMName $VM_SRV_DD
# Get-VMByName -VMName $VM_SRV_FILES

# ========================================
# Stop all vms before starting
Stop-VM -VMName $VM_SRV_DD
Stop-VM -VMName $VM_SRV_FILES

# ========================================
Write-Output "Waiting for the VMs to stop"
Start-Sleep -s 5

# ========================================
# Delete all vms before starting
Delete-VM -VMName $VM_SRV_DD
Delete-VM -VMName $VM_SRV_FILES

# ========================================
# Creation of all the VMs
New-CloneVM -VMSource $VM_SOURCE -VMName $VM_SRV_DD -SSHRemotePort 2222 -WithNAT $true -WithHostOnly $true
New-CloneVM -VMSource $VM_SOURCE -VMName $VM_SRV_FILES -SSHRemotePort 2223 -WithNAT $true -WithHostOnly $true

# ========================================
# Start the VMs
Start-VM -VMName $VM_SRV_DD
Start-VM -VMName $VM_SRV_FILES

# ========================================
Write-Output "Waiting for the VMs to start"
Start-Sleep -s 10

# ========================================
# Copy shell_scripts to the VMs
# DHCP and DNS Machine (Port 2222 -> shell_script__dd.sh)
# Set-SCPItem -Credential $AdminUser  -ComputerName 127.0.0.1 -Port 2222 -Path .\shell_scripts\shell_script_dd.sh -Destination /home/$AdminUser/ -Verbose -AcceptKey
# Set-SCPItem -Credential $AdminUser  -ComputerName 127.0.0.1 -Port 2223 -Path .\shell_scripts\shell_script_files.sh -Destination /home/$AdminUser/ -Verbose -AcceptKey


# ========================================
# Execute shell_scripts on the VMs

$AdminUserPassword = "Admin123"
$SecurePassword = ConvertTo-SecureString $AdminUserPassword -AsPlainText -Force
$Creds = [System.Management.Automation.PSCredential]::new($AdminUser, $SecurePassword)

# DHCP DNS Machine (Port 2222 -> shell_script__dd.sh)
$port = 2222
$retries = 4
while ($retries -gt 0) {
    try {
        Write-Host "Trying to connect to the VM on port $port... $retries" -BackgroundColor Red -ForegroundColor White
        $session = New-SSHSession -ComputerName 127.0.0.1 -Port $port -Credential $Creds -AcceptKey
        $retries = -1
        Configure-DHCPDNSServerDebian -SshSessionId $session.SessionId
        Remove-SSHSession -SessionId $session.SessionId
    }catch{
        Write-Host "Can't connect !" -BackgroundColor Red -ForegroundColor White
        $retries--
        Start-Sleep -s 2
    }
}

#  Files Machine (Port 2223 -> shell_script__files.sh)
$port = 2223
$retries = 4
while ($retries -gt 0) {
    try {
        Write-Host "Trying to connect to the VM on port $port... $retries" -BackgroundColor Red -ForegroundColor White
        $session = New-SSHSession -ComputerName 127.0.0.1 -Port $port -Credential $Creds -AcceptKey
        $retries = -1
        Configure-FileServerDebian -SshSessionId $session.SessionId
        Remove-SSHSession -SessionId $session.SessionId
    }catch{
        Write-Host "Can't connect !" -BackgroundColor Red -ForegroundColor White
        $retries--
        Start-Sleep -s 2
    }
}


# $session = New-SSHSession -ComputerName 127.0.0.1 -Port 2222 -Credential $Creds -AcceptKey
# Configure-DHCP_DNS_Configuration -SshSessionId $session.SessionId
# Remove-SSHSession -SessionId $session.SessionId

# Files Machine (Port 2223 -> shell_script__files.sh)
# $session = New-SSHSession -ComputerName 127.0.0.1 -Port 2222 -Credential $Creds -AcceptKey
# Configure-Files -SshSessionId $session.SessionId
# Remove-SSHSession -SessionId $session.SessionId



