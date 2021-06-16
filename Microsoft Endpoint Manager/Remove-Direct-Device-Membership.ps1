param(
    [Parameter(Mandatory=$true)]
    [string] $CollectionID,
		
    [Parameter(Mandatory=$true)]
    [string] $ResourceID
)

# * Environment variabels * #
# Set the below to match your environment #
$SiteServer = "" # Name of the SCCM / Endpoint Manager server
$SiteCode = "" # Sitecode of the SCCM / Endpoint Manager installation, Ex. PS1
$CredentialName = "" # Name of credentials to use for authentication

### Script ###
$ErrorActionPreference = "Stop"
try{
    $Cred = Get-AutomationPSCredential -Name $CredentialName

    $ScriptBlock  = { 
        Import-Module (Join-Path $(split-path $Env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
                
        #If the PS drive doesn't exist then try to create it.
        if(! (Test-Path "$($Using:SiteCode):")) {
            try{
                New-PSDrive -Name $Using:SiteCode -PSProvider CMSite -Root "." -WhatIf:$False | Out-Null
            } catch {
                return
            }
        }

        Push-Location "$Using:SiteCode`:"

        $Membership = (Get-CMCollectionMember -ResourceId $Using:ResourceID -CollectionId $Using:CollectionID | Select-Object ResourceId, Name, IsDirect)

            if($Membership.IsDirect -eq $true) {
            Remove-CMDeviceCollectionDirectMembershipRule -ResourceId $Using:ResourceID -CollectionId $Using:CollectionID -Force
                
            $currentRetry = 0
            $retryCount   = 30

            for (;;) {
                try {
                    $member = Get-CMDeviceCollectionDirectMembershipRule -ResourceId $Using:ResourceID -CollectionId $Using:CollectionID

                    if (-not $member) {
                        break
                    }
                            
                    throw ("Device {0} was not removed from collection {1}" -f $Using:ResourceID,$Using:CollectionID)
                }
                catch {
                    $currentRetry++

                    if ($currentRetry -gt $retryCount) {
                        throw
                    }

                    Start-Sleep -Seconds 10
                }
            }

            Write-Output @{value = "Device successfully removed from collection"}
        }
        elseif($Membership.IsDirect -eq $false) {
            throw ("Device {0} is not a direct member of collection {1}"-f $Using:ResourceId, $Using:CollectionId)
        }
        else {
            Write-Output @{value = ("Device {0} was not a member of collection {1}" -f $Using:ResourceId, $Using:CollectionId)}
        }
    }

    $cmd = Invoke-Command -ComputerName $SiteServer -ScriptBlock $ScriptBlock -Credential $cred -ErrorAction Stop

    Write-Output $cmd.value
    
    Write-Verbose ("Successfully removed {0} to collection {1}" -f $ResourceId, $CollectionId) 

} catch {
    Write-Error ("Exception caught at line {0}, {1}" -f $($_.InvocationInfo.ScriptLineNumber),$($_.Exception.Message))
    throw
}