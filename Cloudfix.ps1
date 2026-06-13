# Custom CloudRedirect Fixer by Shadowclutch
$exePath = "$env:TEMP\CloudRedirectCLI.exe"

Write-Host "Downloading CloudRedirect from Shadowclutch assets..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/Shadowclutch/CloudRedirect/releases/latest/download/CloudRedirectCLI.exe" -OutFile $exePath

Write-Host "Unblocking file executable..." -ForegroundColor Yellow
Unblock-File -Path $exePath

Write-Host "Executing fix..." -ForegroundColor Green
& $exePath /stfixer
