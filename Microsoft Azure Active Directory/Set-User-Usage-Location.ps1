param (
  [Parameter(Mandatory=$true)]
  [string] $userName,
  
  [Parameter(Mandatory=$true)]
  [string] $usageLocation
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

    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userName'" | Select-Object -ExpandProperty ObjectId
    if(!$user) {
        throw "Cannot find user. The user '$userName' does not exist"
    } 

    Set-AzureADUser -ObjectId $user -UsageLocation $usageLocation

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
}