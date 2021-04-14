param(
  [Parameter(Mandatory=$true)]
  [string] $envelopeId
)

#Environment variables
$DocuSignPrivatKeyVariableName = "" #Name of variable containing private key
$DocuSignClientIDVariableName = "" #Name of variable containing client ID
$DocuSignUserIDVariableName = "" #Name of variable containing User ID
$authority = "account-d.docusign.com"
$apiUri = "https://demo.docusign.net/restapi"

#Script
try {
    $ErrorActionPreference = "Stop"
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $clientID = Get-AutomationVariable -Name $DocuSignClientIDVariableName
    $privateKey = Get-AutomationVariable -Name $DocuSignPrivatKeyVariableName
    $userId = Get-AutomationVariable -Name $DocuSignUserIDVariableName
    $scopes = "signature%20impersonation"

    function Install-NugetPackage {
        param(
            [string] $packageName,
            [string] $targetVersion
        )

        Install-Package $packageName `
            -Source https://www.nuget.org/api/v2 `
            -Provider nuget `
            -RequiredVersion $targetVersion `
            -Force > $null

        Add-Type -Assembly 'System.IO.Compression.FileSystem' > $null
        $zip = [System.IO.Compression.ZipFile]::Open((Get-Package $packageName).Source, "Read")
        $memStream = [System.IO.MemoryStream]::new()
        $reader = [System.IO.StreamReader]($zip.entries[2]).Open()
        $reader.BaseStream.CopyTo($memStream)
        [byte[]]$bytes = $memStream.ToArray()
        [System.Reflection.Assembly]::Load($bytes) > $null
        $reader.Close()
        $zip.Dispose()
    }

    # Load required assemblies
    Install-NugetPackage DerConverter '3.0.0.82'
    Install-NugetPackage PemUtils '3.0.0.82'

    # Create OAuth request
    New-Item "config\private.key" -Force > $null
    $privateKeyPath = [System.IO.Path]::Combine($PSScriptRoot, "config\private.key") | Resolve-Path
    Write-Verbose "PrivateKeyPath:  $privateKeyPath"
    Write-Output $privateKey > $privateKeyPath

    $state = [Convert]::ToString($(Get-Random -Maximum 1000000000), 16)
    $authorizationEndpoint = "https://$authority/oauth/"
    Write-Verbose "AuthorizationEndpoint: $authorizationEndpoint"
    $redirectUri = "http://localhost"
    $redirectUriEscaped = [Uri]::EscapeDataString($redirectURI)
    Write-Verbose "RedirectUriEscaped:  $redirectUriEscaped"
    $authorizationURL = "auth?scope=$scopes&redirect_uri=$redirectUriEscaped&client_id=$clientId&state=$state&response_type=code"
    Write-Verbose "AuthorizationURL:  $authorizationURL"
    $decJwtHeader = [ordered]@{
        'typ' = 'JWT';
        'alg' = 'RS256'
    } | ConvertTo-Json -Compress

    $scopes = $scopes -replace '%20',' '

    $decJwtPayLoad = [ordered]@{
        'iss'   = $clientID;
        'sub'   = $userId;
        'iat'   = $timestamp;
        'exp'   = $timestamp + 3600;
        'aud'   = $authority;
        'scope' = $scopes
    } | ConvertTo-Json -Compress

    $encJwtHeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($decJwtHeader)
    $encJwtHeader = [System.Convert]::ToBase64String($encJwtHeaderBytes) -replace '\+', '-' -replace '/', '_' -replace '='

    $encJwtPayLoadBytes = [System.Text.Encoding]::UTF8.GetBytes($decJwtPayLoad)
    $encJwtPayLoad = [System.Convert]::ToBase64String($encJwtPayLoadBytes) -replace '\+', '-' -replace '/', '_' -replace '='

    $jwtToken = "$encJwtHeader.$encJwtPayLoad"

    $keyStream = [System.IO.File]::OpenRead($privateKeyPath)
    $keyReader = [PemUtils.PemReader]::new($keyStream)

    $rsaParameters = $keyReader.ReadRsaKey()
    $rsa = [System.Security.Cryptography.RSA]::Create($rsaParameters)

    $tokenBytes = [System.Text.Encoding]::ASCII.GetBytes($jwtToken)
    $signedToken = $rsa.SignData(
        $tokenBytes,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)

    $signedBase64Token = [System.Convert]::ToBase64String($signedToken) -replace '\+', '-' -replace '/', '_' -replace '='

    $jwtToken = "$encJwtHeader.$encJwtPayLoad.$signedBase64Token"
    Write-Verbose "jwtToken: $jwtToken"
    $keyStream.Close();
    $rsa.Dispose()
    Remove-Item -Path $privateKeyPath -Force > $null

    $tokenResponse = Invoke-RestMethod `
        -Uri "$authorizationEndpoint/token" `
        -Method "POST" `
        -Body "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$jwtToken"
    Write-Verbose "TokenResponse: $tokenResponse"
    $accessToken = $tokenResponse.access_token
    Write-Verbose "AccessToken: $accessToken"
    
    $userInfoResponse = Invoke-RestMethod `
        -Uri "$authorizationEndpoint/userinfo" `
        -Method "GET" `
        -Headers @{ "Authorization" = "Bearer $accessToken" }
    $accountId = $userInfoResponse.accounts[0].account_id
    Write-Verbose "AccountId: $accountId"
}
catch {
    Write-Output "Make sure to authenticate this app using the following URI: $authorizationEndpoint$authorizationURL"
    Write-Error $_.Exception.Message
    Throw "Error: Could not authenticate with DocuSign"
}

#Get envelope status
try {
    $EnvelopeData = Invoke-RestMethod `
      -Uri "$apiUri/v2.1/accounts/$accountId/envelopes/$envelopeId" `
      -Method 'GET' `
      -Headers @{
      'Authorization' = "Bearer $accessToken";
      'Content-Type'  = "application/json";
    }
  
    Write-Output $envelopeData.status

} catch {
    Write-Error $_.Exception.Message
    Throw "Error: Get envelope status"
}