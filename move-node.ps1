#!/usr/bin/pwsh

Param(
    [Parameter(Mandatory=$true)]
    [string]$NodeIndex,
    [Parameter(Mandatory=$true)]
    [string]$TargetDir,
    [switch]$StartNode,
    [switch]$Force
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
Write-Section "Starting the Elrond Node move procedure"
Invoke-Command -ScriptBlock {sudo ls} | Out-Null

$nodesConfig = Get-ElrondNodesConfig

$result = Test-ElrondNodesConfig -NodesConfig $nodesConfig -Verbose:$Verbose

if($result -ne $true -and !$Force.IsPresent){
    Get-ContinueApproval -Warn `
    -Message ("Invalid configuration found. Continue moving node-$NodeIndex to $TargetDir" + "?")
}

$nodeConfig = $nodesConfig["$NodeIndex"]
if(!$nodeConfig){
    Write-ErrorResult "Node having index $NodeIndex not found on current system. Aborting..."

    exit
}

Write-Subsection "Preparing the target directory"

$result = Test-Path -Path $TargetDir
if(!$result){
    Initialize-Dir -Path $TargetDir -SkipClean
}

$cleanTargetDir = Test-DirIsWritable -Path $TargetDir -ClearPath
if(!$cleanTargetDir){
    Write-ErrorResult "Target Directory $TargetDir is not writable. Aborting..."

    exit
}

Write-Subsection "The following node will be moved to $TargetDir"
Write-Hash -ObjectRef ([ref]$nodeConfig)
if(!$Force.IsPresent){
    Get-ContinueApproval -Message "Are you sure you want to continue?"
}

$currentWorkingDir = $nodeConfig["WorkingDir"]
$newWorkingDir = "$cleanTargetDir/node-$NodeIndex"
$systemdConfigPath = "/etc/systemd/system/elrond-node-$NodeIndex.service"
$tempFilePath = "/tmp/" + (Get-RandomString)

Stop-ElrondNode -NodeIndex $NodeIndex

Write-DoingAction "Moving node data"
Move-Item -Path $currentWorkingDir $cleanTargetDir -Force -ErrorAction SilentlyContinue
Write-Result

Write-DoingAction "Changing the systemd configuration"
$systemdConfigContent = Get-Content -Path $systemdConfigPath -Raw
$systemdConfigContent = $systemdConfigContent -replace $currentWorkingDir,$newWorkingDir
Set-Content -Path $tempFilePath -Value $systemdConfigContent

try{
    Invoke-Command -ScriptBlock{
        sudo mv -f $tempFilePath $systemdConfigPath
        sudo systemctl daemon-reload
    }
    Write-Result
}
catch{
    Write-ErrorResult -Message $_.Exception.Message -WithPrefix
}

if($StartNode.IsPresent){
    Start-ElrondNode -NodeIndex $NodeIndex
}

#
# End section
#

Write-Section "Finished moving the Elrond node node-$NodeIndex"
