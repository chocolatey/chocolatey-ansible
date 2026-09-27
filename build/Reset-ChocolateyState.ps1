<#
    .SYNOPSIS
    Resets Chocolatey CLI on a CI runner back to a freshly-installed state.

    .DESCRIPTION
    GitHub-hosted Windows runners ship with Chocolatey CLI already installed, along
    with a number of Chocolatey packages, non-default configuration values, and
    potentially extra sources and pins. The Azure DevTest Lab VMs this pipeline used
    previously were effectively a blank slate, and the collection's integration tests
    assume that: they assert on the exact set of installed packages, the exact list of
    pins, the first entry of the sources list, and default config and feature values.

    This script removes the existing Chocolatey installation outright and reinstalls
    it from the community bootstrap script. That leaves the host with only the
    'chocolatey' package installed, the default community source, default
    configuration and features, and no pins -- which is what the tests expect.

    Software that was previously installed *by* those packages is deliberately left on
    disk. Chocolatey no longer tracks it, which is all the tests care about, and
    removing it properly would mean running arbitrary package uninstallers that may
    prompt, fail, or request a reboot.

    .EXAMPLE
    .\Reset-ChocolateyState.ps1

    Removes and reinstalls Chocolatey CLI, then verifies only 'chocolatey' remains.

    .NOTES
    This is intended for ephemeral CI runners only. Do not run it against a machine
    whose Chocolatey installation you care about.
#>
[CmdletBinding()]
param(
    # Path to the Chocolatey installation to reset. Defaults to the ChocolateyInstall
    # environment variable, falling back to the standard ProgramData location.
    [Parameter()]
    [string]
    $ChocolateyInstall = $(
        if ($env:ChocolateyInstall) { $env:ChocolateyInstall } else { "$env:ProgramData\chocolatey" }
    ),

    # The bootstrap script used to reinstall Chocolatey CLI.
    [Parameter()]
    [string]
    $BootstrapUrl = 'https://community.chocolatey.org/install.ps1',

    # How many times to attempt the install before giving up. The bootstrap reaches
    # out to the community repository twice, so a transient failure is possible.
    [Parameter()]
    [int]
    $BootstrapAttempts = 3
)

$ErrorActionPreference = 'Stop'

function Write-ChocolateyState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $Description,

        [Parameter(Mandatory)]
        [string]
        $ChocoCommand
    )

    Write-Host "Chocolatey CLI state $Description`:"

    foreach ($listing in 'list', 'pin list', 'source list') {
        Write-Host "  choco $listing"
        & $ChocoCommand $listing.Split(' ') --limit-output | ForEach-Object { Write-Host "    $_" }
    }
}

$chocoCommand = Get-Command -Name "$ChocolateyInstall\bin\choco.exe" -CommandType Application -ErrorAction SilentlyContinue

if ($chocoCommand) {
    Write-ChocolateyState -Description 'before reset' -ChocoCommand $chocoCommand.Source
}
else {
    Write-Host "No existing Chocolatey CLI found at '$ChocolateyInstall'."
}

Write-Host "Installing Chocolatey CLI from '$BootstrapUrl'"

$protocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::SecurityProtocol = $protocol

# The bootstrap script installs wherever this points.
$env:ChocolateyInstall = $ChocolateyInstall

# Both the bootstrap script and the package it fetches come over the network, and a
# transient failure here would otherwise take the whole job with it.
for ($attempt = 1; $attempt -le $BootstrapAttempts; $attempt++) {
    # The bootstrap script quietly does nothing if the folder already exists.
    if (Test-Path -LiteralPath $ChocolateyInstall) {
        Write-Host "Removing existing Chocolatey installation at '$ChocolateyInstall'"
        Remove-Item -LiteralPath $ChocolateyInstall -Recurse -Force
    }

    try {
        Invoke-Expression -Command ([System.Net.WebClient]::new().DownloadString($BootstrapUrl))
        break
    }
    catch {
        if ($attempt -ge $BootstrapAttempts) {
            throw "Chocolatey CLI could not be installed after $BootstrapAttempts attempts: $($_.Exception.Message)"
        }

        $delay = $attempt * 15
        Write-Warning "Attempt $attempt of $BootstrapAttempts failed: $($_.Exception.Message). Retrying in ${delay}s."
        Start-Sleep -Seconds $delay
    }
}

# The bootstrap script updates the machine environment, not this process, so pick up
# the new PATH before verifying the result.
$env:Path = @(
    [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    [System.Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

$chocoCommand = Get-Command -Name "$ChocolateyInstall\bin\choco.exe" -CommandType Application

Write-ChocolateyState -Description 'after reset' -ChocoCommand $chocoCommand.Source

$unexpectedPackages = @(& $chocoCommand.Source list --limit-output | Where-Object { $_ -notmatch '^chocolatey\|' })

if ($unexpectedPackages.Count -gt 0) {
    throw @(
        "Expected a freshly installed Chocolatey CLI to have no packages other than 'chocolatey',"
        "but found: $($unexpectedPackages -join ', '). The integration tests assert on the exact"
        "set of installed packages and will not give meaningful results against this host."
    ) -join ' '
}

Write-Host "Chocolatey CLI has been reset to a clean state."
