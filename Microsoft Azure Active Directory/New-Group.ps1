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

    $group = Get-AzureADGroup -Filter "DisplayName eq '$groupName'"
    if($group) {
        throw "Cannot create group. The group '$groupName' already exists"
    } else {
        Write-Verbose "Creating new group $groupName"
        $group = New-AzureADGroup `
            -DisplayName "$groupName" `
            -MailEnabled $false `
            -SecurityEnabled $true `
            -MailNickName "NotSet" 
    }
 
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
  Write-Output $group | ConvertTo-Json
}