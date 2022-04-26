param (
  [Parameter(Mandatory=$true)]
  [string] $username,
  
  [Parameter(Mandatory=$true)]
  [string] $groupName
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

  $user = Get-ADUser -Credential $credentials -Server $domainController -Filter "UserPrincipalName -eq '$userPrincipalName'" -ErrorAction SilentlyContinue
  if(!$user) {
      throw "The user does not exist"   
  }

  $group = Get-ADGroup -Credential $credentials -Server $domainController -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
  if(!$group) {
    throw "The group does not exist or was not found"   
  }
  
  Add-ADGroupMember -Credential $credentials -Identity $group -Members $user -Server $domainController -Confirm $false -PassThru

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
  Write-Output $metadata | ConvertTo-Json
  Write-Output $members | ConvertTo-Json
}