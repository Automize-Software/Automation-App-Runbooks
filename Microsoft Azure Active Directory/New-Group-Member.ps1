param (
  [Parameter(Mandatory=$true)]
  [string] $userName,

  [Parameter(Mandatory=$true)]
  [string] $groupName
)
 
# * Environment variabels * #
# Set the below to match your environment #
$CredentialName = "" # Credentials to use. MFA for the credentials must be disabled
$TenantID = "" # The Microsoft Tentant ID
 
### Script ###
try {
    $output = @{}

    if (Get-Module -ListAvailable -Name "AzureAD") {
        Write-Verbose "Found AzureAD module"
    } else {
        throw "Could not find AzureAD module. Please install this module"
    }

    $credentials = Get-AutomationPSCredential -Name $CredentialName
    Connect-AzureAD -TenantId $TenantID -Credential $credentials | Out-Null

    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userName'"  | Select-Object -ExpandProperty ObjectId
    if(!$user) {
        throw "Cannot find user. The user '$userName' does not exist"
    }
    $output.user = $user
    
    $group = Get-AzureADGroup -Filter "DisplayName eq '$groupName'" | Select-Object -ExpandProperty ObjectId 
    if(!$group) {
        throw "Cannot find group. The user '$groupName' does not exist"
    }
    $output.group = $group

    $groups = New-Object Microsoft.Open.AzureAD.Model.GroupIdsForMembershipCheck
    $groups.GroupIds = $group
    $groupMember = Select-AzureADGroupIdsUserIsMemberOf -ObjectId $user -GroupIdsForMembershipCheck $groups

    if($groupMember) {
        Write-Output "The user '$username' is already a member of the group '$groupName'. Nothing to do."
    } else {
        $groupMember = Add-AzureADGroupMember -ObjectID $group -RefObjectId $user
    } 
    $output.groupMember = $groupMember
  
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed."
  Write-Output $output | ConvertTo-Json
}