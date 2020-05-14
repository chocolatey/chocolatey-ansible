<#
    .SYNOPSIS
    Publishes a tarball package to Ansible Galaxy / a specified target server.

    .DESCRIPTION
    Publishes a tarball package containing an Ansible Collection to the Ansible
    Galaxy repository, as well as Automation Hub.

    The specified path is searched for any *.tar.gz files within, which will be
    published.

    .EXAMPLE
    .\Publish-Collection.ps1

    Publishes the collection tarball found in $env:SYSTEM_DEFAULTWORKINGDIRECTORY/artifacts folder
    to Ansible Galaxy and Automation Hub.

    .EXAMPLE
    .\Publish-Collection.ps1 -Server automation_hub

    Only publishes the collection to Automation Hub.

    .NOTES
    General notes
#>
[CmdletBinding()]
param(
    [Parameter()]
    # The file path or folder containing the collection tarball.
    [string]
    $Path = "$env:SYSTEM_DEFAULTWORKINGDIRECTORY/artifacts",

    [Parameter()]
    # The target server to publish the collection to.
    # By default, collections will be published to ansible_galaxy and
    # automation_hub (as defined in the ansible.cfg file)
    [string[]]
    $Server
)

$Tarballs = Get-ChildItem -Path $Path -Recurse -File -Filter '*.tar.gz'
Write-Host "Found collection artifact(s) at:"
Write-Host $($PackageFile.FullName -join [Environment]::NewLine)

foreach ($file in $Tarballs) {
    if ($PSBoundParameters.ContainsKey('Server')) {
        foreach ($item in $Server) {
            Write-Host "Publishing collection '$($file.Name)' to targeted server: [$item]"
            ansible-galaxy collection publish $file.FullName --server $item
        }
    }
    else {
        Write-Host "Publishing collection '$($file.Name)' to all configured servers"
        ansible-galaxy collection publish $PackageFile.FullName
    }
}
