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
    $Username,

    [Parameter(Mandatory)]
    [Alias('GalaxyPassword', 'Password')]
    [string]
    $Secret,

    [Parameter()]
    [string]
    $Url
)

$PackageFile = Get-ChildItem -Path "$env:SYSTEM_DEFAULTWORKINGDIRECTORY/artifacts" -Recurse -File -Filter '*.tar.gz'
Write-Host "Found collection artifact at '$($PackageFile.FullName)'"

Write-Verbose "Publishing collection to $Url"
Write-Warning "Publishing action not yet determined."
