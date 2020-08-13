#Requires -Modules ErdCore,ErdIO,ErdUtils,ErdGit

#
# ErdNode Powershell Module
#

function Install-Go{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$Version,
		[Parameter(Mandatory=$true)]
		[string]$BuildDir,
		[Parameter(Mandatory=$true)]
		[string]$TargetPath
	)

	$architecture = Get-Architecture
	$url = "https://dl.google.com/go/$Version.linux-$architecture.tar.gz"
	$tgzPath = "$BuildDir/go.tgz"
	$targetGoPath = "$TargetPath/go"
	Initialize-Dir -Path $BuildDir -SkipClean -Silent

	Write-DoingAction "Checking for any existing go installation at $targetGoPath"
	if(Test-Path "$targetGoPath/bin/go"){
		$currentVersion = Invoke-Command -ScriptBlock {&"$targetGoPath/bin/go" version}
		if($currentVersion -Match $Version){
			Write-OkResult -Message $Version
			
			return $true
		}
		else{
			$currentVersion = ($currentVersion -split "\s")[2]
			Write-WarningResult -Message $currentVersion
			Write-DoingAction "Removing previous Go installation"
			Invoke-Command -ScriptBlock{
				sudo rm -rf $targetGoPath
			}
			Write-Result
		}
	}
	else{
		Write-OkResult -Message "NOT FOUND"
	}
	
	$result = Get-FileFromWeb -Url $url -OutputFileName $tgzPath
	if(!$result){
		Write-ErrorResult -Message "Installation failed. Could not save to $tgzPath" -WithPrefix

		return $false
	}
	$result = Expand-GzipTarball -TgzPath $tgzPath -TargetPath $TargetPath -Clean
	if(!$result){
		Write-ErrorResult -Message "Error extracting go archive" -WithPrefix

		return $false
	}

	return $true
}

function Install-GoModules{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$GoBinPath,
		[Parameter(Mandatory=$true)]
		[string]$RepoPath
	)

	$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ? $true : $false

	Set-GoEnvironmentVariables -GoBinPath $GoBinPath
	$initialLocation = Get-Location
	Set-Location $RepoPath
	
	if(!$IsVerbose){
		Write-DoingAction "Downloading Go Modules"
	}
	else{
		Write-Host "Downloading Go Modules..."
	}
	
	if($IsVerbose){
		Invoke-Command -ScriptBlock{
			go mod vendor 2>&1
		}
		Write-Host "Finished downloading Go Modules."
	}
	else{
		Invoke-Command -ScriptBlock{
			go mod vendor 2>&1
		} | Out-Null
		Write-Result
	}

	Set-Location $initialLocation
}

