param (
  [Parameter(Mandatory=$true)]
  [string] $userName,
  
  [Parameter(Mandatory=$true)]
  [string] $skuId
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

    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userName'"
    if(!$user) {
        throw "Cannot find user. The user '$userName' does not exist"
    } 
    $usageLocation = $user.UsageLocation;
    if(!$usageLocation){
        throw "Missing usage location for the user '$userName'. You must assign a valid usage location to the user before assigning a license."
    }
    
    $sku = Get-AzureADSubscribedSku | Where-Object SkuId -eq $skuId | Select-Object -ExpandProperty SkuId
    if(!$sku){
        Write-Error "Avaliable SKUs"
        Get-AzureADSubscribedSku | Select-Object Sku* | Write-Error
        throw "Could not find the SKU '$skuId'. The SKU does not exist or is not available to you."
    }

    if($sku -And $user){
        $license = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense 
        $license.SkuId = $sku
        $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses 
        $licenses.AddLicenses = $license 
        Set-AzureADUserLicense -ObjectId $user.ObjectId -AssignedLicenses $licenses
    }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
}