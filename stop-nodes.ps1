#!/usr/bin/pwsh

Param(
    [array]$NodeIndexes,
    [switch]$Force,
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
Write-Section "Stopping Elrond Node/s"
Invoke-Command -ScriptBlock {sudo ls} | Out-Null

$nodesConfig = Get-ElrondNodesConfig

$result = Test-ElrondNodesConfig -NodesConfig $nodesConfig -Verbose:$Verbose

if($NodeIndexes -eq $null){
    $NodeIndexes = $nodesConfig.Keys | Sort-Object
}

$numberOfNodes = 0
foreach($nodeIndex in $NodeIndexes){
    if($nodesConfig.Keys -notcontains $nodeIndex){
        continue
    }
    $numberOfNodes++
}

$displayAmount = $numberOfNodes -eq 1 ? "node" : "nodes"
if($result -eq $true){
    if(!$Force.IsPresent){
        Get-ContinueApproval `
        -Message "Valid configuration found. Stopping $numberOfNodes $displayAmount!"
    }
}
else{
    if(!$Force.IsPresent){
        Get-ContinueApproval -Warn `
        -Message "Non-standard configuration was discovered. Stopping $numberOfNodes $displayAmount!"
    }
}

if($nodesConfig.Count -eq 0){
    Write-WarningResult -Message "Nodes not found on current system. Aborting..."
    
    exit
}

Write-Subsection "Stopping nodes"

$noWarn = $true
foreach($nodeIndex in $NodeIndexes){

    $nodeConfig = $nodesConfig["$nodeIndex"]

    if(!$nodeConfig){
        Write-WarningResult "Node having index $nodeIndex not found on local system." -WithPrefix
        $noWarn = $false

        continue
    }
    
    Stop-ElrondNode -NodeIndex $nodeIndex

    if($nodeConfig["ValidKey"] -ne "Yes"){
        Write-WarningResult "Invalid or duplicate key for node-$nodeIndex" -WithPrefix
        $noWarn = $false
    }
}

#
# End section
#
if($noWarn){
    Write-Section "Successfully stopped $numberOfNodes $displayAmount nodes"
}
else{
    Write-Section "Task finished with warnings. Please check output for more details."
}
