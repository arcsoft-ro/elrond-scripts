#!/usr/bin/pwsh

# Import modules
$requiredModules = "ErdCore","ErdIO","ErdUtils","ErdGit","ErdNode","ErdSystem"
foreach($requiredModule in $requiredModules){
    Import-Module "$PSScriptRoot/.modules/$requiredModule/$requiredModule.psd1" -Force
}

#
# Start section
#
Clear-Host
Write-Section "Checking Elrond nodes configuration on current system"
$nodesConfig = Get-ElrondNodesConfig -GetProcessInfo

foreach($nodeConfig in $nodesConfig.Values | Sort-Object -Property NodeIndex){
    $nodeIndex = $nodeConfig["NodeIndex"]
    Write-Subsection "Configuration for node-$nodeIndex"
    Write-Hash -ObjectRef ([ref]$nodeConfig) -Sort
}

#
# End section
#
Write-Section "Finished configuration check task."
