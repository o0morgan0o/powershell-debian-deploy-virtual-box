# Author: Morgan Thibert
# Date: 2023-01
# Description: This script will deploy and configure a set of virtual machines in VirtualBox
# Notes:
# note for myself: to output "" in command we escape with \`:
# -Command "echo test-`"($var)`"
# -Command "echo test-$var"
# -------------------------------------------------------------------------------------------------------------------------

# Counter for keeping track of operations
$global:operationErrorCounter = 0;
$global:operationSuccessCounter = 0;
$global:operationErrorCommands = @();


# =========================================================================================================================
# Source util functions
# =========================================================================================================================
$VBoxManageExe = """C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"""
. .\utils\Set-Resolv.ps1
. .\utils\DisplayHelper.ps1
. .\utils\VM_Operations.ps1
. .\utils\InvokeCommands.ps1
. .\utils\Configure-DHCPDNS.ps1
. .\utils\Configure-FTPMAIL.ps1

# =========================================================================================================================
# set variables
# =========================================================================================================================
$AdminUser = "admin"
$VM_SOURCE_SERVER="Debian_Server"
$VM_SOURCE_CLIENT="Debian_Client"
$VM_SRV_DD="eap-srv-dd"
$VM_SRV_FILES="eap-srv-fmail"
$VM_CLIENT_01="eap-client-01"
$VM_CLIENT_02="eap-client-02"
$NIC_MAC_ADDRESS_CLIENT_01="aa22bb33cc44"
$NIC_MAC_ADDRESS_CLIENT_01_SPLITED="aa:22:bb:33:cc:44"
$DHCP_IP_ADDRESS="192.168.58.10"
$DNS_IP_ADDRESS="192.168.58.10"
# Credential for admin user will be used in several places
$AdminUserPassword = "Admin123"
# Port for nat translations
$SSH_PORT_TRANSLATION_DD=2222
$SSH_PORT_TRANSLATION_FMAIL=2223
$NAT_PORT_TRANSLATION_DD_HTTP=8022
$NAT_PORT_TRANSLATION_FMAIL_HTTP=8023

# =========================================================================================================================
# Creation of credentials for login via ssh
# =========================================================================================================================
$SecurePassword = ConvertTo-SecureString $AdminUserPassword -AsPlainText -Force
$Creds = [System.Management.Automation.PSCredential]::new($AdminUser, $SecurePassword)

# ========================================
# Get-AllVMs 
# Get-VMByName -VMName $VM_SRV_DD
# Get-VMByName -VMName $VM_SRV_FILES

# ========================================
# Stop all vms before starting
Stop-VM -VMName $VM_SRV_DD
Stop-VM -VMName $VM_SRV_FILES
Stop-VM -VMName $VM_CLIENT_01
Stop-VM -VMName $VM_CLIENT_02

# ========================================
Write-Output "Waiting for the VMs to stop"
Start-Sleep -s 5

# ========================================
# Delete all vms before starting
Delete-VM -VMName $VM_SRV_DD
Delete-VM -VMName $VM_SRV_FILES
Delete-VM -VMName $VM_CLIENT_01
Delete-VM -VMName $VM_CLIENT_02

# ========================================
# Creation of all the Server VMs and client VMs
New-CloneVM -VMSource $VM_SOURCE_SERVER -VMName $VM_SRV_DD -SSHRemotePort $SSH_PORT_TRANSLATION_DD -HTTPRemotePort $NAT_PORT_TRANSLATION_DD_HTTP -WithNAT $true -WithHostOnly $true
New-CloneVM -VMSource $VM_SOURCE_SERVER -VMName $VM_SRV_FILES -SSHRemotePort $SSH_PORT_TRANSLATION_FMAIL -HTTPRemotePort $NAT_PORT_TRANSLATION_FMAIL_HTTP -WithNAT $true -WithHostOnly $true
# New-CloneVM -VMSource $VM_SOURCE_CLIENT -VMName $VM_CLIENT_01 -SSHRemotePort 2230 -HTTPRemotePort 8030 -WithNAT $true -WithHostOnly $true
# New-CloneVM -VMSource $VM_SOURCE_CLIENT -VMName $VM_CLIENT_02 -SSHRemotePort 2231 -HTTPRemotePort 8031 -WithNAT $true -WithHostOnly $true

# ========================================
# We modify the client-01 VM because it will use reserved addresses on DHCP so we specify a mac address on enp0s8
Set-NicMacAddress -MACAddress $NIC_MAC_ADDRESS_CLIENT_01 -VMName $VM_CLIENT_01

# ========================================
# Start the VMs
Start-VM -VMName $VM_SRV_DD
Start-VM -VMName $VM_SRV_FILES
# Start-VM -VMName $VM_CLIENT_01
# Start-VM -VMName $VM_CLIENT_02

# ========================================
Write-Output "Waiting for the VMs to start"
Start-Sleep -s 10

# ========================================
# Copy shell_scripts to the VMs
# DHCP and DNS Machine (Port 2222 -> shell_script__dd.sh)
# Set-SCPItem -Credential $AdminUser  -ComputerName 127.0.0.1 -Port 2222 -Path .\shell_scripts\shell_script_dd.sh -Destination /home/$AdminUser/ -Verbose -AcceptKey
# Set-SCPItem -Credential $AdminUser  -ComputerName 127.0.0.1 -Port 2223 -Path .\shell_scripts\shell_script_files.sh -Destination /home/$AdminUser/ -Verbose -AcceptKey

# ========================================
# TODO : Refactorisation of try catch for every functions, maybe a function that will do the try catch
# Execute configurations on the vms


