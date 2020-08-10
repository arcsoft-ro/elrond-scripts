#Requires -Modules ErdCore

#
# ErdIO Powershell Module
#

function Test-FileIsReadable{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$Path
	)

	Write-DoingAction Checking file read permissions on $Path
	try {
		[System.IO.File]::OpenRead($Path).Close()
		Write-Result
		
		return $true
	}
	catch {
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix
		
		return $false
	}
}

function Test-FileIsWritable{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[switch]$ClearPath
	)
	
	Write-DoingAction Checking file write permissions on $Path
	try {
		[System.IO.File]::OpenWrite($Path).Close()
		Write-OkResult
	
		if($ClearPath.IsPresent){
			return Clear-Path -Path $Path
		}
		else{
			return $true
		}
	}
	catch {
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix
	
		return $false
	}
}

function Test-DirIsWritable{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[switch]$ClearPath
	)
	
	Write-DoingAction Checking directory write permissions on $Path
	try {
		$fileName = Get-RandomString
		$writeTest = New-Item -Path "$Path/$fileName" -ErrorAction SilentlyContinue
		
		if(!$writeTest){
			Write-ErrorResult

			return $false
		}
		Remove-Item -Path "$Path/$fileName" -ErrorAction SilentlyContinue
		Write-OkResult
	
		if($ClearPath.IsPresent){
			return Clear-Path -Path $Path
		}
		else{
			return $true
		}
	}
	catch {
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix
		
		return $false
	}
}

function Clear-Path{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$Path
	)

	return $Path.Replace("\\","\").Replace("//","/").TrimEnd("\").TrimEnd("/")
}

function Initialize-Dir{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[switch]$SkipClean,
		[switch]$Throw,
		[switch]$Silent
    )
	
	if(!$Silent.IsPresent){
		Write-DoingAction Initializing directory $Path
	}
	try{
		if(!$SkipClean.IsPresent){
			Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		}
		if(Test-Path -Path $Path){
			if(!$Silent.IsPresent){
				Write-WarningResult -Message "Directory already exists!" -WithPrefix
			}
		}
		else{
			New-Item -ItemType Directory -Path $Path -ErrorAction SilentlyContinue | Out-Null
			if(!$Silent.IsPresent){
				Write-SoftResult
			}
		}
	}
	catch{
		if($Throw.IsPresent){
			throw $_.Exception.Message
		}
		else{
			Write-ErrorResult -Message $_.Exception.Message -WithPrefix
		}
	}
}

function Get-FileFromWeb{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$Url,
		[Parameter(Mandatory=$true)]
		[string]$OutputFileName
	)

	Write-DoingAction "Downloading from $Url"
	try {
		$webClient = New-Object System.Net.WebClient
		$webClient.DownloadFile($Url, $OutputFileName)
		Write-Result
	}
	catch {
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix
		
		return $false
	}

	return $true
}

function Expand-GzipTarball{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$TgzPath,
		[Parameter(Mandatory=$true)]
		[string]$TargetPath,
		[switch]$Clean
	)

	Write-DoingAction "Extracting gzipped tarball $TgzPath => $TargetPath"
	try{
		Invoke-Command -ScriptBlock{
			sudo tar -C $TargetPath -zxf $TgzPath
		}
		Write-OkResult
	}
	catch{
		Write-ErrorResult

		return $false
	}

	if($Clean.IsPresent){
		Remove-Item $TgzPath -Force -ErrorAction SilentlyContinue
	}

	return $true
}

function Get-TomlValue{

	Param(
		[Parameter(Mandatory=$true)]
		[array]$Content,
		[Parameter(Mandatory=$true)]
		[string]$PropertyName
	)

	$line = ($Content | Select-String "^\s*$PropertyName")

	return ($line -split "`"")[1]
}

function Set-TomlValue{

	Param(
		[Parameter(Mandatory=$true)]
		[array]$Content,
		[Parameter(Mandatory=$true)]
		[string]$PropertyName,
		[Parameter(Mandatory=$true)]
		[string]$Value
	)

	foreach($line in $Content){
		if($line -match "^\s*$PropertyName"){
			$newLine = $line -replace "`".*?`"","`"$Value`""

			return $Content -replace $line,$newLine
		}
	}

	$Content += "`n  # Added by elrond maintenance script`n  $PropertyName = `"$Value`""
	
	return $Content
}

function Get-SystemdConfigValue{

	Param(
		[Parameter(Mandatory=$true)]
		[array]$Content,
		[Parameter(Mandatory=$true)]
		[string]$PropertyName
	)

	$line = ($Content | Select-String "^\s*$PropertyName")

	return (($line -split "=")[-1]).TrimEnd()
}

function Set-SystemdConfigValue{

	Param(
		[Parameter(Mandatory=$true)]
		[array]$Content,
		[Parameter(Mandatory=$true)]
		[string]$PropertyName,
		[Parameter(Mandatory=$true)]
		[string]$Value
	)

	$newLine = "$PropertyName=$Value"
	
	foreach($line in $Content){
		if($line -match ".*$PropertyName\s*=\s*"){
			return $Content -replace $line,$newLine
		}
	}
	
	$Content += $newLine

	return $Content
}
