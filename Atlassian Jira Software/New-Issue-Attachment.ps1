param (
    [Parameter(Mandatory=$true)]
	[string] $issueId,
		
    [Parameter(Mandatory=$true)]
    [string] $attachmentSysId,
    
    [Parameter(Mandatory=$true)]
    [string] $filename
)

# * Environment variabels * #
# Set the below to match your environment #
$apiURL = "" #API endpoint. Ex: https://automize.atlassian.net/rest/api/3/
$credName = "" #Name of API Token login credetinals to authenticate with Jira. Ex: Jira-Admin
$ServiceNowInstanceName = "" #Name of the ServiceNow instance that instance should be imported to
$serviceNowCredentialName = "" #Name of Credentials to authenticate with ServiceNow

### Script ###
try{
    New-Item "temp\$filename" -Force > $null
    $documentPath = [System.IO.Path]::Combine($PSScriptRoot, "temp\$filename") | Resolve-Path
    
    $ServiceNowCredential = Get-AutomationPSCredential -Name $serviceNowCredentialName
    $ServiceNowAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ServiceNowCredential.UserName, $ServiceNowCredential.GetNetworkCredential().Password)))
    $ServiceNowHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $ServiceNowHeaders.Add('Authorization',('Basic {0}' -f $ServiceNowAuthInfo))
    $ServiceNowHeaders.Add('Accept','*/*')

    Write-Verbose "ServiceNowHeaders: $ServiceNowHeaders"
    Write-Verbose "DocumentPath: $documentPath"
    
    $uri = "https://$ServiceNowInstanceName.service-now.com/api/now/attachment/$attachmentSysId/file"
    Write-Verbose "SNOW-Uri: $uri"
    $method = "get"
    Invoke-RestMethod -Headers $ServiceNowHeaders -Method $method -Uri $uri -OutFile $documentPath
    
    $attachmentBase64 = New-TemporaryFile
    [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($documentPath)) > $attachmentBase64
  
    $cred = Get-AutomationPSCredential -Name $credName
    $url = "$apiURL/issue/$issueId/attachments"
    Write-Verbose "JIRA-Uri: $url"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
        ('{0}:{1}' -f $cred.UserName, $cred.GetNetworkCredential().Password)
    )
    $Authorization = 'Basic {0}' -f ([Convert]::ToBase64String($bytes))
    
    $wc = new-object System.Net.WebClient
    $wc.Headers.Add("Authorization", $Authorization)
    $wc.Headers.Add("X-Atlassian-Token", "nocheck") 
    $wc.UploadFile($url, $documentPath) > $null   
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} finally {
    Write-Output $attachmentResponse
    Remove-Item $documentPath
}
