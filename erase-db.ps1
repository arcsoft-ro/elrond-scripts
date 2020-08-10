#!/usr/bin/pwsh

Param(
    [array]$NodeIndexes,
    [switch]$StartNodes,
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
Write-Section "Erasing Elrond Node/s DB"
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
        -Message "Valid configuration found. Starting DB erase for $numberOfNodes $displayAmount!"
    }
}
else{
    if(!$Force.IsPresent){
        Get-ContinueApproval -Warn `
        -Message "Non-standard configuration was discovered. Starting DB erase for $numberOfNodes $displayAmount!"
    }
}

if($nodesConfig.Count -eq 0){
    Write-WarningResult -Message "Nodes not found on current system. Aborting..."
    
    exit
}

Write-Subsection "Starting to erase DB on selected nodes"

$noWarn = $true
foreach($nodeIndex in $NodeIndexes){
    if($nodesConfig.Keys -notcontains $nodeIndex){
        Write-WarningResult "Node having index $nodeIndex not found on local system." -WithPrefix
        $noWarn = $false
        continue
    }

    $nodeConfig = $nodesConfig["$nodeIndex"]
    $nodeDbPath = $nodeConfig["WorkingDir"] + "/db"
    
    Stop-ElrondNode -NodeIndex $nodeIndex
    Write-DoingAction "Attempting DB erase for node-$nodeIndex"
    try{
        Remove-Item -Path $nodeDbPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-SoftResult
        Write-Host
    }
    catch{
        Write-WarningResult -Message "Could not erase DB for node-$nodeIndex"
        $noWarn = $false
    }

    if($StartNodes.IsPresent){
        Start-ElrondNode -NodeIndex $nodeIndex
    }
}

#
# End section
#
if($noWarn){
    Write-Section "Successfully erased DB for $numberOfNodes $displayAmount nodes"
}
else{
    Write-Section "Task finished with warnings. Please check output for more details."
}
