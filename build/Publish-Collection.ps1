<#
    .SYNOPSIS
    Publishes a tarball package to Ansible Galaxy / AH

    .DESCRIPTION
    Publishes a tarball package containing an Ansible Collection to Ansible's Galaxy repository,
    as well as AH for paying customers.

    The default working directory specified in $env:SYSTEM_DEFAULTWORKINGDIRECTORY is searched for an
    `artifacts` folder, and any *.tar.gz files within will be published to Ansible Galaxy and/or AH.

    .EXAMPLE
    An example

    .NOTES
    General notes
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [Alias('Username')]
    [string]
    $GalaxyUsername,

    [Parameter(Mandatory)]
    [Alias('GalaxyPassword', 'Password')]
    [string]
    $GalaxySecret,

    [Parameter()]
    [string]
    $AHUsername,

    [Parameter()]
    [Alias('AHPassword')]
    [string]
    $AHSecret
)

$PackageFile = Get-ChildItem -Path "$env:SYSTEM_DEFAULTWORKINGDIRECTORY/artifacts" -Recurse -File -Filter '*.tar.gz'
Write-Host "Found collection artifact at '$($PackageFile.FullName)'"

if ($AHUsername -and $AHSecret) {
    Write-Verbose "Publishing collection to AH"
    Write-Warning "Publishing action not yet determined."
}
else {
    Write-Warning "AH credentials were blank or not provided. Skipping AH publish step."
}

Write-Verbose "Publishing collection to Ansible Galaxy"
Write-Warning "Publishing action not yet determined."
