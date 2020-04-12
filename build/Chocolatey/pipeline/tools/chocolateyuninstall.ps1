$ErrorActionPreference = 'Stop'

$pp = Get-PackageParameters

Remove-Item "$env:TEMP\$($pp['File'])" -Force
Write-Host "Removed '$($pp['File'])' from '$env:TEMP'"