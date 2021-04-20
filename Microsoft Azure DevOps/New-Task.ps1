param (
    [Parameter(Mandatory=$true)]
    [string] $title,
		
    [Parameter(Mandatory=$true)]
    [string] $description,
    
    [Parameter(Mandatory=$true)]
    [string] $requester,
    
    [Parameter(Mandatory=$true)]
    [int] $priority,
    
    [Parameter(Mandatory=$true)]
    [string] $category,
    
    [Parameter(Mandatory=$true)]
    [string] $subCategory
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
    'Content-Type' = 'application/json-patch+json'
  }
  $adoTaskUri = "https://dev.azure.com/$organizationName/$projectName/_apis/wit/workitems/`$Task?api-version=6.0"
  Write-Verbose $adoTaskUri
  
  $ADOInput = @()
  
  [hashtable]$titleObj = @{}
  $titleObj.op = "add"
  $titleObj.path = "/fields/System.Title"
  $titleObj.value = $title
  $ADOInput += $titleObj
  
  [hashtable]$descObj = @{}
  $descObj.op = "add"
  $descObj.path = "/fields/System.Description"
  $descObj.value = "Opened by: $requester<br>Description: $description"
  $ADOInput += $descObj

  [hashtable]$priorityObj = @{}
  $priorityObj.op = "add"
  $priorityObj.path = "/fields/Microsoft.VSTS.Common.Priority"
  $priorityObj.value = $priority
  $ADOInput += $priorityObj
  
  [hashtable]$tagObj = @{}
  $tagObj.op = "add"
  $tagObj.path = "/fields/System.Tags"
  $tagObj.value = "$category;$subCategory"
  $ADOInput += $tagObj
  
  $json = $ADOInput | ConvertTo-Json -Depth 6
  $json = $json -replace '[\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD10-\uDDFF]/g', ''
  Write-Verbose $json

  $task = Invoke-RestMethod -Uri $adoTaskUri -Body $json -headers $adoHeader -Method "POST"
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} finally {
    Write-Output $task | ConvertTo-Json -Depth 6
    Write-Output $task.fields | ConvertTo-Json -Depth 6
}