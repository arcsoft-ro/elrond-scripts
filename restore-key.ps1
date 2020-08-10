#!/usr/bin/pwsh

Param(
    [Parameter(Mandatory=$true)]
    [string]$NodeIndex,
    [Parameter(Mandatory=$true)]
    [string]$KeyPath,
    [switch]$StartNode
)

# Import modules
$requiredModules = "ErdCore","ErdIO","ErdUtils","ErdGit","ErdNode","ErdSystem"
foreach($requiredModule in $requiredModules){
    Import-Module "$PSScriptRoot/.modules/$requiredModule/$requiredModule.psd1" -Force
}

if(!(Test-FileIsReadable -Path $KeyPath -Verbose:$Verbose)){
    Write-Host
    Write-ErrorResult -Message "Validator key $KeyPath is not readable. Aborting..." -WithPrefix

    exit
}

#
# Start section
#
Clear-Host
Write-Section "Restoring Elrond kode validator key"
Invoke-Command -ScriptBlock {sudo ls} | Out-Null

$nodesConfig = Get-ElrondNodesConfig

$result = Test-ElrondNodesConfig -NodesConfig $nodesConfig -Verbose:$Verbose

if($result -eq $true){
    Write-Subsection "Valid configuration found. Restoring key"
}
else{
    if(!$Force.IsPresent){
        Get-ContinueApproval -Warn `
        -Message "Non-standard configuration was discovered. Starting $numberOfNodes $displayAmount!"
    }
}

if($nodesConfig.Count -eq 0){
    Write-WarningResult -Message "Nodes not found on current system. Aborting..."
    
    exit
}

$nodeConfig = $nodesConfig["$NodeIndex"]
if($null -eq $nodeConfig){
    Write-ErrorResult -Message "Configuration for node-$NodeIndex not found. Aborting..." -WithPrefix
}

$result = Restore-ElrondNodeKey -KeyPath $KeyPath -NodeConfig $nodeConfig
if($result -ne $true){
    Write-ErrorResult -Message "Validator key restoration for node-$NodeIndex from $KeyPath failed." -WithPrefix

    exit
}

if($StartNode.IsPresent){
    Restart-ElrondNode -NodeIndex $NodeIndex
}

#
# End section
#
Write-Section "Finished restoring key for node-$NodeIndex"
