#Requires -Modules ErdCore,ErdIO

#
# ErdUtils Powershell Module
#

function Get-ConfigValues{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$ConfigFile
	)

	$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ? $true : $false

	if($IsVerbose){
		Write-DoingAction "Reading config file $ConfigFile"		
	}

	$configJson = Get-Content -Path $ConfigFile -Raw -ErrorAction SilentlyContinue

	if([string]::IsNullOrWhiteSpace($configJson)){
		if($IsVerbose){
			Write-WarningResult
		}
		
		return $null
	}
	if($IsVerbose){
		Write-OkResult
		Write-DoingAction "Parsing config file $ConfigFile"
	}

	try{
		$configObject = ConvertFrom-Json -InputObject $configJson -ErrorAction SilentlyContinue
		if($IsVerbose){
			Write-OkResult
		}
	}
	catch{
		if($IsVerbose){
			Write-WarningResult
		}
	}

	return $configObject
}

function Test-InstallUserConfigValues{

	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef
	)
	
	try{
		Test-WritePermissionsOnDirPathArgument -DirPath $ObjectRef.Value.NodesDir -ArgumentName "NodesDir"
		Test-MandatoryArgument -ArgumentName "NodesNamePrefix" -ArgumentValue $ObjectRef.Value.NodesNamePrefix
		Test-MandatoryArgument -ArgumentName "UserName" -ArgumentValue $ObjectRef.Value.UserName
		Test-WritePermissionsOnDirPathArgument -DirPath $ObjectRef.Value.UtilsDir -ArgumentName "UtilsDir"
		Test-MandatoryArgument -ArgumentName "TestNet" -ArgumentValue $ObjectRef.Value.TestNet
	}
	catch{
		Write-ErrorResult -Message "Error during user settings and arguments check! Aborting..."

		exit
	}
}

function Test-UpgradeUserConfigValues{

	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef
	)
	
	try{
		Test-MandatoryArgument -ArgumentName "UserName" -ArgumentValue $ObjectRef.Value.UserName
		Test-WritePermissionsOnDirPathArgument -DirPath $ObjectRef.Value.UtilsDir -ArgumentName "UtilsDir"
		Test-MandatoryArgument -ArgumentName "TestNet" -ArgumentValue $ObjectRef.Value.TestNet
	}
	catch{
		Write-ErrorResult -Message "Error during user settings and arguments check! Aborting..."

		exit
	}
}

function Test-ErdConfigValues{
	
	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef,
		[switch]$TestNet
	)

	if($TestNet.IsPresent){
		Test-MandatoryArgument -ArgumentName "TestNetConfigRepoUrl" -ArgumentValue $ObjectRef.Value.TestNetConfigRepoUrl
	}
	else{
		Test-MandatoryArgument -ArgumentName "ConfigRepoUrl" -ArgumentValue $ObjectRef.Value.ConfigRepoUrl		
	}
	Test-MandatoryArgument -ArgumentName "ConfigRepoReleaseUrl" -ArgumentValue $ObjectRef.Value.ConfigRepoReleaseUrl
	Test-MandatoryArgument -ArgumentName "ElrondGoRepoUrl" -ArgumentValue $ObjectRef.Value.ElrondGoRepoUrl
	Test-MandatoryArgument -ArgumentName "GoInstallDir" -ArgumentValue $ObjectRef.Value.GoInstallDir
	Test-MandatoryArgument -ArgumentName "GoRequiredVersion" -ArgumentValue $ObjectRef.Value.GoRequiredVersion
	Test-MandatoryArgument -ArgumentName "NodeFlags" -ArgumentValue $ObjectRef.Value.NodeFlags
}

function Test-WritePermissionsOnDirPathArgument{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$DirPath,
		[Parameter(Mandatory=$true)]
		[string]$ArgumentName
	)

	Test-MandatoryArgument -ArgumentName $ArgumentName -ArgumentValue $DirPath

	Initialize-Dir -Path $DirPath -SkipClean
    if(!(Test-DirIsWritable -Path $DirPath)){
		Write-ErrorResult -Message "`n$DirPath is not writable. Aborting..."

		exit
	}
}

function Test-MandatoryArgument{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$ArgumentName,
		[string]$ArgumentValue
	)

	if([string]::IsNullOrWhiteSpace($ArgumentValue)){
		Write-ErrorResult -Message "`n$ArgumentName not provided in config or script argument. Aborting..."

		exit
	}
}

function Start-Termui{

	Param(
		[Parameter(Mandatory=$true)]
		[string]$UtilsDir,
		[Parameter(Mandatory=$true)]
		[string]$NodeIndex
	)

	$nodesConfig = Get-ElrondNodesConfig

	if($nodesConfig.Keys -notcontains $NodeIndex){
		Write-WarningResult "Node having index $NodeIndex not found."

		return
	}

	$nodeConfig = $nodesConfig[$NodeIndex]

	try{

		Write-DoingAction "Starting TermUi for node-$NodeIndex"
		Write-OkResult
		Invoke-Command -ScriptBlock{
			$connectionString = $nodeConfig["NodeHost"] + ":" + $nodeConfig["NodePort"]
			$arguments = "--address",$connectionString
			&"$UtilsDir/termui" $arguments
		}
	}
	catch{
		Write-WarningResult -Message $_.Exception.Message -WithPrefix
	}
}