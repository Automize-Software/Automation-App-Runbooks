
param (
    [Parameter(Mandatory=$true)]
        [string] $VMName = "MyVM",
        
    [Parameter(Mandatory=$true)]
        [string] $VCenterServerName
  )
  
# * Environment variabels * #
# Set the below to match your environment #
$credentials = "" #Name of stored credentials to use for authentication with VMware vCenter


### Script ###
try {
    $metadata = @{
        startTime = Get-Date
    }

    $psSnapIn = "VMware.VimAutomation.Core"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Verbose "Adding PSSnapin $psSnapIn"
    Add-PSSnapin $psSnapIn

    Write-Verbose "Connecting to server $VCenterServerName as user $($credentials.UserName)" 
    Connect-VIServer -Server $VCenterServerName -Credential $credentials > $null

    $vm = Get-VM -Name $VMName
    
    Remove-VM -VM $vm -Confirm:$false -DeletePermanently

    Disconnect-VIServer -Confirm:$false
} catch {
    Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
    throw
} finally {
    Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
    Write-Output $out | ConvertTo-Json
}