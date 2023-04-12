param (        
  [Parameter(Mandatory=$true)]
	[string] $request
)

# * Environment variabels * #
# Set the below to match your environment #
$APIKeyVariableName = "" #Name of the variable contaning your OpenAI API Key

### Script ###
try {
  $apiKey = Get-AutomationVariable -Name $APIKeyVariableName
  $url = "https://api.openai.com/v1/completions"
  
  $headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $apiKey"
  }
  
  $body = @{
    prompt = "$request"
    model = "text-davinci-003"
    max_tokens = 1500
    temperature = 0.7
    n = 1
  }
  
  $jsonBody = ConvertTo-Json $body
  
  $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonBody
  
  Write-Output $response.choices.text

} catch {
  Write-Error ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.Exception.Message)")
  throw
}