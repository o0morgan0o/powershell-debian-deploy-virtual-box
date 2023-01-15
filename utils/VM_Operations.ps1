
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
    $vbox = New-Object -ComObject "VirtualBox.virtualBox"
    return $vbox.Machines | Select-Object -Property Name, Id, Session-State
}

function Get-VMByName {
    Param(
        [Parameter(Mandatory=$true)][String]$VMName
    )
    $vbox = New-Object -ComObject "VirtualBox.virtualBox"
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
        [Parameter(Mandatory=$true)][String]$HTTPRemotePort,
        [Parameter(Mandatory=$true)][Boolean]$WithNAT,
        [Parameter(Mandatory=$true)][Boolean]$WithHostOnly
    )
    "$VBoxManageExe clonevm $VMSource --name $VMName --register" | cmd
    if( $WithNAT -eq $true){
        # we activate nat network interface on first nic
        "$VBoxManageExe modifyvm $VMName --nic1 nat" | cmd
        "$VBoxManageExe modifyvm $VMName --natpf1 ""guestssh,tcp,,$SSHRemotePort,,22""" | cmd
        "$VBoxManageExe modifyvm $VMName --natpf1 ""guesthttp,tcp,,$HTTPRemotePort,,80""" | cmd
    }
    if ($WithHostOnly -eq $true) {
        # we activate host only network interface on second nic
        "$VBoxManageExe modifyvm $VMName --nic2 hostonly" | cmd
        "$VBoxManageExe modifyvm $VMName --hostonlyadapter2 ""VirtualBox Host-Only Ethernet Adapter #2""" | cmd
    }
}

function Get-SRVDDVM {
    $vbox = New-Object -ComObject "VirtualBox.virtualBox"
    $machine = $vbox.FindMachine(($vbox.Machines | where {$_.Name -match $VM_SRV_DD }).id)
    return $machine
}

function Set-NicMacAddress{
    Param (
        [Parameter(Mandatory=$true)][String]$VMName,
        [Parameter(Mandatory=$true)][String]$MacAddress
    )
    "$VBoxManageExe modifyvm $VMName --macaddress2 $MacAddress" | cmd
}