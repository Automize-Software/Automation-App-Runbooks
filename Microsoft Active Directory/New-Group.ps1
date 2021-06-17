param (        
  [Parameter(Mandatory=$true)]
	[string] $samAccountName,
		
  [Parameter(Mandatory=$true)]
    [string] $description = "",
    
  [Parameter(Mandatory=$false)]
    [string] $name,

  [Parameter(Mandatory=$false)]
    [string] $displayname
)

# * Environment variabels * #
# Set the below to match your environment #
$domain = "" #Name of the domain to add the user to
$domainController = "" #IP or FQDN of Domain Controller
$groupScope = "Universal" #Set the scope of the group to be created
$path = "" #Path to create group in. Eg. CN=Groups,DC=YourDomain,DC=Internal
$credentialName = "" #Name of stored credentials to use for authentication with Domain Controller


### Script ###
try {
  $cred = Get-AutomationPSCredential -Name $CredentialName
  $metadata = @{
    startTime = Get-Date
    samAccountName = $samAccountName
    domain = $domain
  }
  
  Write-Verbose "Runbook started - $($metadata.startTime)"

  if (Get-Module -ListAvailable -Name "ActiveDirectory") {
    Write-Verbose "Found ActiveDirectory module"
  } else {
    Write-Verbose "Did not find Active Directory module. Trying to install the RSAT-AD-PowerShell Windows Feature"
    Install-WindowsFeature RSAT-AD-PowerShell
  }

  if($name -eq $null) {
    $name = $samAccountName
  }

  if($displayname -eq $null) {
    $displayname = $name;
  }

  $group = New-ADGroup -SamAccountName $samAccountName `
  	-Name $name `
    -DisplayName $displayname `
    -Description $description `
    -Path $path `
    -GroupScope $groupScope `
	  -Server $domainController `
    -Credential $cred `
    -PassThru

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
  Write-Output $metadata | ConvertTo-Json
  Write-Output $group | ConvertTo-Json
}