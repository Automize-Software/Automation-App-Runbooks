Param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$PipelineId,

    [Parameter(Mandatory = $true)]
    [string]$BranchName,

    [Parameter(Mandatory = $true)]
    [hashtable]$Parameters
)

Begin {
    function Get-DevOpsHeader {
        param (
            [Parameter(Mandatory = $true)]
            [string]$PAT
        )
    
        Process {
            $ErrorActionPreference = "Stop"
            try {
                $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PAT)"))
                $Header = @{Authorization = ("Basic {0}" -f $base64AuthInfo) }
            }
            catch {
                throw $_
            }
        }
        End {
            Write-Output $Header
        }
    }
    function Get-PipelineRun {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Organization,
    
            [Parameter(Mandatory = $true)]
            [string]$Project,
    
            [Parameter(Mandatory = $true)]
            [string]$PipelineId,
            
            [Parameter(Mandatory = $true)]
            [string]$RunId,
    
            [Parameter(Mandatory = $true)]
            [hashtable]$Headers
        )
    
        Process {
            try {
                $ErrorActionPreference = "Stop"
        
                $Params = @{
                    Uri         = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$PipelineId/runs/$($RunId)?api-version=7.1"
                    Method      = "GET"
                    ContentType = "application/json"
                    Headers     = $Headers
                }
        
                $Output = Invoke-RestMethod @Params
            }
            catch {
                throw $_
            }
        }
        End {
            Write-Output $Output
        }
        
    }
    function Start-PipelineRun {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Organization,
    
            [Parameter(Mandatory = $true)]
            [string]$Project,
    
            [Parameter(Mandatory = $true)]
            [string]$PipelineId,
    
            [Parameter(Mandatory = $true)]
            [string]$BranchName,
    
            [Parameter(Mandatory = $true)]
            [hashtable]$Parameters,
    
            [Parameter(Mandatory = $true)]
            [hashtable]$Headers
        )
    
        Process {
            try {
                $ErrorActionPreference = "Stop"
        
                $Body = @{
                    stagesToSkip = @{}
                    resources    = @{
                        repositories = @{
                            self = @{
                                refName = "refs/heads/$BranchName"
                            }
                        }
                    }
                    variables    = @{}
                }
    
                if ($Parameters) {
                    $Body.Add("templateParameters", $Parameters)
                }
                
                $Params = @{
                    Uri         = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$($PipelineId)/runs?api-version=7.1"
                    Method      = "POST"
                    ContentType = "application/json"
                    Headers     = $Headers
                    Body        = $Body | ConvertTo-Json -Depth 10
                }
        
                $Output = Invoke-RestMethod @Params
        
            }
            catch {
                throw ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber) `n$($_.Exception.Message)")
            }   
        }
        End {
            Write-Output $Output
        }
    }
}
Process {
    $ErrorActionPreference = "Stop"
    try {

        # Get DevOps Header
        $Credential = Get-AutomationPSCredential -Name 'DevOpsToken'
        $Header = Get-DevOpsHeader -PAT $Credential.GetNetworkCredential().Password

        # Start Pipeline
        $StartPipelineRun = Start-Pipeline -Organization $Organization -Project $Project -PipelineId $PipelineId -BranchName $BranchName -Parameters $Parameters -Headers $Header
        while (!($PipelineRun.result -in @("succeeded", "failed"))) {
            $PipelineRun = Get-PipelineRun -Organization $Organization -Project $Project -PipelineId $PipelineId -RunId $StartPipelineRun.id -Headers $Header
            Start-Sleep -Seconds 2
        }
    }
    catch {
        throw ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber) `n$($_.Exception.Message)")
    }
}
End {
    Write-Output ($PipelineRun | ConvertTo-Json -Depth 10)
}