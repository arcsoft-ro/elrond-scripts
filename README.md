# elrond-scripts
PowerShell scripts for managing the Elrond node/s

The set of this scripts will support you in deploying, removing, upgrading, as well as in many other management activities related to your Elrond node/s

## Prerequisites
1. Ubuntu/Debian OS
2. A standard user on the system with sudo access
3. Powershell

## Installing

1. Clone or download the files in this repo
2. Install powershell if you don't have it already. Check this page for the correct package for your OS Distribution / version:<br>
https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7<br><br>
### Example for Ubuntu 18.04
```
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update
sudo apt install -y powershell
```

## Configuration
After cloning the repository, prepare your configuration file:
1. Rename the user-config.json.sample to user-config.json
2. Edit the values in the config file to match your preferences

## Running the scripts

Option1: Run the scripts directly
```
/scripts-path/deploy-node.ps1 
```

Option2: Switch to PowerShell first (this enables double-tab arguments listing)
```
pwsh
/scripts-path/deploy-node.ps1 
```
