# Force PowerShell to use secure TLS 1.2 protocols for the download connection
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$exePath = "$env:TEMP\CloudRedirectCLI.exe"

# Clean up any leftover partial file downloads if they exist
if (Test-Path $exePath) { Remove-Item $exePath -Force -ErrorAction SilentlyContinue }

Write-Host "Downloading CloudRedirect from Shadowclutch assets..." -ForegroundColor Cyan
try {
    # Using WebClient pipeline which handles TLS drops better than standard Invoke-WebRequest
    (New-Object System.Net.WebClient).DownloadFile("https://github.com/Shadowclutch/CloudRedirect/releases/latest/download/CloudRedirectCLI.exe", $exePath)
    
    Write-Host "Unblocking file executable..." -ForegroundColor Yellow
    Unblock-File -Path $exePath

    Write-Host "Executing fix..." -ForegroundColor Green
    & $exePath /stfixer
}
catch {
    Write-Host "Download failed. Your Antivirus/Defender is likely blocking the network stream directly." -ForegroundColor Red
    Write-Host "Error Details: $_" -ForegroundColor DarkRed
}
