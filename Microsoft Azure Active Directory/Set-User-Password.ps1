param (
  [Parameter(Mandatory=$true)]
  [string] $userName,
  
  [Parameter(Mandatory=$true)]
  [string] $password,
  
  [Parameter(Mandatory=$true)]
  [boolean] $changePasswordAtLogon = $false
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

    $userPassword = ConvertTo-SecureString $password -AsPlainText -Force

    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userName'" | Select-Object -ExpandProperty ObjectId
    if(!$user) {
        throw "Cannot find user. The user '$userName' does not exist"
    } else {
        Write-Verbose "Changing password"
        Set-AzureADUserPassword `
            -ObjectId $user `
            -Password $userPassword `
            -ForceChangePasswordNextLogin $changePasswordAtLogon
        Write-Verbose "Password changed"
    }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
}