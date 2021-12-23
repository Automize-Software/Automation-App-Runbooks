param (
  [Parameter(Mandatory=$true)]
  [string] $groupName
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

    $group = Get-AzureADGroup -Filter "DisplayName eq '$groupName'" | Select-Object -ExpandProperty ObjectId
    if(!$group) {
        throw "Cannot remove group. The group '$groupName' does not exists"
    } else {
        Write-Verbose "Removing group $groupName"
        $group = Remove-AzureADGroup -ObjectId $group
    }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
}