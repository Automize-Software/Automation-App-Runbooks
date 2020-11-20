param (
  [Parameter(Mandatory=$true)]
		[string] $serverName,
		
	[Parameter(Mandatory=$true)]
		[string] $resourceGroupName
)

try {
    if (Get-Module -ListAvailable -Name "Az.Compute") {
        Write-Verbose "Found Az.Compute module"
    } else {
        throw "Could not find Az.Compute module. Please install this module"
    }
    
    $connectionName = "AzureRunAsConnection"
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName 

    Write-Verbose "Logging in to Azure..."

    $connectionResult = Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    Write-Verbose "Login successful.."

    Start-AzVM -Name $serverName -ResourceGroupName $resourceGroupName
} catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}