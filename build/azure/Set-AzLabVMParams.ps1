[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $LabVMId,

    [Parameter(Mandatory)]
    [string]
    $Username,

    [Parameter(Mandatory)]
    [Alias('Password')]
    [string]
    $Secret
)

do {
    $labVm = Get-AzResource -Id $labVMId
    $labVmComputeId = $labVM.Properties.ComputeId
    Start-Sleep -Seconds 10
}
while (-not $labVmComputeId)

# Get lab VM resource group name
$labVmRgName = (Get-AzResource -Id $labVmComputeId).ResourceGroupName

# Get lab VM public IP address
$labVMIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $labVmRgName -Name $labVm.Name).IpAddress

# Get lab VM FQDN
$labVMFqdn = (Get-AzPublicIpAddress -ResourceGroupName $labVmRgName -Name $labVm.Name).DnsSettings.Fqdn

Write-Host "Setting Lab Resource Group Name Var: $labVmRgName"
Write-Host "##vso[task.setvariable variable=RgName;isOutput=true]$labVmRgName"

Write-Host "Setting Lab VM IP Address Var: $labVMIpAddress"
Write-Host "##vso[task.setvariable variable=IpAddress;isOutput=true]$labVMIpAddress"

Write-Host "Setting Lab VM FQDN Var: $labVMFqdn"
Write-Host "##vso[task.setvariable variable=Fqdn;isOutput=true]$labVMFqdn"

$CertificateScript = {
    $url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
    $file = "$env:temp\ConfigureRemotingForAnsible.ps1"

    [System.Net.WebClient]::new().DownloadFile($url, $file)

    & $file -Verbose

    $Username = "{0}"
    $Password = "{1}" | ConvertTo-SecureString -AsPlainText -Force

    New-LocalUser -Name $Username -Password $Password -PasswordNeverExpires
    Add-LocalGroupMember -Group Administrators -Member $Username
}.ToString()

$Script = New-Item -Path ./CertScript.ps1
$CertificateScript -f $Username, $Secret | Set-Content -Path $Script.FullName

$params = @{
    ResourceId        = $labVMId
    CommandId         = 'RunPowerShellScript'
    ScriptPath        = $Script.FullName
}

Invoke-AzVMRunCommand @params -Verbose

Remove-Item -Path $Script.FullName -Force
