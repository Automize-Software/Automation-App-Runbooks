param (
  [Parameter(Mandatory=$true)]
  [string] $userName,
  
  [Parameter(Mandatory=$true)]
  [string] $skuId
)
 
# * Environment variabels * #
# Set the below to match your environment #
$CredentialName = "" # Credentials to use. MFA for the credentials must be disabled
$TenantID = "" # The Microsoft Tentant ID
 
### Script ###
try {
    if (Get-Module -ListAvailable -Name "AzureAD") {
        Write-Verbose "Found AzureAD module"
    } else {
        throw "Could not find AzureAD module. Please install this module"
    }

    $credentials = Get-AutomationPSCredential -Name $CredentialName
    Connect-AzureAD -TenantId $TenantID -Credential $credentials | Out-Null

    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userName'"
    if(!$user) {
        throw "Cannot find user. The user '$userName' does not exist"
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
        $licenses.AddLicenses = @()
        $licenses.RemoveLicenses = $skuId
        Set-AzureADUserLicense -ObjectId $user.ObjectId -AssignedLicenses $licenses
    }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
}