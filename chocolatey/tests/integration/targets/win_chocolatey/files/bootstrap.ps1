# This is a minimal bootstrap script which simply pulls the default bootstrap
# script from community.chocolatey.org and then uses that to install Chocolatey.
# Afterwards, a file is created so we can confirm this bootstrap script was
# indeed used to install Chocolatey.

$protocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::SecurityProtocol = $protocol

$client = New-Object System.Net.WebClient
$scriptContent = $client.DownloadString("https://community.chocolatey.org/install.ps1")
$filePath = "$PSScriptRoot/install.ps1"

$scriptContent | Set-Content -Path $filePath

$ErrorActionPreference = 'Stop'

# Parameters aren't needed; our Ansible installation process sets all the parameters
# with environment variables before running the bootstrap script.
& $filePath

$temp = "C:\temp"
if (-not (Test-Path -LiteralPath $temp)) {
    New-Item -ItemType Directory -Path $temp -Force > $null
}
[pscustomobject]@{ bootstrap = $true } | ConvertTo-Json | Set-Content -Path "$temp\confirm-bootstrap.txt"
