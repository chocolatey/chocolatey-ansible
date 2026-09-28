<#
    .SYNOPSIS
    Prepares a Windows CI runner to be used as the Ansible target for the collection's
    integration tests.

    .DESCRIPTION
    The integration tests need a Windows host reachable over WinRM. When the control
    node is a WSL distribution running on the same runner, that traffic never leaves
    the runner VM, so this configures the simplest thing that works: a local
    administrator account, an HTTP WinRM listener on port 5985 with Basic
    authentication, and a firewall rule permitting inbound traffic on that port.

    The password is read from an environment variable rather than taken on the command
    line so that it does not appear in the process command line or in CI logs.

    .EXAMPLE
    $env:ANSIBLE_TEST_PASSWORD = '...'
    .\Initialize-WinRmTarget.ps1

    Creates the 'ansible' local administrator and configures WinRM for it.

    .NOTES
    This is intended for ephemeral CI runners only. It creates a privileged local
    account and relaxes WinRM's transport security; do not run it against a machine
    that is reachable by anything you do not trust.
#>
[CmdletBinding()]
param(
    # The local account the Ansible control node will connect as. Created if missing.
    [Parameter()]
    [string]
    $Username = $(if ($env:ANSIBLE_TEST_USERNAME) { $env:ANSIBLE_TEST_USERNAME } else { 'ansible' }),

    # The password to assign to that account. Read from ANSIBLE_TEST_PASSWORD by default.
    [Parameter()]
    [string]
    $Password = $env:ANSIBLE_TEST_PASSWORD,

    # How long to wait for the WinRM listener to start accepting connections.
    [Parameter()]
    [int]
    $TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

# winrm quickconfig always creates the listener on the default HTTP port, so this isn't
# a parameter.
$port = 5985

if (-not $Password) {
    throw "No password supplied. Set the ANSIBLE_TEST_PASSWORD environment variable or pass -Password."
}

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Write-Host "Updating password for existing local user '$Username'"
    Set-LocalUser -Name $Username -Password $securePassword -PasswordNeverExpires $true
}
else {
    Write-Host "Creating local user '$Username'"
    New-LocalUser -Name $Username -Password $securePassword -PasswordNeverExpires -AccountNeverExpires | Out-Null
}

$administrators = Get-LocalGroupMember -Group 'Administrators' | ForEach-Object { $_.Name.Split('\')[-1] }

if ($Username -notin $administrators) {
    Write-Host "Adding '$Username' to the Administrators group"
    Add-LocalGroupMember -Group 'Administrators' -Member $Username
}

# Without this, a local account connecting over the network gets a non-elevated token
# and anything needing admin rights fails.
Write-Host "Enabling LocalAccountTokenFilterPolicy"
$policyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
New-ItemProperty -Path $policyPath -Name 'LocalAccountTokenFilterPolicy' -Value 1 -PropertyType DWord -Force | Out-Null

Write-Host "Configuring the WinRM service"
winrm quickconfig -quiet
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

$ruleName = 'Allow-WinRM-HTTP-Ansible'

if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
    Write-Host "Adding firewall rule '$ruleName' for inbound TCP $port"
    $firewallRule = @{
        Name        = $ruleName
        DisplayName = 'Allow WinRM HTTP (Ansible integration tests)'
        Enabled     = 'True'
        Profile     = 'Any'
        Action      = 'Allow'
        Direction   = 'Inbound'
        Protocol    = 'TCP'
        LocalPort   = $port
    }

    New-NetFirewallRule @firewallRule | Out-Null
}

Write-Host "Waiting for WinRM to accept connections on port $port"
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

while (-not (Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) {
        throw "WinRM is not listening on port $port after $TimeoutSeconds seconds."
    }

    Start-Sleep -Seconds 3
}

Write-Host "WinRM is listening on port $port and ready for '$Username' to connect."
