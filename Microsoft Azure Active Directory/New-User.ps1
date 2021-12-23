param (
  [Parameter(Mandatory=$true)]
  [string] $userName,

  [Parameter(Mandatory=$true)]
  [string] $password,

  [Parameter(Mandatory=$true)]
  [string] $displayName
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
    if($user) {
        throw "Cannot create user. The user '$userName' already exists"
    } else {
        $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
        $PasswordProfile.Password = $password
        $user = New-AzureADUser `
            -DisplayName $displayName `
            -PasswordProfile $PasswordProfile `
            -UserPrincipalName $userName `
            -AccountEnabled $true `
            -MailNickName "Newuser"
    }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
  Write-Output $user | ConvertTo-Json
}