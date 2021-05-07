[CmdletBinding(DefaultParameterSetName = 'Vagrant')]
param(
    [Parameter(ParameterSetName = 'CI')]
    [switch]
    $IsCIBuild,

    [Parameter(ParameterSetName = 'CI')]
    [string]
    $Username,

    [Parameter(ParameterSetName = 'CI')]
    [Alias('LabVMFqdn')]
    [string]
    $ComputerName,

    [Parameter(ParameterSetName = 'CI')]
    [Alias('Password')]
    [string]
    $Secret
)
begin {
    Push-Location

    $InventoryFile = if ($IsCIBuild) { 'ci-inventory.winrm' } else { 'vagrant-inventory.winrm' }
    $Sudo = if ($IsCIBuild) { [string]::Empty } else { "sudo " }

    $OutputPath = if ($IsCIBuild) {
        Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath 'testresults/'
    }
    else {
        '~/.testresults/'
    }

    $ImportVenv = 'source ~/ansible-venv/bin/activate'
    $SetCollectionLocation = 'cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey'
    $SetupCommands = @(
        $ImportVenv
        'cd ./chocolatey'
        'ansible-galaxy collection build'
        'ansible-galaxy collection install *.tar.gz'
    )
    $RunTests = @(
        $SetCollectionLocation
        $ImportVenv
        "${Sudo}ansible-test windows-integration -vvvv --inventory $InventoryFile --requirements --continue-on-error"
        "${Sudo}ansible-test sanity -vvvvv --requirements"
        "${Sudo}ansible-test coverage xml -vvvvv --requirements"
    )
    $CleanupCommands = @(
        "cp -r ./tests/output/ $OutputPath"
        "rm -r $OutputPath/.tmp"
    )
    
    # Join these with && so if the setup fails, the tests don't try to run
    $Commands = @(
        $SetupCommands
        # Join these with ; so if an individual step fails, continue to run so we can get as many results as possible
        @(
            $RunTests
            $CleanupCommands
        ) -join ' ; '
    ) -join ' && '
}
process {
    try {
        if ($IsCIBuild) {
            if (!$Secret) {
                Write-Warning "Choco Client Password appears to be missing!"
            }

            $Inventory = @(
                "[windows]"
                "win10 ansible_host=$ComputerName"
                ""
                "[windows:vars]"
                "ansible_user=$Username"
                "ansible_password=$Secret"
                "ansible_connection=winrm"
                "ansible_port=5986"
                "ansible_winrm_transport=ntlm"
                "ansible_winrm_server_cert_validation=ignore"
                "ansible_become_method=runas"
            )

            $Inventory | Set-Content -Path './chocolatey/tests/integration/ci-inventory.winrm'
            (Get-Content -Path './chocolatey/galaxy.yml' -Raw) -replace '{{ REPLACE_VERSION }}', $env:PACKAGE_VERSION |
                Set-Content -Path './chocolatey/galaxy.yml'
            bash -c $Commands

            # Locate the built tarball and expose the path & name in Azure variables
            $CollectionTarball = Get-ChildItem -Path './chocolatey' -Recurse -File -Filter '*chocolatey*.tar.gz'
            Write-Host "##vso[task.setvariable variable=ArtifactPath;isOutput=true]$($CollectionTarball.FullName)"
            Write-Host "##vso[task.setvariable variable=ArtifactName;isOutput=true]$($CollectionTarball.Name)"
        }
        else {
            Set-Location -Path $PSScriptRoot
            vagrant up

            if (-not $?) {
                throw "An error has occurred; please refer to the Vagrant log for details."
            }

            vagrant ssh choco_ansible_server --command "sed -i ./chocolatey/galaxy.yml 's/{{ REPLACE_VERSION }}/$env:PACKAGE_VERSION/g'"
            vagrant ssh choco_ansible_server --command $Commands
            $Result = [PSCustomObject]@{
                Success  = $?
                ExitCode = $LASTEXITCODE
            }

            vagrant destroy --force

            $Result

            if (-not $Result.Success) {
                throw "Test failures occurred. Refer to the Vagrant log."
            }
        }
    }
    finally {
        Pop-Location
    }
}
