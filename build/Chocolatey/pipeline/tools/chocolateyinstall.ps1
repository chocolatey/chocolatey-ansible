$ErrorActionPreference = 'Stop'; # stop on all errors

$pp = Get-PackageParameters

$null = New-Item -Path $env:TEMP -Name $pp['File'] -ItemType File
Write-Host "Created '$($pp['File'])' in '$env:TEMP'"