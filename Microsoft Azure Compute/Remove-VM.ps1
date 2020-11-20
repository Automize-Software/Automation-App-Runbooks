param (
  [Parameter(Mandatory=$true)]
		[string] $serverName,
		
	[Parameter(Mandatory=$true)]
		[string] $resourceGroupName
)

try {
    $connectionName = "AzureRunAsConnection"
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName 

    Write-Verbose "Logging in to Azure..."

    $connectionResult = Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    Write-Verbose "Login successful.."

    Remove-AzVM -Name $serverName -ResourceGroupName $resourceGroupName
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