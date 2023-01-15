# Debian Architecture Deployer for VirtualBox

## What is it ?

It's a tool made during my personal networking formation, the goal of this is to copy basic VirutalBox Debian VMs and to automate the creation of different services on the network. The powershell script will generate:

- DHCP Server ( isc-dhcp-server )
- DNS Server ( bind9 )
- FTP Server ( ProFtpd )
- Mail Server ( postfix / postfixadmin / dovecot / rainloop )

## How to use it ?

***Warning***: This is a tool created quickly and which is not perfect, because it is related to a concrete simulation project.

### PreRequisites

- The script is a powershell script, so you need to have recent powershell installation.
- You must have preconfigured 2 Debian Machines in virtual Box with some configuration:

One server machine should be named **Debian_Server** in VirtualBox.
One client machine should be named **Debian_Client** in VirtualBox, and should have a desktop environnement installed (optional, but it makes sense).

```bash 
# creation of a user naamed "admin" with Password "Admin123" 
# the user should be in sudo group
sudo adduser admin --home /home/admin --ingroup sudo

# allow admin to run commands with sudo without password
echo 'admin     ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers
# it is better to use visudo to edit sudoers, but do as you want

# install sudo
sudo apt-get install sudo

# installation of basic tools (it is not necessary but it helps to debug)
sudo apt-get install curl tcpdump vim dos2unix 

# you must be able to connect to ssh, so be sure it is installed and ssh server is running
sudo apt-get install sshd
sudo service ssh restart
```

### Usage

1. Clone this repository
2. Eventually change some configuration variables in main script file `virtual_deploy.ps1`. But for the moment, no documentation is provided.
3. Run in powershell invite the script: `.\virtual_deploy.ps1`.

If everyting is ok, you should have no errors at the end of the process. If you encountered problems, check the specified commands...

***Warning***:
Eatch time you rerun the script, the virtual machines are deleted and regenerated. If you want to keep your virtual machines, rename theme after the execution of the script.