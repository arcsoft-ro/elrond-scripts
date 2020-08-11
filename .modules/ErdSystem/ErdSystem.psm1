#Requires -Modules ErdCore

#
# ErdNode System Module
#

function Test-OsDistribution{

	if(([System.IntPtr]::Size * 8) -lt 64){
		return $false
	}

	$release = ((Get-Content /etc/*-release | Select-String ^\s*ID=) -split "=")[-1]

	if($release -notmatch "ubuntu|debian|linuxmint|elementary"){
		return $false
	}

	return $true
}

function Update-System{
	
	Write-Subsection "Upgrading Operating System"
	
	Invoke-Command -ScriptBlock {
		sudo apt clean -q
		sudo apt update -qqq
		sudo apt upgrade -y
	}
}

function Install-Dependencies{
	
	Write-Subsection "Installing dependencies"
	
	Invoke-Command -ScriptBlock {
		sudo apt install -y git rsync curl zip unzip jq gcc wget g++
	}
}

function Set-JournalctlConfig{

	Param(
		[string]$TmpDir = "/tmp"
	)

	Write-DoingAction "Configuring journalctl"

	$configPath = "/etc/systemd/journald.conf"
	$tempConfigPath = "/$TmpDir/" + (Get-RandomString)
	$content = Get-Content -Path $configPath
	
	if(!$content){
		Write-Warning -Message "Could not read journalctl configuration from $configPath"

		return
	}

	$content = Set-SystemdConfigValue -Content $content -PropertyName "SystemMaxUse" -Value "2000M"
	$content = Set-SystemdConfigValue -Content $content -PropertyName "SystemMaxFileSize" -Value "400M"

	Set-Content -Path $tempConfigPath -Value $content

	try{
		Invoke-Command -ScriptBlock{
			sudo mv -f $tempConfigPath $configPath
			sudo systemctl restart systemd-journald
		}
		Write-OkResult
	}
	catch{
		Write-WarningResult
	}

}

function Get-Architecture{
	return Invoke-Command -ScriptBlock {
		dpkg --print-architecture
	}
}

function Start-Service{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$ServiceName
	)

	Write-DoingAction "Atempting to start service $ServiceName"
	Invoke-Command -ScriptBlock{
		sudo systemctl start $ServiceName 2>&1
	}
	Write-Result
}

function Stop-Service{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$ServiceName
	)

	Write-DoingAction "Atempting to stop service $ServiceName"
	Invoke-Command -ScriptBlock{
		sudo systemctl stop $ServiceName 2>&1
	}
	Write-Result
}

function Restart-Service{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$ServiceName
	)

	Write-DoingAction "Atempting to restart service $ServiceName"
	Invoke-Command -ScriptBlock{
		sudo systemctl restart $ServiceName 2>&1
	}
	Write-Result
}