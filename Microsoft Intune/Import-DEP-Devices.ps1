<#
  This Runbook authenticates with Intune using the Graph API
  It then collects all DEP devices (iPhones) to the specified importset table in ServiceNow
  This runbook must be executed on a Windows Hybrid Worker
#>

[CmdletBinding()]
param(
)

# * Environment variabels * #
# Set the below to match your environment #
$apiVersion = "beta" # The API version to use. Ex: beta
$ServiceNowInstance = "" #Name of the ServiceNow instance to send the data to. Ex: automize
$ServiceNowCredentialName = "" #The name of the ServiceNow credentials to use
$IntuneCredentialName = "" #The name of the Intune Credentials to use
$IntuneClientIDVariableName = "" #The name of the variable containing the Client ID for Intune
$TenantNameVariableName = "" #The name of the variable containing the Microsoft Tenant ID
$ServiceNowImportSetTable = "" #The name of the import set table in ServiceNow to which the data will be loaded


### Script ###
try {
    $ErrorActionPreference = "Stop"    
    $version = $apiVersion
    $OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8
    
    
    $ServiceNowCredential = Get-AutomationPSCredential -Name $ServiceNowCredentialName
    $ServiceNowAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ServiceNowCredential.UserName, $ServiceNowCredential.GetNetworkCredential().Password)))
    $ServiceNowHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $ServiceNowHeaders.Add('Authorization',('Basic {0}' -f $ServiceNowAuthInfo))
    $ServiceNowHeaders.Add('Accept','application/json')
    $ServiceNowHeaders.Add('Content-Type','application/json; charset=utf-8')
    
    $Credential = Get-AutomationPSCredential -Name $IntuneCredentialName

    $ClientID = Get-AutomationVariable -Name $IntuneClientIDVariableName
    $TenantName = Get-AutomationVariable -Name $TenantNameVariableName

    $AzureADModulePath = Get-Module -Name "AzureAD" -ListAvailable -ErrorAction Stop -Verbose:$false | Select-Object -ExpandProperty ModuleBase

    Write-Verbose "AzureAD module path: $AzureADModulePath" -Verbose
            
    $Assemblies = @(
        (Join-Path -Path $AzureADModulePath -ChildPath "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"),
        (Join-Path -Path $AzureADModulePath -ChildPath "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll")
    )

    $Assemblies.ForEach({
        Write-verbose "Adding Assembly: $_" -Verbose
    })

    Add-Type -Path $Assemblies -ErrorAction Stop

    $Authority = "https://login.microsoftonline.com/$($TenantName)/oauth2/token"

    Write-Verbose "Authority: $Authority" -Verbose

    $ResourceRecipient = "https://graph.microsoft.com"

    Write-Verbose "Resource recipient: $ResourceRecipient" -Verbose

    $AuthenticationContext = New-Object -TypeName "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $Authority -ErrorAction Stop
    $UserPasswordCredential = New-Object -TypeName "Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential" -ArgumentList ($Credential.UserName, $Credential.Password) -ErrorAction Stop

    $token = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($AuthenticationContext, $ResourceRecipient, $ClientID, $UserPasswordCredential)

    Write-Verbose "Token acquired: $($token.Result.AccessTokenType) $($token.Result.AccessToken)" -Verbose

    $headers = @{
        'Authorization' = "$($token.Result.AccessTokenType) $($token.Result.AccessToken)"
        'Content-Type' = "application/json"
    }
    
    $req = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$version/deviceManagement/depOnboardingSettings" -Headers $headers
    $OnboardSettings = $req.value;
    foreach($Setting in $OnboardSettings) {
        Write-Verbose $Setting
        if($null -ne $Setting.id -And $Setting.tokenType -eq "dep"){
            $id = $Setting.id
        }
    }
    Write-Verbose "depOnboardingSettings ID $id"
    
    $req = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$version/deviceManagement/depOnboardingSettings/$id/importedAppleDeviceIdentities" -Headers $headers
    $Devices = @()
    $Devices += $req.value
    while ($null -ne $req.'@odata.nextLink') {
        $uri = $req.'@odata.nextLink' 
        $req = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -Verbose
        $Devices += $req.value
    }

    $ServiceNowURI = "https://$ServiceNowInstance.service-now.com/api/now/import/$ServiceNowImportSetTable"
    
    foreach($Device in $Devices) {
      $json = $Device | ConvertTo-Json
      $body = [regex]::Replace($json,'(?<=")(.*?)(?=":)',{$args[0].Groups[1].Value.ToLower().replace(' ','_')})
      $body = [System.Text.Encoding]::UTF8.GetBytes($body)
      $response = Invoke-RestMethod -Headers $ServiceNowHeaders -Method 'post' -Uri $ServiceNowURI -Body $body
      $output = $response.RawContent
      Write-Verbose "ServiceNow output: $output"
    }
}

catch {
    Write-Verbose ("Exception caught at line $($_.InvocationInfo.ScriptLineNumber), $($_.exception.message)") -Verbose
    throw
}
finally {
    Write-Verbose "Runbook finished"
}