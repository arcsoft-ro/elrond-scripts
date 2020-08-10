#!/usr/bin/pwsh

Param(
    [string]$KeybaseIdentity,
    [string]$NodesDir,
    [string]$NodesNamePrefix,
    [int]$NumberOfNodes = 1,
    [string]$UtilsDir,
    [switch]$StartNodes,
    [array]$ShardIds,
    [switch]$Force,
    [switch]$SkipSystemUpgrade,
    [switch]$SkipBuild,
    [switch]$SkipUtilsDeploy,
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
Write-Section "Starting Elrond Node/s Installation"
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
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName KeybaseIdentity -Value $KeybaseIdentity
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName NodesDir -Value $NodesDir
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName NodesNamePrefix -Value $NodesNamePrefix
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName NumberOfNodes -Value $NumberOfNodes
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName UserName -Value $env:USER
Add-ValueToObject -ObjectRef ([ref]$userConfig) -MemberName UtilsDir -Value $UtilsDir

if($userConfig.UserName -eq "root"){
    Write-ErrorResult -Message "Installing the node as root is not allowed. Aborting...`n" -WithPrefix

    exit
}

# Script variables
$goBinPath = $elrondConfig.GoInstallDir + "/go/bin"
$buildDir = Get-ElrondBuildDir
$elrondGoRepoPath = $buildDir + "/" + (Get-DefaultDirFromRepoUrl -RepoUrl $elrondConfig.ElrondGoRepoUrl)
$configRepoPath = $buildDir + "/" + ((Get-DefaultDirFromRepoUrl -RepoUrl $elrondConfig.ConfigRepoUrl))
$displayAmount = $NumberOfNodes -eq 1 ? "node" : "nodes"
if($ShardIds -eq $null){
    $ShardIds = @()
}

# Get the user confirmation
Write-Subsection "Please check the installation configuration below"
Write-ObjectMembers -ObjectRef ([ref]$userConfig)
if(!$Force.IsPresent){
    Get-ContinueApproval -Message "$NumberOfNodes $displayAmount will be deployed. Do you want to continue?"
}

# Check arguments and permissions
Test-ErdConfigValues -ObjectRef ([ref]$elrondConfig)
Test-InstallUserConfigValues -ObjectRef ([ref]$userConfig)

Write-Section "Discovering Elrond nodes on current system"
$nodesConfig = Get-ElrondNodesConfig

if($nodesConfig.Count -gt 0){
    $startNodeIndex = (($nodesConfig.Keys | Measure-Object -Maximum).Maximum) + 1
    $result = Test-ElrondNodesConfig -NodesConfig $nodesConfig -Verbose:$Verbose
    if($result -eq $true){
        if(!$Force.IsPresent){
            Get-ContinueApproval `
            -Message "Valid configuration found. $NumberOfNodes $displayAmount will be added starting with node-$startNodeIndex"
        }
    }
    else{
        if(!$Force.IsPresent){
            Get-ContinueApproval -Warn `
            -Message "Non-standard configuration was discovered. $NumberOfNodes $displayAmount will be added starting with node-$startNodeIndex"
        }
    }
}
else{
    $startNodeIndex = 0
}

#
# System check and preparation section
#
if(!$SkipSystemUpgrade.IsPresent){
    Write-Section "Preparing your system" -NoNewline
    $systemCheckResult = Test-OsDistribution
    if(!$systemCheckResult){
        Write-ErrorResult -Message "OS check failed! Only ubuntu and debian based 64bit systems are supported. Aborting..."
        
        exit
    }
    Update-System
    Install-Dependencies
    Set-JournalctlConfig
}

#
# Build preparation section
#

if(!$SkipBuild.IsPresent){
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
}

#
# Deploy section
#

# Node/s
Write-Section "Deploying the Elrond node/s, configuration and systemd files" -NoNewline
$shardIndex = 0
for($i = $startNodeIndex; $i -lt $startNodeIndex + $NumberOfNodes; $i++ ){
    Write-Subsection "Deploying node-$i"
    
    $result = Deploy-ElrondNode -ElrondGoRepoPath $elrondGoRepoPath `
    -ConfigRepoPath $configRepoPath `
    -UserConfig $userConfig `
    -NodeIndex $i `
    -ShardId $ShardIds[$shardIndex] `
    -UserName $userConfig.UserName `
    -NodeFlags $elrondConfig.NodeFlags `
    -StartNodes:$StartNodes

    if(!$result){
        Write-ErrorResult -Message "Deployment of node-$i failed. Aborting..." -WithPrefix

        exit
    }
    $shardIndex++
}

# Utils
if(!$SkipUtilsDeploy.IsPresent){
    Write-Subsection "Deploying the Elrond utils"
    Deploy-ElrondUtils -ElrondGoRepoPath $elrondGoRepoPath -UtilsDir $userConfig.UtilsDir
}

#
# End section
#
Write-Section "Finished Elrond Node/s Installation"