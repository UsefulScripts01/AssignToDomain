#Require -RunAsAdmin
##
# Readme
#
# Before use, run Set-ExecutionPolicy Unrestricted then .\PostInstall.ps1
##

#Get user input
$cred = Get-Credential
$computername = Read-Host -Prompt "NAZWA HOSTA"


#Install RSAT for AD Tools
Get-WindowsCapability -Online -name Rsat.ActiveDirectory.DS-LDS.Tools* | Add-WindowsCapability -Online -ErrorAction Continue

#Gather data
$ouPath = 'OU_PATCH'
$server = 'YOUR.DOMAIN.COM'
$coreId = $computername.Split('-')[0]
$asset = (Get-WmiObject win32_systemenclosure | Select-Object SMBIOSAssetTag).SMBIOSAssetTag
$serial = (Get-WmiObject win32_bios | Select-Object SerialNumber).SerialNumber
$model = (Get-CimInstance win32_computersystem | Select-Object Model).Model
try{
    $username = (Get-ADuser -Identity $coreId -Server $server -Credential $cred| Select-Object Name).Name.split('-')[0]
}
catch {
    Write-Host $Error
    Write-Host 'Unable to find CoreID.'
    exit
}
$desc = "${username} - ${asset} - ${serial} - ${model}"

try{
    Get-ADComputer -Identity $computername
}
catch{
    try{
    New-ADComputer -Name $computername -SAMAccountName $computername -Path $ouPath -Description $desc -Server $server -Credential $cred
    }
    catch {
        Write-Host $Error
        Write-Host 'Error while adding host to domain.'
        exit
    }
}
Rename-Computer -NewName $computername

try{
    Add-Computer -DomainName 'DOMAIN.COM' -Credential $cred -Options JoinWithNewName
}
catch {
    Write-Host $Error
    Write-Host 'Errow while joinning domain.'
    exit
}

#Get SID for administrator group and user
$admins = "S-1-5-21-2052111302-287218729-725345543-530340"
$userSID = (Get-ADUser $coreId -Server $server -Credential $cred | Select-Object SID).SID.Value

try{
    Add-LocalGroupMember -SID "S-1-5-32-544" -Member $userSID,$admins
}
catch{
    Write-Host $Error
    Write-Host 'Error while adding groups.'
    exit
}
#Remove RSAT as it's no longer needed.
Remove-WindowsCapability -Name Rsat.ActiveDirectory.DS-LDS.Tools* -Online

Write-Host "RESTART?"
pause
Restart-Computer
