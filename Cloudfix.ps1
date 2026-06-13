[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$exePath = "$env:TEMP\CloudRedirectCLI.exe"

# Clean up any leftover partial file downloads if they exist
if (Test-Path $exePath) { Remove-Item $exePath -Force -ErrorAction SilentlyContinue }

Write-Host "Fetching latest release URL from GitHub API..." -ForegroundColor Cyan
try {
    # 1. Use the GitHub API to get the asset URL dynamically (Selectively's approach)
    $repoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/Shadowclutch/CloudRedirect/releases/latest"
    $downloadUrl = ($repoInfo.assets | Where-Object { $_.name -like "*CloudRedirectCLI*.exe" }).browser_download_url

    if (-not $downloadUrl) {
        throw "Could not find CloudRedirectCLI.exe in the latest release assets."
    }

    Write-Host "Downloading CloudRedirect from Shadowclutch assets..." -ForegroundColor Cyan
    # 2. Use WebClient to bypass connection resets
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $exePath)
    
    Write-Host "Unblocking file executable..." -ForegroundColor Yellow
    Unblock-File -Path $exePath

    Write-Host "Executing fix..." -ForegroundColor Green
    & $exePath /stfixer
}
catch {
    Write-Host "An error occurred during execution." -ForegroundColor Red
    Write-Host "Error Details: $_" -ForegroundColor DarkRed
}
