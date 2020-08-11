#!/usr/bin/pwsh

Param(
    [string]$BackupDir,
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
Write-Section "Starting Elrond Node/s Keys Backup"

# User Configuration
$userConfig = Get-ConfigValues -ConfigFile "$PSScriptRoot/config/user-config.json"
try{
    Add-StringValueToObject -ObjectRef ([ref]$userConfig) -MemberName UtilsDir -Value $BackupDir
    Test-WritePermissionsOnDirPathArgument -DirPath $userConfig.BackupDir -ArgumentName "BackupDir"
}
catch{
    Write-ErrorResult -Message "Error during user settings and arguments check! Aborting..."

    exit
}

Write-Section "Discovering Elrond nodes on current system"
$nodesConfig = Get-ElrondNodesConfig

$result = Test-ElrondNodesConfig -NodesConfig $nodesConfig -Verbose:$Verbose

if(!$NodeIndexes){
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
        Write-Subsection "Valid configuration found. Proceeding with backup for $numberOfNodes $displayAmount"
}
else{
        Write-Subsection "Non-standard configuration was discovered. Proceeding with backup for $numberOfNodes $displayAmount" -Warn
}

if($nodesConfig.Count -eq 0){
    Write-WarningResult -Message "Nothing to backup. Aborting..."
    
    exit
}

if(!$NodeIndexes){
    $NodeIndexes = $nodesConfig.Keys
}

Write-Subsection "Backing up keyfiles"

foreach($nodeIndex in $NodeIndexes){
    if($nodesConfig.Keys -notcontains $nodeIndex){
        Write-WarningResult -Message "node-$nodeIndex not found on system" -WithPrefix

        if(!$Force.IsPresent){
            exit
        }
    }
}

$noWarn = $true
foreach($nodeIndex in $NodeIndexes){
    if($nodesConfig.Keys -notcontains $nodeIndex){
        $noWarn = $false
        continue
    }

    Write-Host
    $result = Backup-ElrondNodeKey -BackupDir $userConfig.BackupDir -NodeConfig $nodesConfig["$nodeIndex"] -Force:$Force

    if(!$result){
        $noWarn = $false
    }
}

#
# End section
#
if($noWarn){
    Write-Section "Successfully backed up keys for the Elrond nodes"
}
else{
    Write-Section "Backup finished with warnings. Please check output for more details."
}
