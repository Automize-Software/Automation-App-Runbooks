<#
 This runbook will create a new job in Microsoft Orchestrator based on the given input.
 $rbParameters needs to be an XML containing the input parameters for the runbook (if any). Ex: <Parameter><ID>{fb2c8c03-a8df-4a50-905c-8727e8dc9f0a}</ID><Value>Ok</Value></Parameter>
#>

[CmdletBinding()]

param (
    [Parameter(Mandatory=$true)]
		[string] $RunBookGuid,
		
    [Parameter(Mandatory=$false)]
        [string] $rbParameters
)

# * Environment variabels * #
# Set the below to match your environment #
$ServiceURLVariableName = "" #Name of the variable containing the Microsoft Orchestrator Service URL
$rbCredentialVariableName = "" #Name of the credentials for authenticating with Microsoft Orchestrator

### Script ###

$ErrorActionPreference = "Stop"
try {
   
    $ServiceURL = Get-AutomationVariable -Name $ServiceURLVariableName
    $rbCredential = Get-AutomationPSCredential -Name $rbCredentialVariableName

    $request = [System.Net.HttpWebRequest]::Create($ServiceURL)

    # Build the request header
    $request.Method = "POST"
    $request.UserAgent = "Microsoft ADO.NET Data Services"
    $request.Accept = "application/atom+xml,application/xml"
    $request.ContentType = "application/atom+xml"
    $request.KeepAlive = $true
    $request.Headers.Add("Accept-Encoding","identity")
    $request.Headers.Add("Accept-Language","en-US")
    $request.Headers.Add("DataServiceVersion","1.0;NetFx")
    $request.Headers.Add("MaxDataServiceVersion","2.0;NetFx")
    $request.Headers.Add("Pragma","no-cache")

    # Build the request body
    $requestBody = @"

    
        
            
                $($RunBookGuid)
                $($rbParameters)]]>
            
        
    
"@

    # Create a request stream from the request
    $requestStream = new-object System.IO.StreamWriter $request.GetRequestStream()
        
    # Sends the request to the service
    $requestStream.Write($RequestBody)
    $requestStream.Flush()
    $requestStream.Close()

    if ($null -ne $rbCredential -and $rbCredential -ne "") {
        $request.Credentials = $rbCredential
    }

    # Get the response from the request
    [System.Net.HttpWebResponse] $response = [System.Net.HttpWebResponse] $request.GetResponse()

    # Write the HttpWebResponse to String
    $responseStream = $Response.GetResponseStream()
    $readStream = new-object System.IO.StreamReader $responseStream
    $responseString = $readStream.ReadToEnd()

    # Close the streams
    $readStream.Close()
    $responseStream.Close()

    # Get the ID of the resulting job
    if ($response.StatusCode -eq 'Created')
    {
        $xmlDoc = [xml]$responseString
        $jobId = $xmlDoc.entry.content.properties.Id.InnerText
        Write-Output "Successfully started runbook. Job ID: $jobId"
    }
    else
    {
        Throw "Could not start runbook. Status: $($response.StatusCode)"
    } 
}

catch {
    write-output $_.exception.innerexception
    Throw
}