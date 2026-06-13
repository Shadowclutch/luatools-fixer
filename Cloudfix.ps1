$exePath = "$env:TEMP\CloudRedirectCLI.exe"

# 1. Download the tool from the repository release
Invoke-WebRequest -Uri "https://github.com/Selectively11/CloudRedirect/releases/latest/download/CloudRedirectCLI.exe" -OutFile $exePath

# 2. Run the application with the /stfixer argument
& $exePath /stfixer
