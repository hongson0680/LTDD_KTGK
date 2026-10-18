# Run this script in an elevated PowerShell window on the Windows machine that hosts SQL Server.
$ErrorActionPreference = 'Stop'
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open PowerShell with Run as administrator, then run this script again.'
}

$runtimeVersion = '9.0.19'
$downloadDirectory = Join-Path $env:TEMP 'ToeicRuntimeInstall'
New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null
$installers = @(
    @{ Name = "dotnet-runtime-$runtimeVersion-win-x64.exe"; Url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/$runtimeVersion/dotnet-runtime-$runtimeVersion-win-x64.exe" },
    @{ Name = "aspnetcore-runtime-$runtimeVersion-win-x64.exe"; Url = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/$runtimeVersion/aspnetcore-runtime-$runtimeVersion-win-x64.exe" }
)
foreach ($item in $installers) {
    $path = Join-Path $downloadDirectory $item.Name
    Invoke-WebRequest -Uri $item.Url -OutFile $path
    $signature = Get-AuthenticodeSignature -FilePath $path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
        throw "Installer signature verification failed: $($item.Name)"
    }
    $process = Start-Process -FilePath $path -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Installer failed ($($process.ExitCode)): $($item.Name)"
    }
}

$tcpKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp'
Set-ItemProperty -Path $tcpKey -Name Enabled -Value 1
$ipAll = Join-Path $tcpKey 'IPAll'
Set-ItemProperty -Path $ipAll -Name TcpDynamicPorts -Value ''
Set-ItemProperty -Path $ipAll -Name TcpPort -Value '1433'
Restart-Service -Name MSSQLSERVER -Force

Write-Host 'Installed .NET 9 runtimes:'
dotnet --list-runtimes
Write-Host 'SQL Server TCP settings:'
Get-ItemProperty $tcpKey | Select-Object Enabled
Get-ItemProperty $ipAll | Select-Object TcpDynamicPorts, TcpPort
Get-Service MSSQLSERVER | Select-Object Name, Status
