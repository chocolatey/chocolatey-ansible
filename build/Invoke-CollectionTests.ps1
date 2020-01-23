[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Vagrant', 'CI')]
    [string]
    $Mode = 'Vagrant'
)
begin {
    Push-Location
}
process {
    try {
        switch ($Mode) {
            'Vagrant' {
                Set-Location -Path $PSScriptRoot
                vagrant up

                if (-not $?) {
                    throw "An error has occurred; please refer to the Vagrant log for details."
                }

                $Command = @(
                    'source ansible-venv/bin/activate'
                    'cd chocolatey'
                    'ansible-galaxy collection build; ansible-galaxy collection install *.tar.gz'
                    'cd ../.ansible/collections/ansible_collections/chocolatey/chocolatey'
                    'sudo ansible-test windows-integration -vvvvv --inventory vagrant-inventory.winrm'
                ) -join ';'

                vagrant ssh choco_ansible_server --command $Command
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
            'CI' {

            }
        }
    }
    finally {
        Pop-Location
    }
}
