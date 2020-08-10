#!/usr/bin/pwsh

Param(
    [int]$NumberOfNodes = 1,
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
Write-Section "Removing Elrond Node/s"
Invoke-Command -ScriptBlock {sudo ls} | Out-Null

$nodesConfig = Get-ElrondNodesConfig
if($nodesConfig.Count -eq 0){
    Write-WarningResult "There isn't any node deployed on current system. Aborting..."

    exit
}
if($NumberOfNodes -gt $nodesConfig.Count){
    $NumberOfNodes = $nodesConfig.Count
}

if(!$Force.IsPresent){
    Get-ContinueApproval -Message "$NumberOfNodes node will be removed! Are you sure you want to remove the nodes?" -Warn
}

for($i=0; $i -lt $NumberOfNodes; $i++){
    Write-Host ""
    Remove-ElrondNode -Force:$Force
}

#
# End section
#
Write-Section "Finished removing nodes"
