param(
  [Parameter(Mandatory=$true)]
  [string] $documentSysId,

  [Parameter(Mandatory=$true)]
  [string] $signerName,

  [Parameter(Mandatory=$true)]
  [string] $signerEmail
  
)

#Environment variables
$DocuSignPrivatKeyVariableName = "" #Name of variable containing private key
$DocuSignClientIDVariableName = "" #Name of variable containing client ID
$DocuSignUserIDVariableName = "" #Name of variable containing User ID
$serviceNowDocuSignUserCredentialName = "" #Name of Crendential to be used for authenticated with ServiceNow. Ex. ServiceNow-DocuSign-User
$serviceNowInstance = "" #Name of ServiceNow instance to attach the document(s) to. Ex: automizedev
$ccName = "" #Name of entity sending this request. This is the person that the signer can reply to. Ex. Automize-Software
$ccEmail = "" #Email of entity sending this request. This is the person that the signer can reply to. Ex. sales@automize-software.com
$authority = "account-d.docusign.com"
$apiUri = "https://demo.docusign.net/restapi"

#Script
try {
    $ErrorActionPreference = "Continue"
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


    $authorizationEndpoint = "https://account-d.docusign.com/oauth/"
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
    Write-Output "Make sure to authenticate this app using the following URI: $authorizationURL"
    Write-Error $_.Exception.Message
    Throw "Error: Could not authenticate with DocuSign"
}

try {
    New-Item "config\document.bin" -Force > $null
    $documentPath = [System.IO.Path]::Combine($PSScriptRoot, "config\document.bin") | Resolve-Path

    $ServiceNowCredential = Get-AutomationPSCredential -Name $serviceNowDocuSignUserCredentialName
    $ServiceNowAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ServiceNowCredential.UserName, $ServiceNowCredential.GetNetworkCredential().Password)))
    $ServiceNowHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $ServiceNowHeaders.Add('Authorization',('Basic {0}' -f $ServiceNowAuthInfo))
    $ServiceNowHeaders.Add('Accept','*/*')

    Write-Verbose "ServiceNowHeaders: $ServiceNowHeaders"
    Write-Verbose "DocumentPath: $documentPath"
    
    $uri = "https://$serviceNowInstance.service-now.com/api/now/attachment/$documentSysId/file"
    Write-Verbose "Uri: $uri"
    $method = "get"
    $response = Invoke-RestMethod -Headers $ServiceNowHeaders -Method $method -Uri $uri -OutFile $documentPath
    
    Write-Verbose "After Rest get document"

    $requestData = New-TemporaryFile
    $response = New-TemporaryFile
    $docBase64 = New-TemporaryFile

    [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($documentPath)) > $docBase64
    
    # Concatenate the different parts of the request
    @{
        emailSubject = "Please sign this document set";
        documents    = @(
            @{
                documentBase64 = "$(Get-Content $docBase64)";
                name           = "Terms and conditions";
                fileExtension  = "docx";
                documentId     = "1";
            }; );
        recipients   = @{
            carbonCopies = @(
                @{
                    email        = $ccEmail;
                    name         = $ccName;
                    recipientId  = "2";
                    routingOrder = "2";
                };
            );
            signers      = @(
                @{
                    email        = $signerEmail;
                    name         = $signerName;
                    recipientId  = "1";
                    routingOrder = "1";
                    tabs         = @{
                        signHereTabs = @(
                            @{
                                anchorString  = "/sn1/";
                                anchorUnits   = "pixels";
                                anchorXOffset = "20";
                                anchorYOffset = "10";
                            }; );
                        textTabs     = @(
                        );
                    };
                };
            );
        };
        status       = "sent";
    } | ConvertTo-Json -Depth 32 > $requestData
    
    $envelopeURI = "$apiUri/v2.1/accounts/$accountId/envelopes"
    Write-Verbose "EnvelopeURI: $envelopeURI"
    Invoke-RestMethod `
        -Uri $envelopeURI `
        -Method 'POST' `
        -Headers @{
        'Authorization' = "Bearer $accessToken";
        'Content-Type'  = "application/json";
    } `
        -InFile (Resolve-Path $requestData).Path `
        -OutFile $response

    Write-Output "$(Get-Content -Raw $response)"

    Remove-Item $requestData
    Remove-Item $response
    Remove-Item $docBase64

} catch {
    Write-Error $_.Exception.Message
    Throw "Error: Create document in DocuSign"
}
