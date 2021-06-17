param (
  [Parameter(Mandatory=$true)]
	[string] $username,
  [Parameter(Mandatory=$true)]
    [string] $password,
  [Parameter(Mandatory=$true)]
	[boolean] $changePasswordAtLogon = $false
)

# * Environment variabels * #
# Set the below to match your environment #
$domain = "" #Name of the domain to add the user to
$domainController = "" #IP or FQDN of Domain Controller
$credentialsName = "" #Name of stored credentials to use for authentication with Domain Controller

### Script ###
try {
  $metadata = @{
    startTime = Get-Date
    username = $username
    domain = $domain
  }
  
  Write-Verbose "Runbook started - $($metadata.startTime)"

  if (Get-Module -ListAvailable -Name "ActiveDirectory") {
    Write-Verbose "Found ActiveDirectory module"
  } else {
    Write-Verbose "Did not find Active Directory module. Trying to install the RSAT-AD-PowerShell Windows Feature"
    Install-WindowsFeature RSAT-AD-PowerShell
  }

  $credentials = Get-AutomationPSCredential -Name $credentialsName
  $userPrincipalName = $username + "@" + $domain
  $userPassword = ConvertTo-SecureString $password -AsPlainText -Force

  $user = Get-ADUser -Filter "UserPrincipalName -eq '$userPrincipalName'" -ErrorAction SilentlyContinue
  if(!$user) {
      throw "The user does not exists"   
  }
  
  $user = Set-ADAccountPassword -Credential $credentials -Identity $user -NewPassword $userPassword -Server $domainController -Reset -PassThru $true

  if($changePasswordAtLogon -eq $true){
    $user = Set-ADUser -Credential $credentials -Identity $user -ChangePasswordAtLogon $true -Server $domainController -PassThru $true
  }

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
  Write-Output $metadata | ConvertTo-Json
  Write-Output $user | ConvertTo-Json
}