<#
  This Runbook is triggered by Webhook used by Azure DevOps to initiate an update of the state in ServiceNow
  In this template we will set the state of an Incident to Resolved. Tailor this template to fit with the state mappings of your environment
#>
param (
    [object] $WebhookData
)

# * Environment variabels * #
# Set the below to match your environment #
$ServiceNowInstanceName = "" #Name of the ServiceNow instance that should be updated
$serviceNowCredentialName = "" #Name of Credentials to authenticate with ServiceNow with
$ServiceNowTable = "" #Name of ServiceNow table to update. Ex: incident

### Script ###
try{
    $workItem = $WebhookData.Requestbody | ConvertFrom-Json
	$workItemStateObj = $workItem.resource.fields | Select-Object -ExpandProperty System.State
	$state = $workItemStateObj.newValue
	$correlationId = $workItem.resource._links.parent.href
	Write-Output $state
	Write-Output $correlationId

	if($state -eq "Done") { # If state is "Done" we will mark the Incident as Resolved in ServiceNow
		$ServiceNowCredential = Get-AutomationPSCredential -Name $serviceNowCredentialName
		$ServiceNowAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ServiceNowCredential.UserName, $ServiceNowCredential.GetNetworkCredential().Password)))
		$ServiceNowHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
		$ServiceNowHeaders.Add('Authorization',('Basic {0}' -f $ServiceNowAuthInfo))
		$ServiceNowHeaders.Add('Accept','application/json')
		$ServiceNowHeaders.Add('Content-Type','application/json')

		$ServiceNowURI = "https://$ServiceNowInstanceName.service-now.com/api/now/table/$($ServiceNowTable)?sysparm_query=correlation_id%3D$correlationId&sysparm_fields=sys_id,state&sysparm_limit=1"
		Write-Verbose "ServiceNow URI: $ServiceNowURI"

		$response = Invoke-RestMethod -Method "GET" -Uri $ServiceNowURI -Headers $ServiceNowHeaders
		foreach($incident in $response.result) {
			$serviceInput = @{
				'state' = "6"
				'close_code' = "Solved (Permanently)"
				'close_notes' = "Resolved in Azure DevOps"
			}
			$sysId = $incident.sys_id;
			$json = $serviceInput | ConvertTo-Json -Depth 6
			$jsonEncoded = [System.Text.Encoding]::UTF8.GetBytes($json)
			$updateURI = "https://$ServiceNowInstanceName.service-now.com/api/now/table/$ServiceNowTable/$sysId"
			Write-Verbose $updateURI
			$incidentResult = Invoke-RestMethod -Method "PUT" -Uri $updateURI -Headers $ServiceNowHeaders -Body $jsonEncoded | ConvertTo-Json
		}
	}

} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
} finally {
    Write-Output $incidentResult
}