# ((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((
# DNS and DHCP Machine (Port 2222 -> shell_script__dd.sh)
$port = $SSH_PORT_TRANSLATION_DD
$retries = 4
while ($retries -gt 0) {
    try {
        Get-SSHTrustedHost | Remove-SSHTrustedHost
        Write-Host "Trying to connect to the VM on port $port... $retries" -BackgroundColor Red -ForegroundColor White
        $session = New-SSHSession -ComputerName 127.0.0.1 -Port $port -Credential $Creds -AcceptKey -ConnectionTimeout 30
        $retries = -1
        Configure-DHCPDNSServerDebian -SshSessionId $session.SessionId -DHCP_IP_ADDRESS $DHCP_IP_ADDRESS 
        Remove-SSHSession -SessionId $session.SessionId
    }catch{
        Write-Warning $Error[0]
        Write-Host "Can't connect !" -BackgroundColor Red -ForegroundColor White
        $retries--
        Start-Sleep -s 2
    }
}
# END MACHINE CONFIGURATION *************************************************************************
# )))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))


# ((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((
#  Files Machine (Port 2223 -> shell_script__files.sh)
$port = $SSH_PORT_TRANSLATION_FMAIL
$retries = 4
while ($retries -gt 0) {
    try {
        Get-SSHTrustedHost | Remove-SSHTrustedHost
        Write-Host "Trying to connect to the VM on port $port... $retries" -BackgroundColor Red -ForegroundColor White
        $session = New-SSHSession -ComputerName 127.0.0.1 -Port $port -Credential $Creds -AcceptKey -ConnectionTimeout 30
        if ($session -eq $null) {
            throw "Can't connect to the VM on port $port"
        }else {
            $retries = -1
            Configure-FileServerDebian -SshSessionId $session.SessionId -DNS_IP_ADDRESS $DNS_IP_ADDRESS
            Remove-SSHSession -SessionId $session.SessionId
        }

    }catch{
        Write-Warning $Error[0]
        Write-Host "Can't connect !" -BackgroundColor Red -ForegroundColor White
        $retries--
        Start-Sleep -s 2
    }
}
# END MACHINE CONFIGURATION *************************************************************************
# )))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))


# ((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((
#  Files Machine (Port 2223 -> shell_script__files.sh)
# $port = 2230
# $retries = 4 
# while($retries -gt 0){
#     try{
#         Get-SSHTrustedHost | Remove-SSHTrustedHost
#         Write-Host "Trying to connect to the VM on port $port... $retries" -BackgroundColor Red -ForegroundColor White
#         $session = New-SSHSession -ComputerName 127.0.0.1 -Port $port -Credential $Creds -AcceptKey
#         Configure-ClientDebian -SshSessionId $session.SessionId
#         Remove-SSHSession -SessionId $session.SessionId
#         $retries = -1
#     }catch{
            # Write-Warning $Error[0]
#         Write-Host "Can't connect !" -BackgroundColor Red -ForegroundColor White
#         $retries--
#         Start-Sleep -s 2
#     }
# }
# END MACHINE CONFIGURATION *************************************************************************
# )))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))



# ========================================
# Finished / we show a recap
# ========================================
$operationCounter = $operationErrorCounter + $operationSuccessCounter
Show-Yellow -Message "======================================"
Show-Yellow -Message "Finished !"
Show-Yellow -Message "======================================"
Show-White -Message "Results: "
Show-White -Message "Number of operations: $operationCounter "
Show-Red -Message "[+] ERRORS: $operationErrorCounter / $operationCounter operations"
Show-Green -Message "[+] SUCCESS: $operationSuccessCounter / $operationCounter operations"
Show-White -Message "======================================"
Show-Yellow -Message "Theses commandes made errors:"
foreach ($command in $operationErrorCommands) {
    Show-Red -Message "[+] ERROR: $command"
}

Show-Yellow -Message "======================================"
Show-Yellow -Message "Deployment finished !"
Show-Yellow -Message "======================================"
Show-Yellow -Message "You can setup your postfix administrator by going to:"
Show-Green -Message "http://eas-srv-fmail.eas.lan/postfixadmin/setup.php"
Show-Yellow -Message "or via nat translation on port $PORT_NAT_POSTFIXADMIN"
Show-Green -Message "http://localhost:$NAT_PORT_TRANSLATION_FMAIL_HTTP/postfixadmin/setup.php"
Show-Yellow -Message "======================================"
Show-Yellow -Message "Login via:"
Show-Green -Message "http://eas-srv-fmail.eas.lan/postfixadmin/login.php"
Show-Green -Message "http://localhost:$NAT_PORT_TRANSLATION_FMAIL_HTTP/postfixadmin/login.php"
Show-Yellow -Message "======================================"
Show-Yellow -Message "Rainloop admin panel:"
Show-Green -Message "http://eas-srv-fmail.eas.lan/rainloop/?admin"
Show-Green -Message "http://localhost:$NAT_PORT_TRANSLATION_FMAIL_HTTP/rainloop/?admin"
Show-Yellow -Message "Admin default credentials:"
Show-Red -Message "login: admin"
Show-Red -Message "password: 12345"
Show-Yellow -Message "======================================"
Show-Yellow -Message "Rainloop login for clientss:"
Show-Yellow -Message "======================================"
Show-Green -Message "http://eas-srv-fmail.eas.lan/rainloop"
Show-Green -Message "http://localhost:$NAT_PORT_TRANSLATION_FMAIL_HTTP/rainloop"
Show-Yellow -Message "======================================"


Show-Yellow -Message "Bye !"
Show-Yellow -Message " "

