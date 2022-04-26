param (
  [Parameter(Mandatory=$true)]
  [string] $siteName,

  [Parameter(Mandatory=$true)]
  [string] $siteTitle,

  [Parameter(Mandatory=$true)]
  [string] $owner
)

# * Environment variabels * #
# Set the below to match your environment #
$clientIdVariable = "" #Name of variable containing the client id to use for authentication
$certificateVariable = "" #Name of variable containing the pfx certificate in base64 format to use for authentication
$certificatePWVariable = "" #Name of variable containt the password for the pfx certificate
$tenantNameVariable = "" #Name of variable containing your tenant name. Eg. "automize.onmicrosoft.com"
$sharePointURLVariable = "" #Name of varialbe containyour your base sharepoint URL. Eg. "https://automize.sharepoint.com"

### Script ###
$ErrorActionPreference = "Stop"
try {
    Import-Module PnP.PowerShell
} catch {
    Write-Warning "Could not find PnP.PowerShell module. Trying to install it."
    try {
        Install-Module -Name PnP.PowerShell -AllowClobber -Force
    } catch {
        Write-Error "Runbook failed. Please install the PnP.PowerShell module before executing this Runbook."
        throw
    }
}

try {
  $metadata = @{
    startTime = Get-Date
    siteName = $siteName
    siteTitle = $siteTitle
  }
  
  Write-Verbose "Runbook started - $($metadata.startTime)"

  $clientId = Get-AutomationVariable -Name $clientIdVariable
  $encodedPfx = Get-AutomationVariable -Name $certificateVariable
  $certificatePWString = Get-AutomationVariable -Name $certificatePWVariable
  $certificatePW = ConvertTo-SecureString -String $certificatePWString -Force -AsPlainText 
  $tenant = Get-AutomationVariable -Name $tenantNameVariable
  $sharePointUrl = Get-AutomationVariable -Name $sharePointURLVariable
  $teamSiteUrl = "$sharePointUrl/sites/$siteName";
  
  Write-Verbose "Creating new site with URL $teamSiteUrl"

  Connect-PnPOnline -Url $sharePointUrl -ClientId $clientId -Tenant $tenant -CertificateBase64Encoded $encodedPfx -CertificatePassword $certificatePW 

  $newsite = New-PnPSite -Type CommunicationSite -Title "TEST" -Url $teamSiteUrl -Lcid 1033 -Owner $owner -Wait

  Write-Verbose "New site successfully created at $newsite"

  Disconnect-PnPOnline
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
  Write-Output $metadata | ConvertTo-Json
}