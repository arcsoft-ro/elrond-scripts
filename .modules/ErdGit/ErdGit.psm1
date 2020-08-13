#Requires -Modules ErdCore

#
# ErdGit Powershell Module
#

enum RepoStatus {
    NOTEMPTY
    EMPTY
    URLMATCH
    URLMISMATCH
}

function Sync-GitRepo{

    Param(
        [Parameter(Mandatory=$true)]
        [string]$BuildDir,
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl,
        [string]$ReleaseTag
    )

    $IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ? $true : $false

    $repoDirName = Get-DefaultDirFromRepoUrl -RepoUrl $RepoUrl
    $repoPath = "$BuildDir/$repoDirName"
    Initialize-Dir -Path $BuildDir -SkipClean -Silent

    $workingDirStatus = Test-IsGitRepoValidOrEmpty -BuildDir $BuildDir -RepoUrl $RepoUrl

    switch ($workingDirStatus){
        ([RepoStatus]::NOTEMPTY) {
            Write-ErrorResult -Message "Target Git working directory $repoPath is not empty... Aborting" 
            
            exit
        }
        ([RepoStatus]::URLMISMATCH) { 
            Write-ErrorResult -Message "Target Git working directory $repoPath is containing a different repository... Aborting"
            
            exit
        }
        ([RepoStatus]::EMPTY) {
            Initialize-GitRepo -BuildDir $BuildDir -RepoUrl $RepoUrl -ReleaseTag $ReleaseTag -Verbose:$IsVerbose
        }
        ([RepoStatus]::URLMATCH) {
            Update-GitRepo -RepoPath $repoPath -Reset -ReleaseTag $ReleaseTag -Verbose:$IsVerbose
        }
        Default {
            Write-ErrorResult -Message "Could not fetch target Git working directory status from $repoPath... Aborting"
            
            exit
        }
    }
}

function Initialize-GitRepo{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$BuildDir,
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl,
        [string]$ReleaseTag
    )

    $IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ? $true : $false

    Initialize-Dir -Path $BuildDir -SkipClean -Silent
    Write-Subsection "Initializing repository"

    Write-DoingAction "Cloning repo $RepoUrl to $BuildDir"

    $initialLocation = Get-Location
    Set-Location $BuildDir

    $output = Invoke-Command -ScriptBlock {
        if($IsVerbose){
            git clone $RepoUrl
        }
        else{
            git clone $RepoUrl 2>&1
        }
    }

    if($IsVerbose){
        $output
    }
    else{
        Write-Result
    }

    if(![string]::IsNullOrWhiteSpace($ReleaseTag)){
        
        Set-Location (Get-DefaultDirFromRepoUrl -RepoUrl $RepoUrl)
        Write-DoingAction "Switching to release tag $ReleaseTag"

        $output = Invoke-Command -ScriptBlock {
            if($IsVerbose){
                git checkout --force $ReleaseTag
            }
            else{
                git checkout --force $ReleaseTag 2>&1
            }
        }

        if($IsVerbose){
            $output
        }
        else{
            Write-SoftResult
        }
    }

    Set-Location $initialLocation
}

function Update-GitRepo{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$RepoPath,
        [string]$ReleaseTag,
        [switch]$Reset
    )

    $IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent ? $true : $false

    Write-Subsection "Updating git working copy at $RepoPath"

    if($Reset.IsPresent){
        Reset-GitRepo -RepoPath $RepoPath -Verbose:$IsVerbose
    }

    Write-DoingAction "Pulling latest changes"

    $initialLocation = Get-Location
    Set-Location $RepoPath

    $output = Invoke-Command -ScriptBlock {
        if($IsVerbose){
            git checkout --force master
            git pull
        }
        else{
            git checkout --force master 2>&1
            git pull 2>&1
        }
    }
    
    if($IsVerbose){
        $output
    }
    else{
        Write-Result
    }

    if(![string]::IsNullOrWhiteSpace($ReleaseTag)){
        
        Write-DoingAction "Switching to release tag $ReleaseTag"

        $output = Invoke-Command -ScriptBlock {
            if($IsVerbose){
                git checkout --force $ReleaseTag
            }
            else{
                git checkout --force $ReleaseTag 2>&1
            }
        }

        if($IsVerbose){
            $output
        }
        else{
            Write-SoftResult
        }
    }

    Set-Location $initialLocation
}

function Reset-GitRepo{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$RepoPath
    )

    $IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent

    if(!$IsVerbose){
        Write-DoingAction "Resetting git repo at $RepoPath"
    }

    $output = Invoke-Command -ScriptBlock {
        $initialLocation = Get-Location
        Set-Location $RepoPath
        git reset --hard
        Set-Location $initialLocation
    }

    if($IsVerbose){
        $output
    }
    else{
        Write-Result
    }
}

function Test-IsGitRepoValidOrEmpty{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$BuildDir,
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl
    )

    $repoDir = Get-DefaultDirFromRepoUrl($RepoUrl)
    $repoPath = "$BuildDir/$repoDir"

    $targetRepoUrl = Test-IsGitRepo -RepoPath $repoPath
    if($targetRepoUrl){
        if($targetRepoUrl -eq $RepoUrl){
            return [RepoStatus]::URLMATCH
        }
        
        return [RepoStatus]::URLMISMATCH
    }
    else{
        $dirContent = Get-ChildItem -Path $repoPath -Force -ErrorAction SilentlyContinue
        if($dirContent){
            return [RepoStatus]::NOTEMPTY
        }
        
        return [RepoStatus]::EMPTY
    }
}

function Test-IsGitRepo{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$RepoPath
    )

    if(!(Test-Path $RepoPath)){
        return $false
    }

    $repoUrl = Invoke-Command -ScriptBlock {
        $initialLocation = Get-Location
        Set-Location $RepoPath
        git config --get remote.origin.url
        Set-Location $initialLocation
    }

    return $repoUrl
}

function Get-DefaultDirFromRepoUrl{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl
    )

    return (($RepoUrl -split "/")[-1]).Replace(".git","").Replace("\s","")
}

function Get-GitVersionTag{
    return Invoke-Command -ScriptBlock{
        git describe --tags --long | tail -c 11
    }
}

function Get-GitReleaseInfo{
    
    Param(
        [Parameter(Mandatory=$true)]
        [string]$GitReleaseInfoUrl
    )

	Write-DoingAction "Getting release data from $GitReleaseInfoUrl"
	try {
        $response = Invoke-WebRequest -Uri $GitReleaseInfoUrl
        $releaseInfo = ConvertFrom-Json -InputObject $response.Content
        Write-Result

        return $releaseInfo
	}
	catch {
		Write-ErrorResult -Message $_.Exception.Message -WithPrefix
		
		return $false
    }
}

