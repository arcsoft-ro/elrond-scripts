#!/usr/bin/pwsh

Param(
    [string]$NodeIndex="0",
    [string]$UtilsDir
)

# Import modules
$requiredModules = "ErdCore","ErdIO","ErdUtils","ErdGit","ErdNode","ErdSystem"
foreach($requiredModule in $requiredModules){
    Import-Module "$PSScriptRoot/.modules/$requiredModule/$requiredModule.psd1" -Force
}

$userConfig = Get-ConfigValues -ConfigFile "$PSScriptRoot/config/user-config.json"
Add-StringValueToObject -ObjectRef ([ref]$userConfig) -MemberName UtilsDir -Value $UtilsDir
Test-MandatoryArgument -ArgumentName "UtilsDir" -ArgumentValue $userConfig.UtilsDir

Start-Termui -UtilsDir $userConfig.UtilsDir -NodeIndex $NodeIndex