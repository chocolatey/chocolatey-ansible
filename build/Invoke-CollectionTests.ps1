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

                vagrant ssh choco_ansible_server --command 'cd chocolatey; ansible-galaxy collection build; ansible-galaxy collection install *.tar.gz'
                vagrant ssh choco_ansible_server --command 'cd ../.ansible/collections/ansible_collections/chocolatey/chocolatey'
                vagrant ssh choco_ansible_server --command 'ansible-test windows-integration -vvvvv --inventory vagrant-inventory.winrm'
            }
            'CI' {

            }
        }
    }
    finally {
        Pop-Location
    }
}
