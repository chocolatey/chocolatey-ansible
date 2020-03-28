<#
    .SYNOPSIS
    Publishes a tarball package to Ansible Galaxy / a specified target server.

    .DESCRIPTION
    Publishes a tarball package containing an Ansible Collection to Ansible's Galaxy repository,
    as well as AH for paying customers.

    The specified path is searched for an `artifacts` folder, and any *.tar.gz files within will
    be published to Ansible Galaxy and/or AH.

    .EXAMPLE
    An example

    .NOTES
    General notes
#>
[CmdletBinding()]
param(
    [Parameter()]
    # The file path or folder containing the collection tarball.
    [string]
    $Path = "$env:SYSTEM_DEFAULTWORKINGDIRECTORY/artifacts",

    [Parameter(Mandatory)]
    # The API key required to publish the collection to the specified server.
    [string]
    $ApiKey,

    [Parameter()]
    # The target server to publish the collection to.
    # By default, collections will be published to Ansible Galaxy.
    [Alias('ServerUrl', 'Url')]
    [string]
    $Server
)

$PackageFile = Get-ChildItem -Path $Path -Recurse -File -Filter '*.tar.gz'
Write-Host "Found collection artifact at '$($PackageFile.FullName)'"

if ($Server) {
    Write-Host "Publishing collection to $Server"
    ansible-galaxy collection publish $PackageFile.FullName --token=$ApiKey --server=$Server
}
else {
    Write-Host "Publishing collection to Ansible Galaxy (default server)"
    ansible-galaxy collection publish $PackageFile.FullName --token=$ApiKey
}
