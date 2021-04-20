param (
    [Parameter(Mandatory=$true)]
    [int] $workItemId,
    
    [Parameter(Mandatory=$true)]
    [string] $comment,
		
    [Parameter(Mandatory=$true)]
    [string] $requester
)

# * Environment variabels * #
# Set the below to match your environment #
$tokenName = "" # Name of variable containing personal access token
$organizationName = "" # Name of organization. Ex. automizedk
$projectName = "" # Name of project to add work-item to.

# Script
try {
  $pacToken = Get-AutomationVariable -Name $tokenName
  $adoHeader = @{
    'Authorization' = ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$pacToken))))
    'Accept' = 'application/json'
    'Content-Type' = 'application/json'
  }
  $adoTaskUri = "https://dev.azure.com/$organizationName/$projectName/_apis/wit/workitems/$workItemId/comments?api-version=6.0-preview.3"
  Write-Verbose $adoTaskUri

  $ADOInput = @()
  [hashtable]$commentObj = @{}
  $commentObj.text = "From: ServiceNow<br>Added by: $requester<br>Comment: $comment"
  $ADOInput += $commentObj
  $json = $ADOInput | ConvertTo-Json -Depth 6
  $json = $json -replace '[\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD10-\uDDFF]/g', ''
  $task = Invoke-RestMethod -Uri $adoTaskUri -Body $json -headers $adoHeader -Method "POST"
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} finally {
    Write-Output $task | ConvertTo-Json -Depth 6
}