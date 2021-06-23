param (
    [Parameter(Mandatory=$true)]
    [string] $summaryText,
		
    [Parameter(Mandatory=$true)]
    [string] $descriptionText
)

# * Environment variabels * #
# Set the below to match your environment #
$projectKey = "" #Key of the project to which the issue should be added. Ex: AA
$issueTypeId = "" #Id of the issue type. Ex: 10004
$apiURL = "" #API endpoint. Ex: https://automize.atlassian.net/rest/api/3
$credName = "" #Name of API Token login credetinals. Ex: Jira-Admin

### Script ###
try{
    $cred = Get-AutomationPSCredential -Name $credName
    $url = "$apiURL/issue/"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
        ('{0}:{1}' -f $cred.UserName, $cred.GetNetworkCredential().Password)
    )
    $Authorization = 'Basic {0}' -f ([Convert]::ToBase64String($bytes))
    $Headers = @{ 
        'Authorization' = $Authorization
        'Accept' = 'application/json'
        'Content-Type' = 'application/json'
    }
    $project = @{
        'key' = $projectKey
    }
    $issuetype = @{
        'id' = $issueTypeId
    }
    [hashtable]$description = @{}
    $description.version = 1
    $description.type = "doc"
    $description.content = @()
    [hashtable]$content = @{}
    $content.type = "paragraph"
    $content.content= @()
    $paragraph = @{
        'type' = 'text'
        'text' = $descriptionText
    }
    $content.content += $paragraph
    $description.content += $content
    [hashtable]$jiraInput = @{}
    [hashtable]$jiraInput.update = @{
    }
    [hashtable]$jiraInput.fields = @{
        'project' = $project
        'summary' = $summaryText
        'description' = $description
        'issuetype' = $issuetype
    }
    $json = $jiraInput | ConvertTo-Json -Depth 6
    $json = $json -replace '[\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD10-\uDDFF]/g', ''
    $jsonEncoded = [System.Text.Encoding]::UTF8.GetBytes($json)
    $issue = Invoke-WebRequest -Method "POST" -Uri $url -Headers $Headers -Body $jsonEncoded -UseBasicParsing
} catch {
    Write-Output $issue;
    Write-Error -Message $_.Exception
    try {
      if ($PSVersionTable.PSVersion.Major -lt 6) {
        if ($Error.Exception.Response) {  
          $Reader = New-Object System.IO.StreamReader($Error.Exception.Response.GetResponseStream())
          $Reader.BaseStream.Position = 0
          $Reader.DiscardBufferedData()
          $ResponseBody = $Reader.ReadToEnd()
          Write-Output $ResponseBody
        }
      } else  {
        Write-Output $Error.ErrorDetails.Message
      }
    } catch {
      Write-Output "Could not parse output from $url"
    }
    throw $_.Exception
} finally {
    Write-Output $issue.Content
}