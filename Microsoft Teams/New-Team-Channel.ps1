param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$GroupId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ChannelName
)

#Environment variables
$CredentialName = "" # Credentials to use. MFA for the credentials must be disabled
$TenantID = "" # The Microsoft Tentant ID where Teams is enabled

#Script
$ErrorActionPreference = "Stop"
try {
    Import-Module MicrosoftTeams
} catch {
    Write-Warning "Could not find MicrosoftTeams module. Trying to install it."
    try {
        Install-Module MicrosoftTeams -Force -AllowClobber
    } catch {
        Write-Error "Runbook failed. Please install the MicrosoftTeams module before executing this Runbook."
        throw
    }
}

try {
    $cred = Get-AutomationPSCredential -Name $CredentialName 
    Connect-MicrosoftTeams -TenantId $TenantID -Credential $cred
    $params = @{}
    $params.GroupId = $GroupId
    $params.DisplayName = $ChannelName
    
    $channel = New-TeamChannel @params | ConvertTo-Json
    Write-Output $channel
} catch {
    Write-Error ("Exception caught at line {0}, {1}" -f $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message))
    Write-Output $_.TargetObject.Error
    throw
}