function Build-ElrondNode{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$ConfigRepoUrl,
		[Parameter(Mandatory=$true)]
		[string]$ConfigRepoReleaseUrl,
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath,
		[Parameter(Mandatory=$true)]
		[string]$GoBinPath
	)

	Set-GoEnvironmentVariables -GoBinPath $GoBinPath
	$initialLocation = Get-Location
	$nodeSourcePath = "$ElrondGoRepoPath/cmd/node"
	$nodeTargetPath = "$nodeSourcePath/node"
	Set-Location $nodeSourcePath

	$versionTag = Get-GitVersionTag
	$releaseInfo = Get-GitReleaseInfo -GitReleaseInfoUrl $configRepoReleaseUrl
	$configVersion = $releaseInfo.tag_name

	Write-DoingAction "Building the Elrond Node"

	Remove-Item -Path $nodeTargetPath -ErrorAction SilentlyContinue -Force
	try{
		Invoke-Command -ScriptBlock{
			$arguments = "build","-i","-v","-ldflags=`"-X main.appVersion=$configVersion-0-$versionTag`""
			&"go" $arguments
		}
	}
	catch{
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix

		return $false
	}

	Set-Location $initialLocation
	if(Test-Path -Path $nodeTargetPath){
		Write-OkResult

		return $true
	}
	Write-ErrorResult

	return $false
}

function Build-ElrondArwen{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$GoBinPath,
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath
	)

	Set-GoEnvironmentVariables -GoBinPath $GoBinPath
	$initialLocation = Get-Location
	Set-Location $ElrondGoRepoPath

	$requiredArwenVersion = Get-RequiredModuleVersion -ElrondGoRepoPath $ElrondGoRepoPath -ModuleName "arwen-wasm-vm"
	if(!$requiredArwenVersion){
		Write-ErrorResult
		Set-Location $initialLocation

		return $false
	}

	Write-DoingAction "Building arwen-wasm-vm"
	$arwenUrl = "github.com/ElrondNetwork/arwen-wasm-vm/cmd/arwen"
	$arwenTargetPath = "$ElrondGoRepoPath/cmd/node/arwen"
	Remove-Item -Path $arwenTargetPath -ErrorAction SilentlyContinue -Force

	try{
		Invoke-Command -ScriptBlock{
			$arguments = "get","$arwenUrl@$requiredArwenVersion"
			&"go" $arguments
			$arguments = "build","-o",$arwenTargetPath,$arwenUrl
			&"go" $arguments
		}
	}
	catch{
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix
		Set-Location $initialLocation

		return $false
	}
	
	Set-Location $initialLocation
	if(Test-Path -Path $arwenTargetPath){
		$architecture = Get-Architecture
		Invoke-Command -ScriptBlock{
			$arwenLibPath = "$ElrondGoRepoPath/vendor/github.com/ElrondNetwork/arwen-wasm-vm/wasmer/libwasmer_linux_$architecture.so"
			$arguments = "cp","-f","$arwenLibPath","/lib/"
			&"sudo" $arguments
		}

		return $true
	}
	Write-ErrorResult

	return $false
}

function Build-ElrondUtil{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$GoBinPath,
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath,
		[Parameter(Mandatory=$true)]
		[string]$Name
	)

	Set-GoEnvironmentVariables -GoBinPath $GoBinPath
	$initialLocation = Get-Location
	$utilSourcePath = "$ElrondGoRepoPath/cmd/$Name"
	$utilTargetPath = "$utilSourcePath/$Name"
	Set-Location $utilSourcePath

	Write-DoingAction "Building $Name"
	Remove-Item -Path $utilTargetPath -ErrorAction SilentlyContinue -Force

	try{
		Invoke-Command -ScriptBlock{
			go build
		}
	}
	catch{
		Write-WarningResult -Message $_.Exception.Message -WithPrefix
		Set-Location $initialLocation

		return
	}
	
	Set-Location $initialLocation
	if(Test-Path -Path $utilTargetPath){
		Write-OkResult

		return
	}
	Write-WarningResult

	return
}

function Deploy-ElrondNode{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath,
		[Parameter(Mandatory=$true)]
		[string]$ConfigRepoPath,
		[Parameter(Mandatory=$true)]
		[PsCustomObject]$UserConfig,
		[Parameter(Mandatory=$true)]
		[string]$NodeIndex,
		[Parameter(Mandatory=$true)]
		[string]$UserName,
		[Parameter(Mandatory=$true)]
		[string]$NodeFlags,
		[string]$NodeDir,
		[string]$ShardId,
		[switch]$Upgrade,
		[switch]$StartNodes
	)

	if(!$NodeDir){
		$NodeDir = $UserConfig.NodesDir + "/node-$NodeIndex"		
	}
	$nodeConfigDir = "$NodeDir/config"
	
	if(!$Upgrade.IsPresent){
		Initialize-Dir -Path $nodeConfigDir
	}

	Write-DoingAction "Deploying Elrond node-$NodeIndex"
	$binaryDir = "$ElrondGoRepoPath/cmd"
	$result = Copy-Item -Path "$binaryDir/node/node" $NodeDir -Force -PassThru -ErrorAction SilentlyContinue
	if($result){
		Write-OkResult
	}
	else{
		return $false
	}

	Write-DoingAction "Deploying Arwen"
	$result = Copy-Item -Path "$binaryDir/node/arwen" $NodeDir -Force -PassThru -ErrorAction SilentlyContinue
	if($result){
		Write-OkResult
	}
	else{
		return $false
	}
	
	$prefs = [PSCustomObject]@{}
	if($Upgrade.IsPresent){
		Write-DoingAction "Getting current settings in prefs.toml"
		$prefs = Get-PrefsTomlValues -NodeConfigDir $nodeConfigDir
	}
	
	Write-DoingAction "Deploying configuration"
	
	$configFiles = Get-ChildItem -Path $ConfigRepoPath -File -Force -ErrorAction SilentlyContinue
	if(!$configFiles){
		Write-ErrorResult -Message "Could not find node configuration files at $ConfigRepoPath" -WithPrefix
	
		return $false
	}
	$configFiles | Copy-Item -Destination $nodeConfigDir -Force -ErrorAction SilentlyContinue -PassThru

	$subdirs = Get-ChildItem -Path $ConfigRepoPath -Directory -Force -Exclude ".git"
	if($subdirs){
		$subdirs | Copy-Item -Destination $nodeConfigDir -Recurse -Force
	}

	if($Upgrade.IsPresent){
		Set-PrefsTomlValues -NodeConfigDir $nodeConfigDir -ObjectRef ([ref]$prefs)
	}
	else{
		$nodeName = $UserConfig.NodesNamePrefix + "$NodeIndex"
		$ShardId = Test-ShardId -ShardId $ShardId
		Add-StringValueToObject -ObjectRef ([ref]$prefs) -MemberName "NodeDisplayName" -Value $nodeName
		Add-StringValueToObject -ObjectRef ([ref]$prefs) -MemberName "Identity" -Value $UserConfig.KeybaseIdentity
		Add-StringValueToObject -ObjectRef ([ref]$prefs) -MemberName "DestinationShardAsObserver" -Value $ShardId
	}

	$result = Set-PrefsTomlValues -NodeConfigDir $nodeConfigDir -ObjectRef ([ref]$prefs)

	if(!$result){
		return $false
	}
	Write-OkResult

	if(!$Upgrade.IsPresent){
		Write-DoingAction "Generating validatorKey.pem for node-$NodeIndex"
		
		$tmpDir = Get-ElrondRootBuildDir + "/tmp"
		$validatorKey = New-ElrondValidatorKey -ElrondGoRepoPath $ElrondGoRepoPath -TmpDir $tmpDir
		
		if(!$validatorKey){
			return $false
		}
		$result = Set-Content -Path "$nodeConfigDir/validatorKey.pem" -Value $validatorKey -ErrorAction SilentlyContinue -PassThru
		if(!$result){
			Write-WarningResult -Message "Could not set validatorKey.pem file content to $nodeConfigDir" -WithPrefix
	
			return $false
		}		
	}

	Deploy-ElrondNodeSystemd -NodeIndex $NodeIndex -NodeDir $NodeDir -UserName $UserName -NodeFlags $NodeFlags
	
	if($StartNodes.IsPresent){
		Start-ElrondNode -NodeIndex $NodeIndex
	}

	return $true
}

function Deploy-ElrondNodeSystemd{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$NodeIndex,
		[Parameter(Mandatory=$true)]
		[string]$NodeDir,
		[Parameter(Mandatory=$true)]
		[string]$UserName,
		[Parameter(Mandatory=$true)]
		[string]$NodeFlags,
		[string]$TmpDir = "/tmp"
	)

	Write-DoingAction "Deploying Systemd configuration for node-$NodeIndex"

	$templatePath = "$PSScriptRoot/../../.templates/systemd.template"
	$serviceName = "elrond-node-$NodeIndex"
	$systemdFileName = "/etc/systemd/system/$serviceName.service"
	$nodePort = 8080 + $NodeIndex
	$tempFileName = "$TmpDir/" + (Get-RandomString)

	$content = Get-Content -Path $templatePath -Raw -ErrorAction SilentlyContinue
	if(!$content){
		Write-WarningResult -Message "Could not read systemd template file!" -WithPrefix

		return $false
	}
	$content = $content -replace "###node-index###",$NodeIndex
	$content = $content -replace "###node-dir###",$NodeDir
	$content = $content -replace "###node-port###",$nodePort
	$content = $content -replace "###user-name###",$UserName
	$content = $content -replace "###node-flags###",$NodeFlags

	$result = Set-Content -Path $tempFilename -Value $content -ErrorAction SilentlyContinue -PassThru
	if(!$result){
		Write-WarningResult -Message "Could not write temp systemd file!" -WithPrefix

		return $false
	}

	try{
		Invoke-Command -ScriptBlock{
			sudo mv -f $tempFileName $systemdFileName
		}
		Write-OkResult
	}
	catch{
		Write-WarningResult -Message "Could not write systemd file $systemdFileName!" -WithPrefix

		return $false
	}

	Write-DoingAction "Reloading systemctl unit-files"

	try{
		Invoke-Command -ScriptBlock{
			sudo systemctl daemon-reload
		}
		Write-OkResult
	}
	catch{
		Write-WarningResult
	}

	Write-DoingAction "Enabling service $serviceName for autostart at boot."

	try{
		Invoke-Command -ScriptBlock{
			sudo systemctl enable $serviceName 2>&1
		}
		Write-OkResult
	}
	catch{
		Write-WarningResult
	}

	return $true
}

function Deploy-ElrondUtils{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath,
		[Parameter(Mandatory=$true)]
		[string]$UtilsDir
	)

	$binaryDir = "$ElrondGoRepoPath/cmd"
	Initialize-Dir -Path $UtilsDir -SkipClean -Silent

	foreach($utilName in Get-ElrondUtils){
		Write-DoingAction "Deploying $utilName"
		$result = Copy-Item -Path "$binaryDir/$utilName/$utilName" $UtilsDir -Force -ErrorAction SilentlyContinue -PassThru
		if(!$result){
			Write-WarningResult -Message "Could not copy $binaryDir/$utilName/$utilName to $UtilsDir" -WithPrefix
		}
		else{
			Write-OkResult
		}
	}
}

function Get-PrefsTomlValues{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$NodeConfigDir
	)

	$prefsTomlPath = "$NodeConfigDir/prefs.toml"

	$prefsLines = Get-Content -Path $prefsTomlPath -ErrorAction SilentlyContinue

	if(!$prefsLines){
		Write-WarningResult -Message "Could not read $prefsTomlPath!" -WithPrefix
		return $false
	}

	$prefs = [PSCustomObject]@{}
	foreach($prefMember in Get-PrefsTomlMembersForBackup){
		$memberValue = Get-TomlValue -Content $prefsLines -PropertyName $prefMember
		Add-StringValueToObject -ObjectRef ([ref]$prefs) -MemberName $prefMember -Value $memberValue
	}

	return $prefs
}

function Set-PrefsTomlValues{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$NodeConfigDir,
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef
	)

	$prefsTomlPath = "$NodeConfigDir/prefs.toml"

	$prefsLines = Get-Content -Path $prefsTomlPath -ErrorAction SilentlyContinue

	if(!$prefsLines){
		Write-WarningResult -Message "Could not read $prefsTomlPath!" -WithPrefix

		return $false
	}
	foreach($member in Get-Member -InputObject $ObjectRef.Value -MemberType NoteProperty){
		$memberName = $member.Name
		$prefsLines = Set-TomlValue -Content $prefsLines -PropertyName $memberName -Value $ObjectRef.Value.$memberName
	}

	$result = Set-Content -Path $prefsTomlPath -Value $prefsLines -ErrorAction SilentlyContinue -PassThru
	if(!$result){
		Write-WarningResult -Message "Could not write $prefsTomlPath!" -WithPrefix

		return $false
	}		

	return $true
}

function New-ElrondValidatorKey{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath,
		[string]$TmpDir = "/tmp"
	)

	if(!(Test-Path -Path $TmpDir)){
		Initialize-Dir -Path $TmpDir -SkipClean
	}

	$keyFileName = "$TmpDir/validatorKey.pem"

	$initialLocation = Get-Location

	Set-Location $TmpDir

	try{
		Invoke-Command -ScriptBlock{
			&"$ElrondGoRepoPath/cmd/keygenerator/keygenerator"
		} | Out-Null
	}
	catch{
		Write-WarningResult -Message "Could not generate validatorKey.pem" -WithPrefix

		return $false
	}

	$rawKey = Get-Content -Path $keyFileName -Raw

	if(!$rawKey){
		Write-WarningResult -Message "Could not generate validatorKey.pem" -WithPrefix

		return $false
	}
	Remove-Item $keyFileName -Force -ErrorAction SilentlyContinue
	Set-Location $initialLocation

	return $rawKey
}

function Backup-ElrondNodeKey{

	Param(
		[Parameter(Mandatory=$true)]
		[hashtable]$NodeConfig,
		[Parameter(Mandatory=$true)]
		[string]$BackupDir,
		[switch]$Force
	)

	$nodeIndex = $NodeConfig["NodeIndex"]
	$keyPath = $NodeConfig["WorkingDir"] + "/config/validatorKey.pem"
	$nodeBackupDir = $BackupDir + "/node-$nodeIndex/config/"

	if(!(Test-Path -Path $nodeBackupDir)){
		Initialize-Dir -Path $nodeBackupDir
	}

	if((Test-Path -Path "$nodeBackupDir/validatorKey.pem") -and (!$Force.IsPresent)){
		Get-ContinueApproval -Message "Backup for node-$nodeIndex already exists at $nodeBackupDir. Do you want to continue?" -Warn
	}

	Write-DoingAction "Backing up key for node-$nodeIndex"
	$result = Copy-Item -Path $keyPath -Destination $nodeBackupDir -PassThru -ErrorAction SilentlyContinue
	if(!$result){
		Write-ErrorResult

		return $false
	}
	Write-OkResult
	
	return $true
}

function Restore-ElrondNodeKey{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$KeyPath,
		[Parameter(Mandatory=$true)]
		[hashtable]$NodeConfig,
		[switch]$Force
	)

	$nodeIndex = $NodeConfig["NodeIndex"]
	$restorePath = $NodeConfig["WorkingDir"] + "/config/" + "validatorKey.pem"

	if(!(Test-FileIsReadable -Path $keyPath)){
		Write-ErrorResult "Could not restore validator key for node-$nodeIndex"

		return $false
	}

	if((Test-Path -Path $restorePath) -and !$Force.IsPresent){
		Get-ContinueApproval -Message "Key for node-$nodeIndex will be replaced. Do you want to continue?" -Warn
	}

	Write-DoingAction "Restoring key for node-$nodeIndex"
	$result = Copy-Item -Path $keyPath -Destination $restorePath -Force -PassThru -ErrorAction SilentlyContinue
	if(!$result){
		Write-ErrorResult

		return $false
	}
	Write-OkResult
	
	return $true
}

function Get-ElrondNodeKey{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$KeyPath
	)

	$key = Get-Content -Path $KeyPath -Raw -ErrorAction SilentlyContinue

	if($key){
		return $key.Trim()
	}

	return $key
}

function Test-ElrondNodeKey{
	
	Param(
		[string]$Key
	)

	if(!$Key){
		return $false
	}

	$parts = $Key -split "-----"
	$parts = $parts | Select-String -Notmatch "^\s*$"

	if([string]::IsNullOrWhiteSpace($parts[1])){
		return $false
	}

	$headerPrivateKey = ($parts[0] -split "BEGIN PRIVATE KEY for ")[-1]
	$footerPrivateKey = ($parts[2] -split "END PRIVATE KEY for ")[-1]
	if($headerPrivateKey -ne $footerPrivateKey){
		return $false
	}

	return $true
}

function Start-ElrondNode{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$NodeIndex
	)

	Start-Service -ServiceName "elrond-node-$NodeIndex"
}

function Stop-ElrondNode{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$NodeIndex
	)

	Stop-Service -ServiceName "elrond-node-$NodeIndex"
}

function Restart-ElrondNode{
	
	Param(
		[Parameter(Mandatory=$true)]
		[string]$NodeIndex
	)

	Restart-Service -ServiceName "elrond-node-$NodeIndex"
}

function Start-ElrondNodes{
	$nodesConfig = Get-ElrondNodesConfig

	foreach($nodeKey in $nodesConfig.Keys){
		Start-ElrondNode -NodeIndex $nodeKey
	}
}

function Stop-ElrondNodes{
	$nodesConfig = Get-ElrondNodesConfig

	foreach($nodeKey in $nodesConfig.Keys){
		Stop-ElrondNode -NodeIndex $nodeKey
	}
}

function Restart-ElrondNodes{
	$nodesConfig = Get-ElrondNodesConfig

	foreach($nodeKey in $nodesConfig.Keys){
		Restart-ElrondNode -NodeIndex $nodeKey
	}
}

function Get-ElrondNodesConfig{

	Param(
		[switch]$GetProcessInfo,
		[switch]$Silent
	)

	if(!$Silent.IsPresent){
		Write-DoingAction "Discovering Elrond nodes"
	}

	$systemdFiles = Get-Item -Path "/etc/systemd/system/elrond-node-*.service"

	$nodesConfig = @{}
	$keys = @{}
	
	foreach($systemdFile in $systemdFiles){
		$nodeIndex = ((($systemdFile.Name -split "-")[-1]) -split "\.")[0]
		$content = Get-Content -Path $systemdFile

		$workingDir = Get-SystemdConfigValue -Content $content -PropertyName WorkingDirectory
		$execStart = Get-SystemdConfigValue -Content $content -PropertyName ExecStart
		$connectionString = (($execStart -split "-rest-api-interface")[1]) -split ":"
		$nodeHost = $connectionString[0].Trim()
		$nodePort = ($connectionString[1] -split "\s")[0]

		$prefsValues = Get-PrefsTomlValues -NodeConfigDir "$workingDir/config"

		$nodeConfig = @{}
		$nodeConfig["NodeIndex"] = $nodeIndex
		$nodeConfig["WorkingDir"] = $workingDir
		$nodeConfig["NodeHost"] = $nodeHost
		$nodeConfig["NodePort"] = $nodePort
		$nodeConfig["NodeName"] = $prefsValues.NodeDisplayName
		$nodeConfig["ShardId"] = $prefsValues.DestinationShardAsObserver
		$nodeConfig["Identity"] = $prefsValues.Identity

		if($GetProcessInfo.IsPresent){
			$nodeProcess = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object Path -match "$workingDir/node"
			if($nodeProcess){
				$nodeConfig["ProcessId"] = $nodeProcess.Id
			}
			else{
				$nodeConfig["ProcessId"] = "N/A"
			}
		}

		$key = Get-ElrondNodeKey -KeyPath "$workingDir/config/validatorKey.pem"
		if(Test-ElrondNodeKey -Key $key){
			$nodeConfig["ValidKey"] = "Yes"
			foreach($existingIndex in $keys.Keys){
				$existingKey = $keys[$existingIndex]
				if($key -eq $existingKey){
					$nodeConfig["ValidKey"] = "Duplicate with node-$existingIndex"
				}
			}
		}
		else{
			$nodeConfig["ValidKey"] = "No"
		}

		$keys[$nodeIndex] = $key
		$nodesConfig[$nodeIndex] = $nodeConfig
	}

	$count = $systemdFiles.Count
	if(!$Silent.IsPresent){
		Write-OkResult -Message "Found $count nodes" -WithPrefix
	}

	return $nodesConfig
}

function Test-ElrondNodesConfig{

	Param(
		[Parameter(Mandatory=$true)]
		[hashtable]$NodesConfig
	)

	$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ? $true : $false
	$validConfig = $true

	if($NodesConfig.Count -eq 0){
		return $true
	}
	
	$maxIndex = ($NodesConfig.Keys | Measure-Object -Maximum).Maximum
	$IsVerbose ? (Write-DoingAction "Checking nodes indexes") : $null
	if($maxIndex + 1 -eq $NodesConfig.Count){
		$IsVerbose ? (Write-OkResult) : $null
	}
	else{
		Write-WarningResult -Message ("Found wrong max index $maxIndex for " + $NodesConfig.Count + " nodes") -WithPrefix
		$validConfig = $false
	}
	
	for($i = 0; $i -lt $NodesConfig.Count; $i++){
		$IsVerbose ? (Write-DoingAction "`nSystemd configuration for node-$i") : $null
		
		if($NodesConfig["$i"]){
			$IsVerbose ? (Write-OkResult -Message "FOUND!") : $null
			$nodeConfig = $NodesConfig["$i"]

			$IsVerbose ? (Write-DoingAction "Port configuration") : $null
			$requiredPort = 8080 + $i
			$discoveredPort = $nodeConfig["NodePort"]
			if($requiredPort -eq $discoveredPort){
				$IsVerbose ? (Write-OkResult -Message $requiredPort) : $null
			}
			else{
				$IsVerbose ? (Write-WarningResult -Message "Wrong port $discoveredPort. Expected $requiredPort") : $null
				$validConfig = $false
			}

			$IsVerbose ? (Write-DoingAction "Directory naming configuration") : $null
			$requiredDir = "node-$i"
			$discoveredDir = (($nodeConfig["WorkingDir"]) -split "/")[-1]
			if($requiredDir -eq $discoveredDir){
				$IsVerbose ? (Write-OkResult -Message $requiredDir) : $null
			}
			else{
				$IsVerbose ? (Write-WarningResult -Message "Wrong directory name $discoveredDir. Expected $requiredDir") : $null
				$validConfig = $false
			}
		}
		else{
			$IsVerbose ? (Write-WarningResult -Message "Systemd configuration not found" -WithPrefix) : $null
			$validConfig = $false
		}
	}

	return $validConfig
}

