function Set-Resolv {
    Param(
        [Parameter(Mandatory=$true)] [string]$DNS_IP_ADDRESS
    )
    # =================================================================================================================
    # setup /etc/resolv.conf
    # =================================================================================================================
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "echo '
domain eas.lan
search eas.lan
nameserver $DNS_IP_ADDRESS
' | sudo tee /etc/resolv.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo dos2unix /etc/resolv.conf"
    Invoke-BashFunction -SshSessionId $SshSessionId -CommandToExecute "sudo chattr +i /etc/resolv.conf"
}