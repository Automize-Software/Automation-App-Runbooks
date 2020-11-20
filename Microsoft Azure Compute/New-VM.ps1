param (
    [Parameter(Mandatory=$true)]
		[string] $VMName = "MyVM",
		
    [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName = "MyResourceGroup",

    [Parameter(Mandatory=$true)]
        [string] $VMLocalAdminUser,
        
    [Parameter(Mandatory=$true)]
        [string] $VMLocalAdminPassword,
        
    [Parameter(Mandatory=$true)]
        [string] $LocationName = "eastus",
    
    [Parameter(Mandatory=$true)]
        [string] $VMSize = "Standard_DS3",

    [Parameter(Mandatory=$true)]
        [string] $NICName = "MyNIC",

    [Parameter(Mandatory=$true)]
        [string] $SubnetID
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

    $VMLocalAdminSecurePassword = ConvertTo-SecureString $VMLocalAdminPassword -AsPlainText -Force

    $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $SubnetID

    $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2012-R2-Datacenter' -Version latest

    New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose
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