function Remove-ElrondNode{

	Param(
		[switch]$Force
	)

	$nodesConfig = Get-ElrondNodesConfig
	
	if($nodesConfig.Count -gt 0){
		$maxIndex = ($nodesConfig.Keys | Measure-Object -Maximum).Maximum
		$nodeConfig = $nodesConfig["$maxIndex"]
		$nodeDir = $nodeConfig["WorkingDir"]

		if(!$Force.IsPresent){
			Write-Hash -ObjectRef ([ref]$nodeConfig) -Sort
			Get-ContinueApproval -Message "The node described above will be removed. Are you sure you want to continue?" -Warn
		}
		
		Stop-ElrondNode -NodeIndex $maxIndex

		Write-DoingAction "Removing node-$maxIndex data at $nodeDir"
		Remove-Item -Path $nodeDir -Recurse -Force -ErrorAction SilentlyContinue
		Write-SoftResult
		
		Write-DoingAction "Removing node-$maxIndex systemd configuration"
		$systemdFilePath = "/etc/systemd/system/elrond-node-$maxIndex.service"
		try{
			Invoke-Command -ScriptBlock{
				sudo rm -f $systemdFilePath
			}
			Write-OkResult
		}
		catch{
			Write-WarningResult -Message "Systemctl reload failed " + $_.Exception.Message -WithPrefix
		}

		Write-DoingAction "Reloading systemd configuration"
		try{
			Invoke-Command -ScriptBlock{
				sudo systemctl daemon-reload
			}
			Write-OkResult
		}
		catch{
			Write-WarningResult -Message "Systemctl reload failed " + $_.Exception.Message -WithPrefix
		}
	}
}

