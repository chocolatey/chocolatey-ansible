[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $LabVMId
)

$labVmComputeId = (Get-AzResource -Id $LabVMId).Properties.ComputeId

# Get lab VM resource group name
$labVmRgName = (Get-AzResource -Id $labVmComputeId).ResourceGroupName

# Get the lab VM Name
$labVmName = (Get-AzResource -Id $LabVMId).Name

# Get lab VM public IP address
$labVMIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $labVmRgName -Name $labVmName).IpAddress

# Get lab VM FQDN
$labVMFqdn = (Get-AzPublicIpAddress -ResourceGroupName $labVmRgName -Name $labVmName).DnsSettings.Fqdn

# Set a variable labVmRgName to store the lab VM resource group name
Write-Host "##vso[task.setvariable variable=ChocoCIClient.labVmRgName;]$labVmRgName"

# Set a variable labVMIpAddress to store the lab VM Ip address
Write-Host "##vso[task.setvariable variable=ChocoCIClient.labVMIpAddress;]$labVMIpAddress"

# Set a variable labVMFqdn to store the lab VM FQDN name
Write-Host "##vso[task.setvariable variable=ChocoCIClient.labVMFqdn;]$labVMFqdn"
