param (
  [Parameter(Mandatory=$true)]
  [string] $userName
)
 
# * Environment variabels * #
# Set the below to match your environment #
$CertificateName = "" # Name of certificate to use for authentication
$ClientIDVariableName = "" # Name of variable containing the client ID to use to Authenticate with Azure
$TenantVariableName = "" # Variable containing your Microsoft Tentant ID
 
### Script ###
try {    
    if (Get-Module -ListAvailable -Name "AzureAD") {
        Write-Verbose "Found AzureAD module"
    } else {
        throw "Could not find AzureAD module. Please install this module"
    }

    if (Get-Module -ListAvailable -Name "Az.Accounts") {
        Write-Verbose "Found Az.Accounts module"
    } else {
        throw "Could not find Az.Accounts module. Please install this module"
    }

    if (Get-Module -ListAvailable -Name "Az.Resources") {
        Write-Verbose "Found Az.Resources module"
    } else {
        throw "Could not find Az.Resources module. Please install this module"
    }

    if (Get-Module -ListAvailable -Name "Az.Automation") {
        Write-Verbose "Found Az.Automation module"
    } else {
        throw "Could not find Az.Automation module. Please install this module"
    }

    Import-Module Az.Accounts
    Import-Module Az.Resources
    Import-Module Az.Automation
    Import-Module AzureAD

    $cert = Get-AutomationCertificate -Name $CertificateName
    $appId = Get-AutomationVariable -Name $ClientIDVariableName
    $tenantId = Get-AutomationVariable -Name $TenantVariableName
    
    $aadConnect = Connect-AzureAD -TenantId $tenantId -ApplicationId $appId -CertificateThumbprint $cert.Thumbprint -ErrorAction Stop

    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userName'"  | Select-Object -ExpandProperty ObjectId
    if(!$user) {
        throw "Cannot find user. The user '$userName' does not exist"
    } else {
        Write-Verbose "Removing user"
        Remove-AzureADUser -ObjectId $user
        Write-Verbose "User removed"
    }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
}