
function Configure-ClientDebian {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId,
        [Parameter(Mandatory=$true)][String]$ClientHostname,
        [Parameter(Mandatory=$true)][Int]$MachineSSHPortTranslation,
        [Parameter(Mandatory=$true)][String]$UserToCreate,
        [Parameter(Mandatory=$true)][String]$PasswordForUserToCreate
    )

    # $FILE_SERVER_IP_ADDRESS = "192.168.58.20"
    # $SUBNET = "192.168.58.0"
    # $SUBNET_MASK = "255.255.255.0"

    # create backups of config files
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo cp /etc/network/interfaces /etc/network/interfaces.bak"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo ls -la /etc/network/"

    # set hostnames
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static $ClientHostname" 
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo hostnamectl set-hostname --static $ClientHostname" 

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

    # =================================================================================================================
    # Creation of user 
    # =================================================================================================================
    # creation of user with home
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo useradd -m $UserToCreate -s /bin/bash"
    # command to change password with the password provided
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '${UserToCreate}:$PasswordForUserToCreate' | sudo chpasswd"


    # =================================================================================================================
    # copy script in /etc/xdg/autostart for starting firefox at login
    # =================================================================================================================
    # we copy the firefox-autostart.sh.desktop gnome autostart file
    Set-SCPItem -Credential $creds  -ComputerName 127.0.0.1 -Port $MachineSSHPortTranslation -Path .\confs\clients\scripts\firefox-autostart.sh.desktop -Destination ~ -Verbose -AcceptKey
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix ~/firefox-autostart.sh.desktop"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo mv ~/firefox-autostart.sh.desktop /etc/xdg/autostart/firefox-autostart.sh.desktop"
    # we move it in the autostart folder
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown root:root /etc/xdg/autostart/firefox-autostart.sh.desktop"
    # we also set a script on the client to open the firefox windows for admin
    # TODO Find a better way to open firefox at launch
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '#!/bin/bash' | sudo tee /home/$UserToCreate/firefox-launcher.sh"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo 'firefox http://smtp.eas.lan/postfixadmin/setup.php http://smtp.eas.lan/rainloop' | sudo tee -a /home/$UserToCreate/firefox-launcher.sh"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chown ${UserToCreate}:${UserToCreate} /home/$UserToCreate/firefox-launcher.sh"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chmod +x /home/$UserToCreate/firefox-launcher.sh"

}