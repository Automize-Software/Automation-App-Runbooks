
param (
    [Parameter(Mandatory=$true)]
        [string] $VMName = "MyVM",
          
    [Parameter(Mandatory=$true)]
        [string] $HostClusterName,
        
    [Parameter(Mandatory=$true)]
        [string] $VCenterServerName,
            
    [Parameter(Mandatory=$true)]
        [string] $DatacenterName,
            
    [Parameter(Mandatory=$true)]
        [string] $DataStoreClusterName,
            
    [Parameter(Mandatory=$true)]
        [string] $CpuCount,

    [Parameter(Mandatory=$true)]
        [string] $RamMB,
        
    [Parameter(Mandatory=$true)]
        [string] $DiskStorageFormat,
    
    [Parameter(Mandatory=$true)]
        [string] $DiskGB,

    [Parameter(Mandatory=$true)]
        [string] $VMWareVMVersion,

    [Parameter(Mandatory=$true)]
        [string] $VMWareGuestID,

    [Parameter(Mandatory=$true)]
        [string] $NetworkName,

    [Parameter(Mandatory=$true)]
        [string] $NetworkAdapterType,

    [Parameter(Mandatory=$true)]
        [string] $SCSIControllerType
  )
  
# * Environment variabels * #
# Set the below to match your environment #
$credentialsName = "" #Name of stored credentials to use for authentication with VMware vCenter


### Script ###
try {
    $metadata = @{
        startTime = Get-Date
    }

    Write-Verbose "Runbook started - $($metadata.startTime)"

    $credentials = Get-AutomationPSCredential -Name $credentialsName

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Add-PSSnapin VMware.VimAutomation.Core

    Connect-VIServer -Server $VCenterServerName -Credential $credentials

    $HostCluster = Get-Cluster -Name HostClusterName
    $DatastoreCluster = Get-DatastoreCluster -Location $DatacenterName -name $DataStoreClusterName

    $NewVMProperties = @{
        Name              = $VMName
        ResourcePool      = $HostCluster
        Datastore         = $DatastoreCluster
        NumCpu            = $CpuCount
        MemoryMB          = $RamMB
        DiskStorageFormat = $DiskStorageFormat
        DiskGB            = $DiskGB
        Version           = $VMWareVMVersion
        GuestId           = $VMWareGuestID
        NetworkName       = $NetworkName
    }

    New-VM @NewVMProperties

    $VmV = Get-VM -Name $VMName | Get-View

    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmConfigSpec.NumCoresPerSocket = $CpuCount
    $vmConfigSpec.MemoryHotAddEnabled = $true
    $vmConfigSpec.CPUHotAddEnabled = $true
    $VmV.reconfigVM($vmConfigSpec)

    Get-VM -Name $VMName | Get-NetworkAdapter | Set-NetworkAdapter -Type $NetworkAdapterType -Confirm:$False
    Get-VM -Name $VMName | Get-ScsiController | Set-ScsiController -Type $SCSIControllerType

    Disconnect-VIServer -Confirm:$false
} catch {
    Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
    throw
} finally {
    Write-Verbose "Runbook has completed. Total runtime $((([DateTime]::Now) - $($metadata.startTime)).TotalSeconds) Seconds"
    Write-Output $out | ConvertTo-Json
}