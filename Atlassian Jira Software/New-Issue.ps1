param (
    [Parameter(Mandatory=$true)]
    [string] $summaryText,
		
    [Parameter(Mandatory=$true)]
    [string] $descriptionText
)

# * Environment variabels * #
# Set the below to match your environment #
$reporterName = "" #Name of the user that should be set as the reporter on the issue in Jira
$projectKey = "" #Key of the project to which the issue should be added. Ex: AA
$issueTypeId = "" #Id of the issue type. Ex: 10004
$apiURL = "" #API endpoint. Ex: https://automize.atlassian.net/rest/api/3/
$credName = "" #Name of API Token login credetinals. Ex: Jira-Admin

### Script ###
try{
    $cred = Get-AutomationPSCredential -Name $credName
    $url = $apiURL
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
    $reporter = @{
        'name' = $reporterName
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
        'reporter' = $reporter
    }
    $json = $jiraInput | ConvertTo-Json -Depth 6
    $json = $json -replace '[\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD10-\uDDFF]/g', ''
    $jsonEncoded = [System.Text.Encoding]::UTF8.GetBytes($json)
    $issue = Invoke-RestMethod -Method "POST" -Uri $url -Headers $Headers -Body $jsonEncoded | ConvertTo-Json
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} finally {
    Write-Output $issue
}