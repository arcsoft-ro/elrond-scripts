#
# ErdCore Powershell Module
#

function Write-Section{

	Param(
		[switch]$NoNewline
	)

	$currentTime = Get-Date -Format "HH:mm:ss"
	$hostname = hostname
	$message = "`n###`n### $args - $hostname - $currentTime `n###"
	
	if(!$NoNewline.IsPresent){
		$message = $message + "`n"
	}
	Write-Host $message  -ForegroundColor Cyan
}

function Write-Subsection{

	Param(
		[switch]$Warn
	)

	if($Warn.IsPresent){
		Write-Host "`n### WARNING! ### " -NoNewline -ForegroundColor Yellow
		Write-Host $args -ForegroundColor Cyan
	}
	else{
		Write-Host "`n### $args`:" -ForegroundColor Cyan
	}
}

function Write-OkResult{
	
	Param(
		[string]$Message = "OK!",
		[switch]$WithPrefix
	)

	if($WithPrefix.IsPresent){
		Write-Host "OK! " -ForegroundColor Green -NoNewline
		Write-Host $Message
	}
	else{
		Write-Host $Message -ForegroundColor Green
	}
}

function Write-WarningResult{
	
	Param(
		[string]$Message = "WARNING!",
		[switch]$WithPrefix
	)
	
	if($WithPrefix.IsPresent){
		Write-Host "WARNING! " -ForegroundColor Yellow -NoNewline
		Write-Host $Message
	}
	else{
		Write-Host $Message -ForegroundColor Yellow
	}
}

function Write-ErrorResult{
	
	Param(
		[string]$Message = "ERROR!",
		[switch]$WithPrefix
	)

	if($WithPrefix.IsPresent){
		Write-Host "ERROR! " -ForegroundColor Red -NoNewline
		Write-Host $Message
	}
	else{
		Write-Host $Message -ForegroundColor Red
	}
}

function Write-Result{

    if($?){
        Write-OkResult
    }
    else{
        Write-ErrorResult
    }
}

function Write-SoftResult{

    if($?){
        Write-OkResult
    }
    else{
        Write-WarningResult
    }
}

function Out-Result{

	$returnValue = $?

	if($returnValue){
        Write-OkResult
    }
    else{
        Write-ErrorResult
    }

	return $returnValue
}

function Out-SoftResult{
	
	$returnValue = $?

	if($returnValue){
        Write-OkResult
    }
    else{
        Write-WarningResult
    }

	return $returnValue
}

function Write-Aligned{

	Param(
		[string]$Key,
		[string]$Value,
		[int]$SpaceSize = 30,
		[string]$ForegroundColor
	)

	$requiredSpaces = $SpaceSize - $Key.Length
	Write-Host ($Key + ":" + (" " * $requiredSpaces)) -NoNewline
	if([string]::IsNullOrWhiteSpace($ForegroundColor)){
		$ForegroundColor = "Yellow"
	}
	Write-Host $Value -ForegroundColor $ForegroundColor
}

function Write-DoingAction{
	Write-Host "$args -> " -NoNewline
}

function Get-ContinueApproval{

	Param(
		[string]$Message,
		[ValidateSet("Break","Exit")]
		[string]$Action = "Exit",
		[switch]$Warn
	)

	if(!([string]::IsNullOrEmpty($Message))){
		if($Warn.IsPresent){
			Write-Host "`n### WARNING! ### " -NoNewline -ForegroundColor Yellow
			Write-Host $Message -ForegroundColor Cyan
		}
		else{
			Write-Host "`n$Message" -ForegroundColor Cyan
		}
	}

	Write-Host `nPress `'Y`' to continue or any other key to cancel...
	$keyPressed = [System.Console]::ReadKey()
	if($keyPressed.Key -ne "y" -and $keyPressed.Key -ne "Y"){
		if($Action -eq "Exit"){
			Write-Host `nAborted! Press any key to exit...`n -ForegroundColor Red
			$keyPressed = [System.Console]::ReadKey()
			
			exit
		}
		else{
			Write-Host `nAborted! Breaking from iteration...`n -ForegroundColor Red
			break
		}
	}
	else{
		Write-Host `n
	}
}

function Add-StringValueToObject{

	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef,
		[Parameter(Mandatory=$true)]
		[string]$MemberName,
		[string]$Value
	)

	if(!$ObjectRef.Value){
		return
	}

	if(![string]::IsNullOrWhiteSpace($Value)){
		if($ObjectRef.Value.PSobject.Properties.Name -Match $MemberName){
			$ObjectRef.Value.$MemberName = $Value
		}
		else{
			$ObjectRef.Value | Add-Member -NotePropertyName $MemberName -NotePropertyValue $Value
		}
	}
}

function Add-ValueToObject{

	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef,
		[Parameter(Mandatory=$true)]
		[string]$MemberName,
		[object]$Value
	)

	if(!$ObjectRef.Value){
		return
	}

	if($ObjectRef.Value.PSobject.Properties.Name -Match $MemberName){
		$ObjectRef.Value.$MemberName = $Value
	}
	else{
		$ObjectRef.Value | Add-Member -NotePropertyName $MemberName -NotePropertyValue $Value
	}
}

function Write-ObjectMembers{

	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef
	)

	if(!$ObjectRef.Value){
		return
	}

	foreach($member in Get-Member -InputObject $ObjectRef.Value -MemberType NoteProperty){
		$memberName = $member.Name
		Write-Aligned -Key $memberName -Value $ObjectRef.Value.$memberName
	}
}

function Write-Hash{

	Param(
		[Parameter(Mandatory=$true)]
		[ref]$ObjectRef,
		[string]$ForegroundColor = "Yellow"
	)

	if(!$ObjectRef.Value){
		return
	}

	foreach($key in $ObjectRef.Value.Keys){
		$itemValue = $ObjectRef.Value[$key]
		if($key -eq "ProcessId"){
			if($itemValue -match "^\d{1,9}"){
				$computedColor = "Green"
			}
			else{
				$computedColor = "Red"
			}
		}
		elseif($key -eq "ValidKey"){
			if($itemValue -eq "Yes"){
				$computedColor = "Green"
			}
			else{
				$computedColor = "Red"
			}
		}
		else{
			$computedColor = $ForegroundColor
		}
		Write-Aligned -Key $key -Value $itemValue -ForegroundColor $computedColor
	}
}

function Get-RandomString{

	Param(
		[int]$Count = 10
	)

	return -join ((65..90) + (97..122) | Get-Random -Count $Count | ForEach-Object {[char]$_})
}

function Get-ElrondBuildDir{
	return "$env:HOME/go/src/github.com/ElrondNetwork"
}

function Get-ElrondRootBuildDir{
	return "$env:HOME/go"
}
