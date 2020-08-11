#!/usr/bin/pwsh

Param(
    [string]$NodesDir,
    [string]$UtilsDir,
    [switch]$Verbose
)

# Import modules
$requiredModules = "ErdCore","ErdIO","ErdUtils","ErdGit","ErdNode","ErdSystem"
foreach($requiredModule in $requiredModules){
    Import-Module "$PSScriptRoot/.modules/$requiredModule/$requiredModule.psd1" -Force
}

#
# Start section
#
Clear-Host
Write-Section "Starting Elrond full cleanup procedures"
Invoke-Command -ScriptBlock {sudo ls} | Out-Null

# Elrond Configuration
$elrondConfig = Get-ConfigValues -ConfigFile "$PSScriptRoot/config/elrond-config.json" -Verbose:$Verbose
if(!$elrondConfig){
    Write-ErrorResult -Message "Elrond configuration not found. Aborting..." -WithPrefix

    exit
}

# User Configuration
$userConfig = Get-ConfigValues -ConfigFile "$PSScriptRoot/config/user-config.json"
if(!$userConfig){
    $userConfig = [PSCustomObject]@{}
}
Add-StringValueToObject -ObjectRef ([ref]$userConfig) -MemberName NodesDir -Value $NodesDir
Add-StringValueToObject -ObjectRef ([ref]$userConfig) -MemberName UtilsDir -Value $UtilsDir

# Get the user confirmation
if(!$Force.IsPresent){
    Get-ContinueApproval -Message "All data, including keys will be lost. Are you sure you want to continue?" -Warn
}

$nodesConfig = Get-ElrondNodesConfig -Silent
Write-Subsection "Removing all nodes"
if($nodesConfig.Count -eq 0){
    Write-WarningResult -Message "Did not find any node running" -WithPrefix
}
else{
    for($i = 0; $i -lt $nodesConfig.Count; $i++){
        Write-Host
        Remove-ElrondNode
    }
}

Write-Subsection "Removing all data"
Write-DoingAction "Removing Nodes Directory"
Remove-Item -Path $userConfig.NodesDir -Recurse -Force -ErrorAction SilentlyContinue
Write-SoftResult

Write-DoingAction "Removing Utils Directory"
Remove-Item -Path $userConfig.UtilsDir -Recurse -Force -ErrorAction SilentlyContinue
Write-SoftResult

Write-DoingAction "Removing Build Directory"
Remove-Item -Path (Get-ElrondBuildDir) -Recurse -Force -ErrorAction SilentlyContinue
Write-SoftResult

Write-DoingAction "Removing Go"
$goInstallDir = $elrondConfig.GoInstallDir + "/go"
$rootBuildDir = Get-ElrondRootBuildDir
Invoke-Command -ScriptBlock{
    sudo rm -rf $goInstallDir
    sudo rm -f /lib/libwasmer_*
    sudo rm -rf $rootBuildDir
}
Write-Result

#
# End section
#
Write-Section "Finished Elrond full cleanup"
