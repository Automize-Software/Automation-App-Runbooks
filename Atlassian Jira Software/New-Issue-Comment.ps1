param (
    [Parameter(Mandatory=$true)]
		[string] $issueId,
		
    [Parameter(Mandatory=$true)]
        [string] $commentText
)

# * Environment variabels * #
# Set the below to match your environment #
$apiURL = "https://automize.atlassian.net/rest/api/3" #API endpoint. Ex: https://automize.atlassian.net/rest/api/3/
$credName = "" #Name of API Token login credetinals. Ex: Jira-Admin

### Script ###
try{
    $cred = Get-AutomationPSCredential -Name $credName
    $url = "$apiURL/issue/$issueId/comment"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
        ('{0}:{1}' -f $cred.UserName, $cred.GetNetworkCredential().Password)
    )
    $Authorization = 'Basic {0}' -f ([Convert]::ToBase64String($bytes))
    $Headers = @{ 
        'Authorization' = $Authorization
        'Accept' = 'application/json'
        'Content-Type' = 'application/json'
    }
    [hashtable]$comment = @{}
    $comment.version = 1
    $comment.type = "doc"
    $comment.content = @()
    [hashtable]$content = @{}
    $content.type = "paragraph"
    $content.content= @()
    $paragraph = @{
        'type' = 'text'
        'text' = $commentText
    }
    $content.content += $paragraph
    $comment.content += $content
    [hashtable]$jiraInput = @{}
    $jiraInput.body = $comment
    $json = $jiraInput | ConvertTo-Json -Depth 6
    $json = $json -replace '[\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD10-\uDDFF]/g', ''
    $jsonEncoded = [System.Text.Encoding]::UTF8.GetBytes($json)
    $commentResponse = Invoke-RestMethod -Method "POST" -Uri $url -Headers $Headers -Body $jsonEncoded | ConvertTo-Json
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} finally {
    Write-Output $commentResponse
}