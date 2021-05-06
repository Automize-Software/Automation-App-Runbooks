param(
  [Parameter(Mandatory=$true)]
  [string] $username
)

#Environment variables
$serverCredName = "" #Name of Crendential to be used for authenticated with Microsoft Exchange server.
$exchangeServerVarName = "" #Name of variable containing the Microsoft Exchange server name.

#Script
$cred = Get-AutomationPSCredential -Name $serverCredName 
$exchangeServerName = Get-AutomationVariable -Name $exchangeServerVarName
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$exchangeServerName/powershell -Credential $cred 

Write-Debug "Import Exchange remote session"
$importsession = Import-PSSession $session -AllowClobber

$ErrorActionPreference = "Stop"
$ADUser = Get-ADUser -Properties "msExchMailboxGuid" -Filter "sAMAccountName -eq '$username'" -ErrorAction SilentlyContinue

if($ADUser) {
    Write-Debug "User exist"
    if($null -eq $ADUser.msExchMailboxGuid) {
        Write-Warning "Mailbox could not be removed as it does not exist"
    } else {
        Write-Debug 'Removing mailbox'
        Disable-Mailbox -Identity $username -Confirm:$false 
    }
    Write-Output $mailbox
} else {
    Remove-PSSession $session
    Throw "The user does not exists"
}
Remove-PSSession $session