function Get-RequiredModuleVersion{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$ElrondGoRepoPath,
		[Parameter(Mandatory=$true)]
		[string]$ModuleName
	)

	Write-DoingAction "Getting required version for module `"$ModuleName`""
	try{
		$modulesFilePath = "$ElrondGoRepoPath/go.mod"
		$moduleEntry = Get-Content -Path $modulesFilePath -ErrorAction SilentlyContinue | Select-String $ModuleName
		if(!$moduleEntry){
			Write-ErrorResult "Could not read content of $modulesFilePath" -WithPrefix

			return $false
		}
		if(($moduleEntry | Measure-Object).Count -ne 1){
			Write-ErrorResult "No match or multiple matches found" -WithPrefix

			return $false
		}
		$moduleVersion = ($moduleEntry -split "\s")[-1]
		if(!$moduleVersion){
			Write-ErrorResult "Could not find version of $ModuleName from line $moduleEntry" -WithPrefix

			return $false
		}

		Write-OkResult -Message $moduleVersion
		return $moduleVersion
	}
	catch{
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix

		return $false
	}
}

function Test-ShardId{

	Param(
		[string]$ShardId
	)

	if($ShardId -notmatch "^[-]?\d{1,9}$"){
		return "disabled"
	}

	if($ShardId -eq -1){
		return "metachain"
	}

	if($ShardId -ge 0 -and $ShardId -le 999999999){
		return "$ShardId"
	}

	return "disabled"
}

function Set-GoEnvironmentVariables{

	Param(
		[string]$GoBinPath = "/usr/local/go/bin",
		[string]$Go111Module = "on"
	)

	if($env:GO111MODULE -notmatch $Go111Module){
		$env:GO111MODULE = $Go111Module
	}

	if($env:PATH -notmatch $GoBinPath){$NODE_EXTRA_FLAGS
		$env:PATH += ":$GoBinPath"
	}
}

function Get-BinaryVersion{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$ConfigRepoPath
	)

	$filePath = "$ConfigRepoPath/binaryVersion"

	return (Get-Content -Path $filePath).Trim()
	
}

function Get-ElrondUtils{
	return "termui","logviewer","seednode","keygenerator"
}

function Get-PrefsTomlMembersForBackup{
	return "DestinationShardAsObserver","NodeDisplayName","Identity"
}
