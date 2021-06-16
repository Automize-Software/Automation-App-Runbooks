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
        If (! (Test-Path "$($Using:SiteCode):")) {
            Try{
                New-PSDrive -Name $Using:SiteCode -PSProvider CMSite -Root "." -WhatIf:$False | Out-Null
            } Catch {
                Return
            }
        }

        Push-Location "$Using:SiteCode`:"

        Add-CMDeviceCollectionDirectMembershipRule -ResourceId $Using:ResourceID -CollectionId $Using:CollectionID
                
        $currentRetry = 0
        $retryCount   = 30

        for (;;) {
            try {
                $member = Get-CMDeviceCollectionDirectMembershipRule -ResourceId $Using:ResourceID -CollectionId $Using:CollectionID

                if ($member) {
                    break
                }
                        
                throw ("Could not verify the device {0} in collection {1}" -f $Using:ResourceID,$Using:CollectionID)
            }
            catch {
                $currentRetry++

                if ($currentRetry -gt $retryCount) {
                    throw
                }

                Start-Sleep -Seconds 10
            }
        }

        @{value=$($member)}
    }

    $cmd = Invoke-Command -ComputerName $SiteServer -ScriptBlock $ScriptBlock -Credential $cred -ErrorAction Stop

    Write-Output $cmd.value | ConvertTo-Json  
    
    Write-Verbose ("Successfully added {0} to collection {1}" -f $ResourceId, $CollectionId)
} catch {
    Write-Error ("Exception caught at line {0}, {1}" -f $($_.InvocationInfo.ScriptLineNumber),$($_.Exception.Message))
    throw
}