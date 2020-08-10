#!/usr/bin/pwsh

Param(
    [string]$UtilsDir,
    [switch]$StartNodes,
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
Write-Section "Starting Elrond Node/s Upgrade"
Invoke-Command -ScriptBlock {sudo ls} | Out-Null

# Elrond Configuration
$elrondConfig = Get-ConfigValues -ConfigFile "$PSScriptRoot/config/elrond-config.json" -Verbose:$Verbose
if(!$elrondConfig){
    Write-ErrorResult -Message "Elrond configuration not found. Aborting..." -WithPrefix

    exit
}
Test-ErdConfigValues -ObjectRef ([ref]$elrondConfig)

# User Configuration
$userConfig = Get-ConfigValues -ConfigFile "$PSScriptRoot/config/user-config.json"
if(!$userConfig){
    $userConfig = [PSCustomObject]@{}
}
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName UserName -Value $env:USER
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName UtilsDir -Value $UtilsDir

Test-UpgradeUserConfigValues -ObjectRef ([ref]$userConfig)

# Script variables
$goBinPath = $elrondConfig.GoInstallDir + "/go/bin"
$buildDir = Get-ElrondBuildDir
$elrondGoRepoPath = $buildDir + "/" + (Get-DefaultDirFromRepoUrl -RepoUrl $elrondConfig.ElrondGoRepoUrl)
$configRepoPath = $buildDir + "/" + ((Get-DefaultDirFromRepoUrl -RepoUrl $elrondConfig.ConfigRepoUrl))

Write-Section "Discovering Elrond nodes on current system"
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
        -Message "Valid configuration found. $numberOfNodes $displayAmount will be upgraded!"
    }
}
else{
    if(!$Force.IsPresent){
        Get-ContinueApproval -Warn `
        -Message "Non-standard configuration was discovered. $numberOfNodes $displayAmount will be upgraded!"
    }
}

#
# System check and preparation section
#
Write-Section "Preparing your system" -NoNewline
$systemCheckResult = Test-OsDistribution
if(!$systemCheckResult){
    Write-ErrorResult -Message "OS check failed! Only ubuntu and debian based 64bit systems are supported. Aborting..."
    
    exit
}
Update-System
Install-Dependencies
Set-JournalctlConfig

#
# Build preparation section
#

# Repos
Write-Section "Preparing build" -NoNewline
Sync-GitRepo -BuildDir $buildDir -RepoUrl $elrondConfig.ElrondGoRepoUrl -Verbose:$Verbose
Sync-GitRepo -BuildDir $buildDir -RepoUrl $elrondConfig.ConfigRepoUrl -Verbose:$Verbose

# Go
Write-Subsection "Installing Go"
$result = Install-Go -Version $elrondConfig.GoRequiredVersion -BuildDir $buildDir -TargetPath $elrondConfig.GoInstallDir
if(!$result){
    Write-ErrorResult -Message "Go installation failed. Aborting..."

    exit
}
Install-GoModules -GoBinPath $goBinPath -RepoPath $elrondGoRepoPath -Verbose:$Verbose

#
# Build section
#
Write-Section "Building the Elrond binaries" -NoNewline

# Node
Write-Subsection "Building the Elrond node"
$nodeBuildResult = Build-ElrondNode `
    -ConfigRepoReleaseUrl $elrondConfig.ConfigRepoReleaseUrl `
    -ConfigRepoUrl $elrondConfig.ConfigRepoUrl `
    -GoBinPath $goBinPath `
    -ElrondGoRepoPath $elrondGoRepoPath
    
if(!$nodeBuildResult){
    Write-ErrorResult -Message "Error building the Elrond node. Aborting..."

    exit
}

# Arwen
Write-Subsection "Building Arwen Wasm VM"
$arwenBuildResult = Build-ElrondArwen -GoBinPath $goBinPath -ElrondGoRepoPath $elrondGoRepoPath
if(!$arwenBuildResult){
    Write-ErrorResult -Message "Error building arwen-wasm-wm. Aborting..."

    exit
}

# Utils
Write-Subsection "Building the Elrond utils"
foreach($utilName in Get-ElrondUtils){
    Build-ElrondUtil -GoBinPath $goBinPath -ElrondGoRepoPath $elrondGoRepoPath -Name $utilName
}

#
# Deploy section
#

# Node/s
Write-Section "Upgrading the Elrond node/s and configuration" -NoNewline
foreach($nodeIndex in $NodeIndexes){

    $nodeConfig = $nodesConfig["$nodeIndex"]

    Write-Subsection "Upgrading node-$nodeIndex"

    Stop-ElrondNode -NodeIndex $nodeIndex
    
    $result = Deploy-ElrondNode -ElrondGoRepoPath $elrondGoRepoPath `
    -ConfigRepoPath $configRepoPath `
    -UserConfig $userConfig `
    -NodeIndex $nodeIndex `
    -UserName $userConfig.UserName `
    -NodeFlags $elrondConfig.NodeFlags `
    -NodeDir $nodeConfig["WorkingDir"] `
    -Upgrade `
    -StartNodes:$StartNodes

    if(!$result){
        Write-ErrorResult -Message "Upgrading node-$nodeIndex failed. Aborting..." -WithPrefix

        exit
    }
}

# Utils
Write-Subsection "Deploying the Elrond utils"
Deploy-ElrondUtils -ElrondGoRepoPath $elrondGoRepoPath -UtilsDir $userConfig.UtilsDir

#
# End section
#
Write-Section "Finished Upgrading Elrond nodes"
