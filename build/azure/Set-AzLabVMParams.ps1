[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $LabVMId
)

do {
    $labVmComputeId = (Get-AzResource -Id $LabVMId).Properties.ComputeId
    Start-Sleep -Seconds 10
}
while (-not $labVmComputeId)

# Get lab VM resource group name
$labVmRgName = (Get-AzResource -Id $labVmComputeId).ResourceGroupName

# Get the lab VM Name
$labVmName = (Get-AzResource -Id $LabVMId).Name

# Get lab VM public IP address
$labVMIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $labVmRgName -Name $labVmName).IpAddress

# Get lab VM FQDN
$labVMFqdn = (Get-AzPublicIpAddress -ResourceGroupName $labVmRgName -Name $labVmName).DnsSettings.Fqdn

Write-Host "Setting Lab Resource Group Name Var: $labVmRgName"
Write-Host "##vso[task.setvariable variable=ChocoCIClient.labVmRgName;]$labVmRgName"

Write-Host "Setting Lab VM IP Address Var: $labVMIpAddress"
Write-Host "##vso[task.setvariable variable=ChocoCIClient.labVMIpAddress;]$labVMIpAddress"

Write-Host "Setting Lab VM FQDN Var: $labVMFqdn"
Write-Host "##vso[task.setvariable variable=ChocoCIClient.labVMFqdn;]$labVMFqdn"

$CertificateScript = {
    # Make sure the Fully Qualified Domain Name is being used
    $hostName = [System.Net.Dns]::GetHostName()
    $domainName = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName

    If (-Not $hostName.endswith($domainName)) {
        $hostName += "." + $domainName
    }

    Write-Host "Creating self signed certificate"

    # you can only generate a new certificate in 'My'
    # necessary to branch based on PowerShell version, since not all parameters are supported in earlier versions
    if ($PSVersionTable.PSVersion.Major -le 4) {
        $newCert = New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My -DnsName $hostName
    }
    else {
        $newCert = New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My -DnsName $hostName -KeyUsage KeyEncipherment, DigitalSignature -NotAfter (Get-Date).AddYears(10)
    }

    # move the certificate to 'TrustedPeople'
    $certPath = Get-ChildItem -Path 'Cert:\\LocalMachine\\My' | Where-Object subject -like "*$hostName"
    Move-Item -Path $certPath.PsPath -Destination 'Cert:\\LocalMachine\\TrustedPeople' > $null
}

$Script = New-Item -Path ./CertScript.ps1
$CertificateScript | Set-Content -Path $Script.FullName

$params = @{
    ResourceGroupName = 'choco-ci'
    VMName            = $labVMName
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $Script.FullName
}

Invoke-AzVMRunCommand @params -Verbose
