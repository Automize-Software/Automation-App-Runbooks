# * Environment variabels * #
# Set the below to match your environment #
$syncServerName = "" #Name of variable that stores the IP or FQDN of Sync Server with Azure AD Connect
$credentialsName = "" #Name of stored credentials to use for authentication with Domain Controller

### Script ###
try {
  $metadata = @{
    startTime = Get-Date
  }
  Write-Verbose "Runbook started - $($metadata.startTime)"
  $syncServer = Get-AutomationVariable -Name $syncServerName
  $credentials = Get-AutomationPSCredential -Name $credentialsName
  Invoke-Command -ComputerName $syncServer -Credential $credentials -ScriptBlock {
    Import-Module ADSync
    Start-ADSyncSyncCycle -PolicyType Delta
  } -ErrorVariable errmsg
  if($errmsg){
    throw $errmsg
  }
} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
} finally {
  Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
}