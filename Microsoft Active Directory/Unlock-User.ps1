param (
  [Parameter(Mandatory=$true)]
	[string] $username
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

  $credentials = Get-AutomationPSCredential -Name $credentialsName
  $userPrincipalName = $username + "@" + $domain

  $user = Get-ADUser -Filter "UserPrincipalName -eq '$userPrincipalName'" -ErrorAction SilentlyContinue
  if(!$user) {
      throw "The user does not exists"   
  }
  
  $user =  Unlock-ADAccount -Credential $credentials -Identity $user -Server $domainController -PassThru $true

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
  Write-Output $metadata | ConvertTo-Json
  Write-Output $user | ConvertTo-Json
}