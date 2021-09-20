param (
  [Parameter(Mandatory=$true)]
		[string] $username,
		
	[Parameter(Mandatory=$true)]
		[string] $password,
		
	[Parameter(Mandatory=$true)]
		[string] $firstname,
			
	[Parameter(Mandatory=$true)]
		[string] $lastname
)

# * Environment variabels * #
# Set the below to match your environment #
$domain = "" #Name of the domain to add the user to
$domainController = "" #IP or FQDN of Domain Controller
$path = "" #Path to create the user in. Eg. CN=Users,DC=YourDomain,DC=Internal
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
  $displayname = $firstname + " " + $lastname
  $samAccountName = $username
  $userPrincipalName = $username + "@" + $domain
  $userPassword = ConvertTo-SecureString $password -AsPlainText -Force
  
  $user = New-ADUser -SamAccountName $samAccountName `
  	-UserPrincipalName $userPrincipalName `
  	-DisplayName $displayname `
  	-Givenname $firstname `
  	-Name $displayname `
  	-Surname $lastname `
  	-ChangePasswordAtLogon:$False `
  	-Path $path  `
    -AccountPassword $userPassword `
	-Enabled:$True `
	-Server $domainController `
	-Credential $credentials `
	-PassThru

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)") -Verbose
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds" -Verbose
  Write-Output $metadata | ConvertTo-Json
  Write-Output $user | ConvertTo-Json
}
