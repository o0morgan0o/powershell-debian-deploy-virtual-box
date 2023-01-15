
function Configure-ClientDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId
    )

    # $FILE_SERVER_IP_ADDRESS = "192.168.58.20"
    # $SUBNET = "192.168.58.0"
    # $SUBNET_MASK = "255.255.255.0"
    # $MACHINE_PORT = 2223

    # create backups of config files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/network/interfaces /etc/network/interfaces.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ls -la /etc/network/"

    # set hostnames
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static eas-client-01" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --pretty eas-client-01" 

    # =================================================================================================================
    # set ip configuration
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
# set enp0s8
allow-hotplug enp0s8
iface enp0s8 inet dhcp
' | sudo tee -a /etc/network/interfaces" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/network/interfaces"
    # check command
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cat /etc/network/interfaces" 
    # restart network
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ifdown enp0s8;sudo ifup enp0s8" 
}