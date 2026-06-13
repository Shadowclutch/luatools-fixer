# Tool Suite by Shadowclutch | github.com/Shadowclutch
# Based on luatools by piqseu
# Credits: waike, Skyflare, SelectivelyGood, Peron, clem.la, melly

# Anyone seeing this? well don't waste time improving this script.
# It's messy and just temporary until i get the new version.

param(
    [string]$DownloadLink, # Overwrites the download link (give a direct link)
    [string]$PluginName, # Overwrites the plugin name
    [int]$Branch # 1 for luatools, 2 for steamtools-collection (overwrites the above two options)
)

## Configure this
$Host.UI.RawUI.WindowTitle = "Luatools plugin installer | .gg/luatools"
$name = "luatools" # automatic first letter uppercase included
$link = "https://github.com/madoiscool/ltsteamplugin/releases/latest/download/ltsteamplugin.zip"
$milleniumTimer = 5 # in seconds for auto-installation

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Hidden defines
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$upperName = $name.Substring(0, 1).ToUpper() + $name.Substring(1).ToLower()
if ( $DownloadLink ) {
    $link = $DownloadLink
}
if ( $PluginName ) {
    $name = $PluginName
}


# Second option to get steamtools-collection plugin
# use $branch = 2 ; irm ... | iex
if ($br -eq 2 -or $Branch -eq 2) {
    $name = "steamtools-collection"
    $link = "https://github.com/clemdotla/steamtools-collection/releases/download/Latest/steamtools-collection.zip"
}


#### Logging defines ####
function Log {
    param ([string]$Type, [string]$Message, [boolean]$NoNewline = $false)

    $Type = $Type.ToUpper()
    switch ($Type) {
        "OK" { $foreground = "Green" }
        "INFO" { $foreground = "Cyan" }
        "ERR" { $foreground = "Red" }
        "WARN" { $foreground = "Yellow" }
        "LOG" { $foreground = "Magenta" }
        "AUX" { $foreground = "DarkGray" }
        default { $foreground = "White" }
    }

    $date = Get-Date -Format "HH:mm:ss"
    $prefix = if ($NoNewline) { "`r[$date] " } else { "[$date] " }
    Write-Host $prefix -ForegroundColor "Cyan" -NoNewline

    Write-Host [$Type] $Message -ForegroundColor $foreground -NoNewline:$NoNewline
}
Log "WARN" "Hey! Just letting you know that i'm working on a new version combining various scripts of the server"
Log "AUX" "Will include language support on THIS script too, luv y'all brazilians"
Write-Host

# To hide IEX blue box thing
$ProgressPreference = 'SilentlyContinue'



Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force


#### Requirements part ####

# Steamtools check
# TODO: Make this prettier?
function CheckSteamtools {
    $files = @( "dwmapi.dll", "xinput1_4.dll" )
    foreach($file in $files) {
        if (!( Test-Path (Join-Path $steam $file) )) {
            return $false
        }
    }
    
    return $true
}

$path = Join-Path $steam "dwmapi.dll"
if ( CheckSteamtools ) {
    Log "INFO" "Steamtools already installed"
}
else {
    # Filtering the installation script
    # $script = Invoke-RestMethod "https://steam.run"
    $script = Invoke-RestMethod "https://luatools.vercel.app/st.ps1"
    $keptLines = @()

    foreach ($line in $script -split "`n") {
        $conditions = @( # Removes lines containing one of those
            ($line -imatch "Start-Process" -and $line -imatch "steam"),
            ($line -imatch "steam\.exe"),
            ($line -imatch "Start-Sleep" -or $line -imatch "Write-Host"),
            ($line -imatch "cls" -or $line -imatch "exit"),
            ($line -imatch "Stop-Process" -and -not ($line -imatch "Get-Process"))
        )
        
        if (-not($conditions -contains $true)) {
            $keptLines += $line
        }
    }

    $SteamtoolsScript = $keptLines -join "`n"
    Log "ERR" "Steamtools not found."
    
    # Retrying with a max of 5
    for ($i = 0; $i -lt 5; $i++) {

        Log "AUX" "Install it at your own risk! Close this script if you don't want to."
        Log "WARN" "Pressing any key will install steamtools (UI-less)."
        
        [void][System.Console]::ReadKey($true)
        Write-Host
        Log "WARN" "Installing Steamtools"
        
        Invoke-Expression $SteamtoolsScript *> $null

        if ( CheckSteamtools ) {
            Log "OK" "Steamtools installed"
            break
        }
        else {
            Log "ERR" "Steamtools installation failed, retrying..."
        }

    }
}

# Millenium check
$milleniumInstalling = $false
foreach ($file in @("millennium.dll", "python311.dll")) {
    if (!( Test-Path (Join-Path $steam $file) )) {
        
        # Ask confirmation to download
        Log "ERR" "Millenium not found, installation process will start in 5 seconds."
        Log "WARN" "Press any key to cancel the installation."
        
        for ($i = $milleniumTimer; $i -ge 0; $i--) {
            # Wheter a key was pressed
            if ([Console]::KeyAvailable) {
                Write-Host
                Log "ERR" "Installation cancelled by user."
                exit
            }

            Log "LOG" "Installing Millenium in $i second(s)... Press any key to cancel." $true
            Start-Sleep -Seconds 1
        }
        Write-Host



        Log "INFO" "Installing millenium"

        Invoke-Expression "& { $(Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1') } -NoLog -DontStart -SteamPath '$steam'"

        Log "OK" "Millenium done installing"
        $milleniumInstalling = $true
        break
    }
}
if ($milleniumInstalling -eq $false) { Log "INFO" "Millenium already installed" }



#### Plugin part ####
# Ensuring \Steam\plugins
if (!( Test-Path (Join-Path $steam "plugins") )) {
    New-Item -Path (Join-Path $steam "plugins") -ItemType Directory *> $null
}


$Path = Join-Path $steam "plugins\$name" # Defaulting if no install found

# Checking for plugin named "$name"
foreach ($plugin in Get-ChildItem -Path (Join-Path $steam "plugins") -Directory) {
    $testpath = Join-Path $plugin.FullName "plugin.json"
    if (Test-Path $testpath) {
        $json = Get-Content $testpath -Raw | ConvertFrom-Json
        if ($json.name -eq $name) {
            Log "INFO" "Plugin already installed, updating it"
            $Path = $plugin.FullName # Replacing default path
            break
        }
    }
}

# Installation 
$subPath = Join-Path $env:TEMP "$name.zip"

Log "LOG" "Downloading $name"
if ($DownloadLink) { Log "Aux" $($link) }
Invoke-WebRequest -Uri $link -OutFile $subPath *> $null
if ( !( Test-Path $subPath ) ) {
    Log "ERR" "Failed to download $name"
    exit
}
Log "LOG" "Unzipping $name"
try {      
    $zip = [System.IO.Compression.ZipFile]::OpenRead($subPath)
    foreach ($entry in $zip.Entries) {
        $destinationPath = Join-Path $Path $entry.FullName
        
        if (-not $entry.FullName.EndsWith('/') -and -not $entry.FullName.EndsWith('\')) {
            $parentDir = Split-Path -Path $destinationPath -Parent
            if ($parentDir -and $parentDir.Trim() -ne '') {
                $pathParts = $parentDir -replace [regex]::Escape($steam), '' -split '[\\/]' | Where-Object { $_ }
                $currentPath = $Path
                
                foreach ($part in $pathParts) {
                    $currentPath = Join-Path $currentPath $part
                    if (Test-Path $currentPath) {
                        $item = Get-Item $currentPath
                        if (-not $item.PSIsContainer) {
                            Remove-Item $currentPath -Force
                        }
                    }
                }
                
                [System.IO.Directory]::CreateDirectory($parentDir) | Out-Null
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
            }
        }
    }
    
    $zip.Dispose()
}
catch {
    write-host "Error: $($_.Exception.Message)"
    if ($zip) { $zip.Dispose() }
    Log "ERR" "Extraction failed, trying normal way"
    Expand-Archive -Path $subPath -DestinationPath $Path -Force
}


if ( Test-Path $subPath ) {
    Remove-Item $subPath -ErrorAction SilentlyContinue
}

Log "OK" "$upperName installed"


# Removing beta
$betaPath = Join-Path $steam "package\beta"
if ( Test-Path $betaPath ) {
    Remove-Item $betaPath -Recurse -Force
}
# Removing potential x32 (kinda greedy but ppl got issues and was hard to fix without knowing it was the issue, ppl don't know what they run)
$cfgPath = Join-Path $steam "steam.cfg"
if ( Test-Path $cfgPath ) {
    Remove-Item $cfgPath -Recurse -Force
}
Remove-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue


# Toggling the plugin on (+turning off updateChecking to try fixing a bug where steam doesn't start)
$configPath = Join-Path $steam "ext/config.json"
if (-not (Test-Path $configPath)) {
    $config = @{
        plugins = @{
            enabledPlugins = @($name)
        }
        general = @{
            checkForMillenniumUpdates = $false
        }
    }
    New-Item -Path (Split-Path $configPath) -ItemType Directory -Force | Out-Null
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}
else {
    $config = (Get-Content $configPath -Raw -Encoding UTF8) | ConvertFrom-Json

    function _EnsureProperty {
        param($Object, $PropertyName, $DefaultValue)
        if (-not $Object.$PropertyName) {
            $Object | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $DefaultValue -Force
        }
    }

    _EnsureProperty $config "general" @{}
    _EnsureProperty $config "general.checkForMillenniumUpdates" $false
    $config.general.checkForMillenniumUpdates = $false

    _EnsureProperty $config "plugins" @{ enabledPlugins = @() }
    _EnsureProperty $config "plugins.enabledPlugins" @()
    
    $pluginsList = @($config.plugins.enabledPlugins)
    if ($pluginsList -notcontains $name) {
        $pluginsList += $name
        $config.plugins.enabledPlugins = $pluginsList
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}
Log "OK" "Plugin enabled"


# Result showing
Write-Host
if ($milleniumInstalling) { Log "WARN" "Steam startup will be longer, don't panic and don't touch anything in steam!" }


# Start with the "-clearbeta" argument
$exe = Join-Path $steam "steam.exe"
Start-Process $exe -ArgumentList "-clearbeta"

Log "INFO" "Starting steam"
Log "WARN" "Hey so there's a bug where steam may not start"
Log "WARN" "Hopefully this script fixes it"
Log "WARN" "But i had to turn updates of millennium off."
Log "WARN" "In future, they will come back but in the meantime:"
Log "OK" "Manually check for updates of millennium if you want up to date."
Log "AUX" "Millennium is working now tho (latest version)."

# Apply branch 2 name/link (works for both -Branch 2 and menu selection)
if ($Branch -eq 2) {
    $name = "steamtools-collection"
    $link = "https://github.com/clemdotla/steamtools-collection/releases/download/Latest/steamtools-collection.zip"
    $upperName = "Steamtools-collection"
}


#### Branch 3: Spacetheme Block Remover (by waike - waike.dev) ####
if ($Branch -eq 3) {
    Log "INFO" "Spacetheme Block Remover"
    Log "AUX"  "Removes the 'get a job loser' text blocking your Steam client."
    Log "AUX"  "Credit: waike (waike.dev)"
    Blank

    $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steamPath -or -not (Test-Path $steamPath)) {
        Log "ERR" "Steam not found."
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Find all possible Spacetheme roots
    $themeRoots = @()
    $possibleRoots = @(
        "$steamPath\steamui\skins\Steam",
        "$steamPath\steamui\skins\spacetheme",
        "$steamPath\millennium\themes",
        "$steamPath\millennium\themes\Steam",
        "C:\Program Files (x86)\Steam\millennium\themes",
        "C:\Program Files (x86)\Steam\millennium\themes\Steam",
        "C:\Program Files\Steam\millennium\themes",
        "C:\Program Files\Steam\millennium\themes\Steam"
    )
    
    foreach ($root in $possibleRoots) {
        if (Test-Path $root) { $themeRoots += $root }
    }

    if ($themeRoots.Count -eq 0) {
        Log "ERR" "Spacetheme was not found in any standard location."
        Read-Host "Press Enter to exit"
        exit 1
    }

    Log "WARN" "Closing all Steam processes..."
    Get-Process -Name "steam" -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 1
    Get-Process -Name "steam","steamwebhelper","steamerrorreporter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Stop-Service "Steam Client Service" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Get-Process -Name "steam","steamwebhelper","steamservice","steamerrorreporter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $pattern = '(?is)/\*\s*\r?\n?\s*&\s*Ban piracy plugins.*?color:\s*#fff\s*!important;\s*\}'
    $patchedCount = 0

    foreach ($root in $themeRoots) {
        foreach ($cssFile in Get-ChildItem -Path $root -Recurse -Filter "*.css" -ErrorAction SilentlyContinue) {
            $content = Get-Content $cssFile.FullName -Raw
            if ($content -match $pattern) {
                $content = $content -replace $pattern, '/* Patched piracy warning block */'
                Set-Content -Path $cssFile.FullName -Value $content -NoNewline -Encoding UTF8
                $patchedCount++
                Log "OK" "Patched $($cssFile.Name)"
            }
        }
    }

    if ($patchedCount -gt 0) {
        Log "OK" "Patched $patchedCount CSS file(s)"
    } else {
        Log "INFO" "Nothing to patch — block may already be removed."
    }

    Blank
    Read-Host "Press Enter to exit"
    exit
}


#### Branch 4: Steam Offline Fix (by waike - waike.dev) ####
if ($Branch -eq 4) {
    Log "INFO" "Steam Offline Fix"
    Log "AUX"  "Steamtools sometimes forces offline mode — this attempts to fix the loading icon issue."
    Log "AUX"  "Credit: waike (waike.dev)"
    Blank

    $steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
    if (-not $steamPath) { $steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath }
    if (-not $steamPath) {
        Log "ERR" "Steam path not found."
        Read-Host "Press Enter to exit"
        exit 1
    }

    $loginUsersPath = Join-Path $steamPath 'config\loginusers.vdf'
    if (Test-Path $loginUsersPath) {
        $content = Get-Content -Path $loginUsersPath -Raw
        if ($content -match '"WantsOfflineMode"\s+"1"') {
            $newContent = $content -replace '("WantsOfflineMode"\s+)"1"', '$1"0"'
            Set-Content -Path $loginUsersPath -Value $newContent -Encoding UTF8
            Log "OK" "Fixed — WantsOfflineMode set to 0 in loginusers.vdf"
        } else {
            Log "INFO" "Steam was not set to offline mode, nothing changed."
        }
    } else {
        Log "ERR" "loginusers.vdf not found at: $loginUsersPath"
    }

    Blank
    Read-Host "Press Enter to exit"
    exit
}


#### Branch 5: ST Uninstaller (by Shadowclutch) ####
if ($Branch -eq 5) {
    $Host.UI.RawUI.WindowTitle = "Rafiekunsimp Uninstaller | github.com/Rafie-kun"

    function Get-SteamPath {
        $entries = @(
            @{ Path = "HKCU:\Software\Valve\Steam";             Key = "SteamPath"   },
            @{ Path = "HKLM:\SOFTWARE\Valve\Steam";             Key = "InstallPath" },
            @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"; Key = "InstallPath" }
        )
        foreach ($e in $entries) {
            if (Test-Path $e.Path) {
                $val = (Get-ItemProperty -Path $e.Path -Name $e.Key -ErrorAction SilentlyContinue).($e.Key)
                if ($val -and (Test-Path $val)) { return $val }
            }
        }
        return $null
    }

    $steam = Get-SteamPath
    if (-not $steam) {
        Log "ERR" "Steam not found. Is Steam installed?"
        Blank; Read-Host "Press Enter to exit"
        exit 1
    }

    function Test-PluginInstalled {
        $dir = Join-Path $steam "plugins"
        if (-not (Test-Path $dir)) { return $false }
        foreach ($p in Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue) {
            $jp = Join-Path $p.FullName "plugin.json"
            if (Test-Path $jp) {
                $j = try { Get-Content $jp -Raw | ConvertFrom-Json } catch { $null }
                if ($j -and $j.name -eq $name) { return $true }
            }
        }
        return $false
    }

    function Test-SteamtoolsInstalled {
        $hasDll = (@("dwmapi.dll","xinput1_4.dll") | Where-Object { Test-Path (Join-Path $steam $_) }).Count -gt 0
        return ($hasDll -or (Test-Path "C:\Program Files\SteamTools"))
    }

    function Test-MillenniumInstalled {
        $millenniumMarkers = @(
            "millennium.dll",
            "python311.dll",
            "python311.zip",
            "version.dll",
            "user32.dll",
            "winmm.dll",
            "millennium_bootstrap.dll",
            "ext",
            "millennium",
            "pkg"
        )
        return ($millenniumMarkers | Where-Object { Test-Path (Join-Path $steam $_) }).Count -gt 0
    }

    function Get-LuaFileCount {
        $p = Join-Path $steam "config\stplug-in"
        if (-not (Test-Path $p)) { return 0 }
        return @(Get-ChildItem -Path $p -Filter "*.lua" -ErrorAction SilentlyContinue).Count
    }

    function Uninstall-Plugin {
        Blank; Sep; Log "INFO" "Uninstalling plugin: $name"; Sep; Blank

        $dir = Join-Path $steam "plugins"
        if (-not (Test-Path $dir)) { Log "WARN" "Plugins directory not found."; return }

        $pluginPath = $null
        foreach ($p in Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue) {
            $jp = Join-Path $p.FullName "plugin.json"
            if (Test-Path $jp) {
                $j = try { Get-Content $jp -Raw | ConvertFrom-Json } catch { $null }
                if ($j -and $j.name -eq $name) { $pluginPath = $p.FullName; break }
            }
        }

        if ($pluginPath) {
            Log "LOG" "Removing: $pluginPath"
            Remove-Item $pluginPath -Recurse -Force
            Log "OK" "$upperName folder removed"
        } else {
            Log "WARN" "Plugin folder for '$name' not found — already uninstalled?"
        }

        $configPath = Join-Path $steam "ext/config.json"
        if (Test-Path $configPath) {
            $config = try { (Get-Content $configPath -Raw -Encoding UTF8) | ConvertFrom-Json } catch { $null }
            if ($config -and $config.plugins -and $config.plugins.enabledPlugins) {
                $before = @($config.plugins.enabledPlugins)
                $after  = $before | Where-Object { $_ -ne $name }
                if ($before.Count -ne $after.Count) {
                    $config.plugins.enabledPlugins = $after
                    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
                    Log "OK" "Removed '$name' from enabled plugins list"
                }
            }
        }

        Log "OK" "$upperName uninstalled"
    }

    function Uninstall-Steamtools([bool]$RemoveLuas) {
        Blank; Sep; Log "INFO" "Uninstalling SteamTools"; Sep; Blank

        $stDlls          = @("dwmapi.dll","xinput1_4.dll")
        $foundDlls       = $stDlls | Where-Object { Test-Path (Join-Path $steam $_) }
        $stAppDir        = "C:\Program Files\SteamTools"
        $stAppExists     = Test-Path $stAppDir
        $stplugPath      = Join-Path $steam "config\stplug-in"
        $luaFiles        = @()
        if (Test-Path $stplugPath) { $luaFiles = @(Get-ChildItem -Path $stplugPath -Filter "*.lua" -ErrorAction SilentlyContinue) }
        $stRegKey        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SteamTools"
        $stRegExists     = Test-Path $stRegKey
        $startMenuDir    = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\SteamTools"
        $startMenuExists = Test-Path $startMenuDir

        if ($foundDlls.Count -eq 0 -and -not $stAppExists) { Log "INFO" "SteamTools does not appear to be installed."; return }

        Log "WARN" "Killing Steam and SteamTools..."
        Get-Process -Name "steam","SteamTools" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        foreach ($f in $foundDlls) {
            $t = Join-Path $steam $f
            try   { Remove-Item -Path $t -Force -ErrorAction Stop; Log "OK" "Removed: $f" }
            catch { Log "ERR" "Could not remove $f — try running as Administrator" }
        }

        if ($RemoveLuas) {
            foreach ($lua in $luaFiles) {
                try   { Remove-Item -Path $lua.FullName -Force -ErrorAction Stop; Log "OK" "Removed: $($lua.Name)" }
                catch { Log "ERR" "Could not remove $($lua.Name)" }
            }
        }

        if ($stAppExists) {
            try   { Remove-Item -Path $stAppDir -Recurse -Force -ErrorAction Stop; Log "OK" "Removed: $stAppDir" }
            catch { Log "ERR" "Could not remove $stAppDir — try running as Administrator" }
        }

        if ($stRegExists) {
            try   { Remove-Item -Path $stRegKey -Recurse -Force -ErrorAction Stop; Log "OK" "Registry entry removed" }
            catch { Log "ERR" "Could not remove registry entry" }
        }

        if ($startMenuExists) {
            try   { Remove-Item -Path $startMenuDir -Recurse -Force -ErrorAction Stop; Log "OK" "Start Menu folder removed" }
            catch { Log "ERR" "Could not remove Start Menu folder" }
        }

        Log "OK" "SteamTools uninstalled"
    }

    function Uninstall-Millennium([bool]$KeepPlugins) {
        Blank; Sep; Log "INFO" "Uninstalling Millennium"; Sep; Blank

        $milFiles   = @(
            "millennium.dll",
            "python311.dll",
            "python311.zip",
            "version.dll",
            "user32.dll",
            "winmm.dll",
            "millennium_bootstrap.dll"
        )
        $milDirs    = @("ext","plugins","millennium","pkg")
        $foundFiles = $milFiles | Where-Object { Test-Path (Join-Path $steam $_) }
        $foundDirs  = $milDirs  | Where-Object { Test-Path (Join-Path $steam $_) }

        if ($foundFiles.Count -eq 0 -and $foundDirs.Count -eq 0) { Log "INFO" "Millennium does not appear to be installed."; return }

        Log "WARN" "Killing Steam..."
        Get-Process -Name "steam" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        foreach ($f in $foundFiles) {
            $t = Join-Path $steam $f
            try   { Remove-Item -Path $t -Force -ErrorAction Stop; Log "OK" "Removed: $f" }
            catch { Log "ERR" "Could not remove $f — try running as Administrator" }
        }

        foreach ($d in $foundDirs) {
            if ($d -eq "plugins" -and $KeepPlugins) { Log "AUX" "Skipping plugins folder"; continue }
            $t = Join-Path $steam $d
            try   { Remove-Item -Path $t -Recurse -Force -ErrorAction Stop; Log "OK" "Removed: $d\" }
            catch { Log "ERR" "Could not remove $d\ — try running as Administrator" }
        }

        Log "OK" "Millennium uninstalled"
    }

    function Restart-SteamApp {
        $exe = Join-Path $steam "steam.exe"
        if (Test-Path $exe) { Start-Process -FilePath $exe; Log "OK" "Steam started" }
        else                { Log "ERR" "steam.exe not found" }
    }

    $luaCount      = Get-LuaFileCount
    $doPlugin      = Test-PluginInstalled
    $doSteamtools  = Test-SteamtoolsInstalled
    $doMillennium  = Test-MillenniumInstalled
    $doLuas        = $false
    $doKeepPlugins = $false

    function Write-UninstallMenu {
        Clear-Host
        Write-Host ("  " + ([char]0x2588).ToString() * 61) -ForegroundColor DarkGreen
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGreen
        Write-Host " ST UNINSTALLER " -NoNewline -ForegroundColor Red
        Write-Host "]  " -NoNewline -ForegroundColor DarkGreen
        Write-Host "by Shadowclutch  |  github.com/Shadowclutch" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Blank

        function Checkbox([bool]$on) { if ($on) { "[X]" } else { "[ ]" } }
        function InstallStatus([bool]$found) { if ($found) { "[installed]" } else { "[not found]" } }

        Write-Host "  WHAT TO UNINSTALL" -ForegroundColor DarkGray
        Write-Host "  1   " -ForegroundColor Cyan -NoNewline
        Write-Host "$(Checkbox $doPlugin) Plugin ($name)        " -NoNewline
        Write-Host (InstallStatus (Test-PluginInstalled)) -ForegroundColor DarkGray

        Write-Host "  2   " -ForegroundColor Cyan -NoNewline
        Write-Host "$(Checkbox $doSteamtools) SteamTools            " -NoNewline
        Write-Host (InstallStatus (Test-SteamtoolsInstalled)) -ForegroundColor DarkGray

        Write-Host "  3   " -ForegroundColor Cyan -NoNewline
        Write-Host "$(Checkbox $doMillennium) Millennium            " -NoNewline
        Write-Host (InstallStatus (Test-MillenniumInstalled)) -ForegroundColor DarkGray

        Blank
        Write-Host "  OPTIONS" -ForegroundColor DarkGray

        $luaLabel = if ($luaCount -gt 0) { "($luaCount file(s) found)" } else { "(none found)" }
        Write-Host "  4   " -ForegroundColor Cyan -NoNewline
        Write-Host "$(Checkbox $doLuas) Remove SteamTools Lua files   " -NoNewline
        Write-Host $luaLabel -ForegroundColor DarkGray

        Write-Host "  5   " -ForegroundColor Cyan -NoNewline
        Write-Host "$(Checkbox $doKeepPlugins) Keep Millennium plugins folder"

        Blank
        Write-Host "  R   " -ForegroundColor Green -NoNewline; Write-Host "Run"
        Write-Host "  Q   " -ForegroundColor DarkGray -NoNewline; Write-Host "Quit"
        Blank
    }

    while ($true) {
        Write-UninstallMenu
        $key = Read-Host "Toggle option or run"

        switch ($key.Trim().ToUpper()) {
            "1" { $doPlugin      = -not $doPlugin }
            "2" { $doSteamtools  = -not $doSteamtools }
            "3" { $doMillennium  = -not $doMillennium }
            "4" { $doLuas        = -not $doLuas }
            "5" { $doKeepPlugins = -not $doKeepPlugins }
            "Q" { exit 0 }
            "R" {
                if (-not $doPlugin -and -not $doSteamtools -and -not $doMillennium) {
                    Clear-Host
                    Log "WARN" "Nothing selected to uninstall."
                    Blank
                    Read-Host "Press Enter to go back"
                    break
                }

                Clear-Host; Sep
                Write-Host "  Running uninstaller..." -ForegroundColor Cyan
                Sep

                if ($doPlugin)     { Uninstall-Plugin }
                if ($doSteamtools) { Uninstall-Steamtools -RemoveLuas $doLuas }
                if ($doMillennium) { Uninstall-Millennium -KeepPlugins $doKeepPlugins }

                Blank
                $restart = Read-Host "Restart Steam? (y/n)"
                if ($restart.Trim() -ieq "y") { Restart-SteamApp }

                Blank; Sep
                Write-Host "  Done!" -ForegroundColor Green
                Sep; Blank
                Read-Host "Press Enter to exit"
                exit 0
            }
        }
    }
}


#### Branch 6: Steam Bulk Fixer (by waike - waike.dev) ####
if ($Branch -eq 6) {
    Log "INFO" "Steam Bulk Fixer"
    Log "AUX"  "Runs a collection of fixes for your Steam client and Steamtools."
    Log "AUX"  "Credit: waike (waike.dev)"
    Blank

    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $IsAdmin) {
        Log "WARN" "Not running as admin — Windows Defender changes won't run."
        Blank
        $choice = Read-Host "Are you sure you want to continue? (Y/N)"
        if ($choice -notin @("Y","y")) {
            Log "ERR" "Cancelled."
            Start-Sleep -Seconds 1
            exit
        }
        Log "INFO" "Continuing..."
    }

    if ($SkipDefender) {
        Log "AUX" "Skipping Windows Defender exclusions (-SkipDefender flag set)"
        $env:SKIP_DEFENDER = "1"
    }

    Blank
    Log "INFO" "Starting..."

    $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steamPath -or -not (Test-Path $steamPath)) {
        Log "ERR" "Steam not found."
        Read-Host "Press Enter to exit"
        exit
    }

    Log "AUX" "Steam path: $steamPath"

    Log "WARN" "Closing Steam..."
    while (Get-Process steam, steamwebhelper -ErrorAction SilentlyContinue) {
        Get-Process steam, steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep 1
    }
    Log "OK" "Steam closed."

    if ($IsAdmin -and $env:SKIP_DEFENDER -ne "1") {
        Log "INFO" "Adding Defender exclusion..."
        try {
            Add-MpPreference -ExclusionPath $steamPath -ErrorAction Stop
            Log "OK" "Defender updated."
        } catch {
            Log "WARN" "Defender change failed."
        }
    } else {
        Log "AUX" "Skipping Defender changes."
    }

    Log "INFO" "Downloading DLLs..."
    $urls = @{
        "xinput1_4.dll" = "http://update.steamox.com/update"
        "dwmapi.dll"    = "http://update.steamox.com/dwmapi"
    }
    foreach ($dll in $urls.Keys) {
        $dest = Join-Path $steamPath $dll
        Log "LOG" "Getting $dll..."
        try {
            Invoke-RestMethod -Uri $urls[$dll] -OutFile $dest
            Log "OK" "$dll done."
        } catch {
            Log "ERR" "Failed to download $dll"
        }
    }
    Log "OK" "DLLs finished."

    Log "INFO" "Running Shadowclutch temporary fixer..."
    try {
        Invoke-Expression (Invoke-RestMethod "https://luatools.vercel.app/temporary-fixer.ps1")
    } catch {
        Log "WARN" "Fixer failed."
    }

    Log "INFO" "Installing Shadowclutch plugin..."
    try {
        Invoke-Expression (Invoke-RestMethod "https://luatools.vercel.app/temporary-fixer.ps1")
    } catch {
        Log "WARN" "Rafiekunsimp install failed."
    }

    Log "INFO" "Launching Steam..."
    Start-Process (Join-Path $steamPath "steam.exe")

    Blank
    Log "OK" "Done."
    Blank
    Read-Host "Press Enter to exit"
    exit
}


#### Branch 7: Steam Manifest Downloader (by Skyflare - Modified by Shadowclutch) ####
<#
.SYNOPSIS
    Steam Manifest Downloader - Downloads depot manifests for SteamTools

.DESCRIPTION
    Downloads depot manifests when SteamTools servers are unavailable.
    Parses local Lua files and fetches manifests from GitHub mirror or a
    fallback API (Morrenus or ManifestHub) depending on the mode.

.PARAMETER ApiKey
    Your ManifestHub API key (required for github+manifesthub mode).
    Can also be set via $env:MH_API_KEY.

.PARAMETER MorrenusApiKey
    Your Morrenus API key (required for github+morrenus mode).
    Can also be set via $env:MORRENUS_API_KEY.

.PARAMETER AppId
    The Steam App ID to download manifests for.
    Can also be set via $env:APP_ID.

.NOTES
    Mode is controlled by the $env:MANIFEST_MODE environment variable:
      "github"             - GitHub mirror only, no API key needed (default)
      "github+morrenus"    - GitHub first, Morrenus API as fallback
      "github+manifesthub" - GitHub first, ManifestHub API as fallback
#>

param(
    [string]$ApiKey,
    [string]$MorrenusApiKey,
    [string]$AppId
)

# Set console encoding to UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Steam Manifest Downloader (For Steamtools)"

function Write-Header {
    param([string]$Mode = "github")
    Clear-Host
    Write-Host ""
    # Clickable hyperlinks using ANSI escape sequences (works in Windows Terminal)
    $esc = [char]27
    if ($Mode -eq "github+morrenus") {
        $sourceLink = "$esc]8;;https://hubcapmanifest.com/$esc\Morrenus$esc]8;;$esc\"
        $sourcePad  = "          "
    } elseif ($Mode -eq "github+manifesthub") {
        $sourceLink = "$esc]8;;https://github.com/SteamAutoCracks/ManifestHub$esc\ManifestHub$esc]8;;$esc\"
        $sourcePad  = "       "
    } else {
        $sourceLink = "$esc]8;;https://github.com/qwe213312/k25FCdfEOoEJ42S6$esc\GitHub Mirror$esc]8;;$esc\"
        $sourcePad  = "    "
    }
    $discordLink = "$esc]8;;https://discord.gg/luatools$esc\discord.gg/luatools$esc]8;;$esc\"
    Write-Host "  +================================================================+" -ForegroundColor Cyan
    Write-Host "  |        STEAM MANIFEST DOWNLOADER (For Steamtools)              |" -ForegroundColor Cyan
    Write-Host "  |   Downloads Out-Of-Date Manifest Files From $sourceLink$sourcePad|" -ForegroundColor Cyan
    Write-Host "  |                                                                |" -ForegroundColor Cyan
    Write-Host "  |                   by $discordLink                       |" -ForegroundColor DarkCyan
    Write-Host "  +================================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label,
        [int]$Width = 40,
        [ConsoleColor]$Color = "Green"
    )

    $percent = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $filled = [math]::Floor(($Current / [math]::Max($Total, 1)) * $Width)
    $empty = $Width - $filled

    $barFilled = "#" * $filled
    $barEmpty = "-" * $empty

    Write-Host ("`r  {0} [{1}" -f $Label, $barFilled) -NoNewline
    Write-Host $barEmpty -NoNewline -ForegroundColor DarkGray
    Write-Host ("] {0}% ({1}/{2})    " -f $percent, $Current, $Total) -NoNewline
}

function Write-Status {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host "  [*] $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [+] $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "  [-] $Message" -ForegroundColor Red
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function Exit-WithPrompt {
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

function Get-SteamPath {
    $registryPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKCU:\SOFTWARE\Valve\Steam"
    )

    foreach ($path in $registryPaths) {
        try {
            $steamPath = (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue).InstallPath
            if ($steamPath -and (Test-Path $steamPath)) {
                return $steamPath
            }
        } catch {}
    }

    return $null
}

function Get-DepotIdsFromLua {
    param([string]$LuaPath)

    $depots = @()
    $content = Get-Content -Path $LuaPath -ErrorAction Stop

    foreach ($line in $content) {
        # Match addappid(depotid, digit, "key") pattern, ignoring comments
        if ($line -match 'addappid\s*\(\s*(\d+)\s*,\s*\d+\s*,\s*"[a-fA-F0-9]+"') {
            $depotId = $matches[1]
            $depots += $depotId
        }
    }

    return $depots | Select-Object -Unique
}

function Get-AppInfo {
    param([string]$AppId)

    $url = "https://api.steamcmd.net/v1/info/$AppId"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
        return $response
    } catch {
        return $null
    }
}

function Get-ManifestIdForDepot {
    param(
        [object]$AppInfo,
        [string]$AppId,
        [string]$DepotId
    )

    try {
        $depots = $AppInfo.data.$AppId.depots
        if ($depots.$DepotId -and $depots.$DepotId.manifests -and $depots.$DepotId.manifests.public) {
            return $depots.$DepotId.manifests.public.gid
        }
    } catch {}

    return $null
}

function Try-DownloadUrl {
    param(
        [string]$Url,
        [string]$OutputFile,
        [int]$MaxRetries,
        [string]$Label,
        [int]$RetryDelaySeconds = 3
    )

    $lastError = $null

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            if (Test-Path $OutputFile) {
                Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue
            }

            Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 120 -OutFile $OutputFile -ErrorAction Stop

            if (Test-Path $OutputFile) {
                $fileSize = (Get-Item $OutputFile).Length
                if ($fileSize -gt 0) {
                    return @{ Success = $true; Is404 = $false; Size = $fileSize; Attempts = $attempt }
                }
            }

            $lastError = "Empty file received"
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            if ($statusCode -eq 404) {
                if (Test-Path $OutputFile) { Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue }
                return @{ Success = $false; Is404 = $true; Error = "Not found (404)"; Attempts = $attempt }
            }
            $lastError = $_.Exception.Message
        }

        if ($attempt -lt $MaxRetries) {
            Write-Host "      Attempt $attempt failed ($Label): $lastError" -ForegroundColor DarkYellow
            Write-Host "      Retrying in ${RetryDelaySeconds}s..." -ForegroundColor DarkGray
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    return @{ Success = $false; Is404 = $false; Error = $lastError; Attempts = $MaxRetries }
}

function Download-Manifest {
    param(
        [string]$DepotId,
        [string]$ManifestId,
        [string]$OutputPath,
        [string]$Mode,
        [string]$ApiKey,
        [int]$RetryDelaySeconds = 3
    )

    $outputFile = Join-Path $OutputPath "${DepotId}_${ManifestId}.manifest"
    $githubUrl = "https://raw.githubusercontent.com/qwe213312/k25FCdfEOoEJ42S6/main/${DepotId}_${ManifestId}.manifest"

    # Always try GitHub first
    $githubResult = Try-DownloadUrl -Url $githubUrl -OutputFile $outputFile -MaxRetries 2 -Label "GitHub" -RetryDelaySeconds $RetryDelaySeconds

    if ($githubResult.Success) {
        return @{ Success = $true; FilePath = $outputFile; Size = $githubResult.Size; Attempts = $githubResult.Attempts }
    }

    # On GitHub 404 and mode has a secondary API, try it
    if ($githubResult.Is404 -and $Mode -ne "github") {
        if ($Mode -eq "github+morrenus") {
            Write-Host "      Not on GitHub, trying Morrenus..." -ForegroundColor DarkGray
            $secondaryUrl = "https://hubcapmanifest.com/api/v1/generate/manifest?depot_id=${DepotId}&manifest_id=${ManifestId}&api_key=${ApiKey}"
            $secondaryLabel = "Morrenus"
        } else {
            Write-Host "      Not on GitHub, trying ManifestHub..." -ForegroundColor DarkGray
            $secondaryUrl = "https://api.manifesthub1.filegear-sg.me/manifest?apikey=${ApiKey}&depotid=${DepotId}&manifestid=${ManifestId}"
            $secondaryLabel = "ManifestHub"
        }

        $secondaryResult = Try-DownloadUrl -Url $secondaryUrl -OutputFile $outputFile -MaxRetries 5 -Label $secondaryLabel -RetryDelaySeconds $RetryDelaySeconds

        if ($secondaryResult.Success) {
            return @{ Success = $true; FilePath = $outputFile; Size = $secondaryResult.Size; Attempts = $secondaryResult.Attempts }
        }

        return @{ Success = $false; Error = $secondaryResult.Error; Attempts = $secondaryResult.Attempts }
    }

    return @{ Success = $false; Error = $githubResult.Error; Attempts = $githubResult.Attempts }
}

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes B"
    }
}

# ===========================================================================
# MAIN SCRIPT
# ===========================================================================

if ($env:MANIFEST_MODE) {
    $resolvedMode = $env:MANIFEST_MODE
} else {
    Clear-Host
    Write-Host ""
    Write-Host "  Select download mode:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    1. Github Mirror    (No Key Required, Try This First!)" -ForegroundColor White
    Write-Host "    2. Morrenus         (Free Key from https://hubcapmanifest.com/)" -ForegroundColor White
    Write-Host "    3. ManifestHub      (Free Key from https://manifesthub1.filegear-sg.me/)" -ForegroundColor White
    Write-Host ""
    do {
        $modeChoice = Read-Host "  Enter choice (1-3)"
    } while ($modeChoice -notin @("1","2","3"))
    $resolvedMode = switch ($modeChoice) {
        "1" { "github" }
        "2" { "github+morrenus" }
        "3" { "github+manifesthub" }
    }
}

Write-Header -Mode $resolvedMode

$activeApiKey = $null

if ($resolvedMode -eq "github") {
    Write-Host "  [MODE] GitHub Only - No API key required" -ForegroundColor Yellow
} elseif ($resolvedMode -eq "github+morrenus") {
    Write-Host "  [MODE] GitHub + Morrenus - Morrenus API as fallback" -ForegroundColor Cyan
    $activeApiKey = $MorrenusApiKey
    if (-not $activeApiKey) { $activeApiKey = $env:MORRENUS_API_KEY }
    if (-not $activeApiKey) {
        Write-Host ""
        Write-Host "  How to get your Morrenus API key:" -ForegroundColor DarkGray
        Write-Host "    1. Login at https://hubcapmanifest.com/ with your Discord account" -ForegroundColor DarkGray
        Write-Host "    2. Generate your key at https://hubcapmanifest.com/api-keys/user" -ForegroundColor DarkGray
        Write-Host "    3. Or get it from LuaTools plugin settings if you set it there" -ForegroundColor DarkGray
        Write-Host ""
        $activeApiKey = Read-Host "  Enter Morrenus API Key"
    }
    if ([string]::IsNullOrWhiteSpace($activeApiKey)) {
        Write-ErrorMsg "Morrenus API Key is required!"
        Exit-WithPrompt
    }
    # Validate key format: smm_ prefix + 96 hex chars = 100 total
    if ($activeApiKey -notmatch '^smm_[0-9a-f]{96}$') {
        Write-ErrorMsg "Invalid Morrenus API key format!"
        Write-Host "  Expected: smm_ followed by 96 hex characters (total 100 chars)" -ForegroundColor DarkGray
        Exit-WithPrompt
    }
    # Validate key against Morrenus API
    Write-Host ""
    Write-Status "Validating Morrenus API key..."
    try {
        $statsResponse = Invoke-RestMethod -Uri "https://hubcapmanifest.com/api/v1/user/stats?api_key=$activeApiKey" -Method Get -TimeoutSec 15 -ErrorAction Stop
        if (-not $statsResponse.can_make_requests) {
            Write-ErrorMsg "Your Morrenus key has hit its daily limit ($($statsResponse.daily_usage)/$($statsResponse.daily_limit)). Try again tomorrow."
            Exit-WithPrompt
        }
        Write-Success "Welcome back $($statsResponse.username)! Fetching depots now!"
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        if ($statusCode -eq 401 -or $statusCode -eq 403 -or $statusCode -eq 404) {
            Write-ErrorMsg "API key not found or expired."
        } else {
            # Try to parse the body for the detail message
            try {
                $errBody = $_.ErrorDetails.Message | ConvertFrom-Json
                Write-ErrorMsg $errBody.detail
            } catch {
                Write-ErrorMsg "Failed to validate Morrenus API key: $($_.Exception.Message)"
            }
        }
        Exit-WithPrompt
    }
} elseif ($resolvedMode -eq "github+manifesthub") {
    Write-Host "  [MODE] GitHub + ManifestHub - ManifestHub API as fallback" -ForegroundColor Cyan
    $activeApiKey = $ApiKey
    if (-not $activeApiKey) { $activeApiKey = $env:MH_API_KEY }
    if (-not $activeApiKey) {
        Write-Host "  Get your API key from: " -NoNewline
        Write-Host "https://manifesthub1.filegear-sg.me/" -ForegroundColor Yellow
        Write-Host ""
        $activeApiKey = Read-Host "  Enter ManifestHub API Key"
    }
    if ([string]::IsNullOrWhiteSpace($activeApiKey)) {
        Write-ErrorMsg "ManifestHub API Key is required!"
        Exit-WithPrompt
    }
}

Write-Host ""

while ($true) {

# Get App ID (check param -> env var -> prompt)
if (-not $AppId) {
    $AppId = $env:APP_ID
}
if (-not $AppId) {
    $AppId = Read-Host "  Enter Steam AppID (Not Depot ID or DLC ID)"
}

if ([string]::IsNullOrWhiteSpace($AppId) -or $AppId -notmatch '^\d+$') {
    Write-ErrorMsg "Valid App ID is required!"
    Exit-WithPrompt
}

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor DarkGray
Write-Host ""

# Find Steam installation
Write-Status "Locating Steam installation..."
$steamPath = Get-SteamPath

if (-not $steamPath) {
    Write-ErrorMsg "Could not find Steam installation!"
    exit 1
}

Write-Success "Steam found at: $steamPath"

# Check for Lua file
$luaPath = Join-Path $steamPath "config\stplug-in\$AppId.lua"
Write-Status "Looking for Lua file: $luaPath"

if (-not (Test-Path $luaPath)) {
    Write-Host ""
    Write-ErrorMsg "Lua file not present for AppID $AppId"
    Write-Host "  Expected path: $luaPath" -ForegroundColor DarkGray
    exit 1
}

Write-Success "Lua file found!"
Write-Host ""

# Parse Lua file for depot IDs
Write-Status "Parsing Lua file for depot IDs..."
$depotIds = Get-DepotIdsFromLua -LuaPath $luaPath

if ($depotIds.Count -eq 0) {
    Write-ErrorMsg "No depot IDs found in Lua file!"
    exit 1
}

Write-Success "Found $($depotIds.Count) depot ID(s) in Lua file"
Write-Host ""

# Display found depot IDs
Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  | Depot IDs found:                                              |" -ForegroundColor DarkGray
$depotList = ($depotIds -join ", ")
if ($depotList.Length -gt 55) {
    $depotList = $depotList.Substring(0, 52) + "..."
}
$paddedDepotList = $depotList.PadRight(60)
Write-Host "  | $paddedDepotList|" -ForegroundColor White
Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""

# Get app info from SteamCMD API
Write-Status "Fetching app info from SteamCMD API..."
$appInfo = Get-AppInfo -AppId $AppId

if (-not $appInfo -or $appInfo.status -ne "success") {
    Write-ErrorMsg "Failed to fetch app info from SteamCMD API!"
    exit 1
}

Write-Success "App info retrieved successfully"
Write-Host ""

# Match depot IDs with manifest IDs
Write-Status "Matching depot IDs with manifest IDs..."
$downloadQueue = @()

foreach ($depotId in $depotIds) {
    $manifestId = Get-ManifestIdForDepot -AppInfo $appInfo -AppId $AppId -DepotId $depotId

    if ($manifestId) {
        $downloadQueue += @{
            DepotId = $depotId
            ManifestId = $manifestId
        }
    }
}

if ($downloadQueue.Count -eq 0) {
    Write-WarningMsg "No matching manifests found for any depot IDs!"
    exit 1
}

Write-Success "Found $($downloadQueue.Count) depot(s) with available manifests"
Write-Host ""

# Prepare output directory
$depotCachePath = Join-Path $steamPath "depotcache"
if (-not (Test-Path $depotCachePath)) {
    New-Item -ItemType Directory -Path $depotCachePath -Force | Out-Null
}

Write-Status "Output directory: $depotCachePath"
Write-Host ""

# ===========================================================================
# DOWNLOAD SECTION
# ===========================================================================

Write-Host "  ================================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  DOWNLOADING MANIFESTS" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$skippedCount = 0
$failedDepots = @()
$totalSize = 0
$startTime = Get-Date

for ($i = 0; $i -lt $downloadQueue.Count; $i++) {
    $item = $downloadQueue[$i]
    $depotId = $item.DepotId
    $manifestId = $item.ManifestId

    # Update overall progress
    Write-Host ""
    Write-ProgressBar -Current ($i) -Total $downloadQueue.Count -Label "Overall Progress" -Color Cyan
    Write-Host ""
    Write-Host ""

    # Check if manifest up-to-date
    $existingFile = Join-Path $depotCachePath "${depotId}_${manifestId}.manifest"
    if (Test-Path $existingFile) {
        $existingSize = (Get-Item $existingFile).Length
        if ($existingSize -gt 0) {
            $skippedCount++
            $sizeStr = Format-FileSize -Bytes $existingSize
            Write-Host "  [=] Depot $depotId - Not Out-Of-Date ($sizeStr), skipping" -ForegroundColor DarkCyan
            continue
        }
    }

    # Show current download info
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray
    $depotLine = "Downloading: Depot $depotId"
    $manifestLine = "Manifest ID: $manifestId"
    Write-Host ("  | {0,-62}|" -f $depotLine) -ForegroundColor Yellow
    Write-Host ("  | {0,-62}|" -f $manifestLine) -ForegroundColor White
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray

    # Download the manifest
    $result = Download-Manifest -DepotId $depotId -ManifestId $manifestId -OutputPath $depotCachePath -Mode $resolvedMode -ApiKey $activeApiKey

    if ($result.Success) {
        $successCount++
        $totalSize += $result.Size
        $sizeStr = Format-FileSize -Bytes $result.Size
        $retryInfo = if ($result.Attempts -gt 1) { " [Attempt $($result.Attempts)]" } else { "" }
        Write-Success "Depot $depotId - Downloaded ($sizeStr)$retryInfo"
    } else {
        $failedDepots += @{
            DepotId = $depotId
            ManifestId = $manifestId
            Error = $result.Error
        }
        Write-ErrorMsg "Depot $depotId - Failed after $($result.Attempts) attempts: $($result.Error)"
    }
}

# Final progress update
Write-Host ""
Write-ProgressBar -Current $downloadQueue.Count -Total $downloadQueue.Count -Label "Overall Progress" -Color Cyan
Write-Host ""

$endTime = Get-Date
$elapsed = $endTime - $startTime

# ===========================================================================
# SUMMARY
# ===========================================================================

Write-Host ""
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  DOWNLOAD COMPLETE" -ForegroundColor Cyan
Write-Host ""
Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |                         SUMMARY                               |" -ForegroundColor DarkGray
Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray

$successText = "Downloaded:    $successCount"
Write-Host ("  |  {0,-60}|" -f $successText) -ForegroundColor Green

$skippedText = "Skipped:       $skippedCount (up-to-date)"
Write-Host ("  |  {0,-60}|" -f $skippedText) -ForegroundColor DarkCyan

$failedText = "Failed:        $($failedDepots.Count)"
$failedColor = if ($failedDepots.Count -gt 0) { "Red" } else { "Green" }
Write-Host ("  |  {0,-60}|" -f $failedText) -ForegroundColor $failedColor

$totalText = "Total:         $($downloadQueue.Count) depots"
Write-Host ("  |  {0,-60}|" -f $totalText) -ForegroundColor White

$sizeText = "Downloaded:    $(Format-FileSize -Bytes $totalSize)"
Write-Host ("  |  {0,-60}|" -f $sizeText) -ForegroundColor White

$timeText = "Time Elapsed:  $($elapsed.ToString('mm\:ss'))"
Write-Host ("  |  {0,-60}|" -f $timeText) -ForegroundColor White

$outputText = "Output:        $depotCachePath"
if ($outputText.Length -gt 60) {
    $outputText = $outputText.Substring(0, 57) + "..."
}
Write-Host ("  |  {0,-60}|" -f $outputText) -ForegroundColor White

Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkGray

# Show failed depots if any
if ($failedDepots.Count -gt 0) {
    Write-Host ""
    Write-Host "  FAILED DOWNLOADS:" -ForegroundColor Red
    Write-Host ""
    foreach ($failed in $failedDepots) {
        Write-Host "    Depot $($failed.DepotId) (Manifest: $($failed.ManifestId))" -ForegroundColor Red
        Write-Host "    Error: $($failed.Error)" -ForegroundColor DarkRed
        Write-Host ""
    }
}

Write-Host ""
Write-Host "  What would you like to do next?" -ForegroundColor Cyan
Write-Host ""
Write-Host "    1. Process another AppID" -ForegroundColor White
Write-Host "    2. Done! (close PowerShell)" -ForegroundColor White
Write-Host ""
do {
    $nextChoice = Read-Host "  Enter choice (1-2)"
} while ($nextChoice -notin @("1","2"))

if ($nextChoice -eq "2") { break }

$AppId = $null
Write-Header -Mode $resolvedMode
Write-Host ""

} # end while ($true)

exit 0




#### Branch 8: No Internet Connection Fix (Program by SelectivelyGood | Script by Peron) ####
if ($Branch -eq 8) {
    $Host.UI.RawUI.WindowTitle = "CloudRedirect Installer | github.com/Rafie-kun"

    # ---- Branch 8: CloudRedirect Installer (by SelectivelyGood | Script by Peron) ----

    # ==============================
    # CloudRedirect Installer
    # ==============================
    $Host.UI.RawUI.WindowTitle = "CloudRedirect Installer | github.com/Rafie-kun"

    # ===================== LOGGING =====================
    function Log {
        param (
            [string]$Type,
            [string]$Message,
            [boolean]$NoNewline = $false
        )
        $Type = $Type.ToUpper()
        $color = switch ($Type) {
            "OK"   { "Green" }
            "INFO" { "Cyan" }
            "ERR"  { "Red" }
            "WARN" { "Yellow" }
            "LOG"  { "Magenta" }
            default { "White" }
        }
        $date = Get-Date -Format "HH:mm:ss"
        $prefix = if ($NoNewline) { "`r[$date] " } else { "[$date] " }
        Write-Host $prefix -ForegroundColor Cyan -NoNewline
        Write-Host "[$Type] $Message" -ForegroundColor $color -NoNewline:$NoNewline
    }

    # ===================== STEAM DETECTION =====================
    Log "INFO" "Searching for Steam installation..."

    function Find-SteamPath {
        $PossiblePaths = @()
        try {
            $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue
            if ($reg.InstallPath) { $PossiblePaths += $reg.InstallPath }
        } catch {}

        try {
            $reg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
            if ($reg.SteamPath) { $PossiblePaths += $reg.SteamPath -replace '\\\\', '\' }
        } catch {}

        $DefaultPath = "C:\Program Files (x86)\Steam"
        if (Test-Path $DefaultPath) { $PossiblePaths += $DefaultPath }

        $PossiblePaths = $PossiblePaths | Select-Object -Unique | Where-Object { Test-Path $_ }

        if ($PossiblePaths.Count -eq 0) {
            Log "ERR" "Steam installation not found. Please install Steam first."
            exit 1
        }

        $SteamPath = $PossiblePaths[0]
        Log "OK" "Steam found at: $SteamPath"
        return $SteamPath
    }

    $steam = Find-SteamPath

    # ===================== CLOSE STEAM =====================
    Log "INFO" "Closing Steam if running..."
    Get-Process -Name "steam" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
    Write-Host ""

    # ===================== DOWNLOAD LATEST FILES =====================
    Log "INFO" "Fetching latest CloudRedirect files..."

    $ApiUrl = "https://api.github.com/repos/Selectively11/CloudRedirect/releases/latest"
    $CliFile = Join-Path $env:TEMP "CloudRedirectCLI.exe"
    $DllFile = Join-Path $env:TEMP "cloud_redirect.dll"

    try {
        $Release = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing -ErrorAction Stop
        Log "LOG" "Latest version: $($Release.tag_name)"

        # Download CloudRedirectCLI.exe
        $CliAsset = $Release.assets | Where-Object { $_.name -eq "CloudRedirectCLI.exe" } | Select-Object -First 1
        if ($CliAsset) {
            Log "LOG" "Downloading CloudRedirectCLI.exe..."
            Invoke-WebRequest -Uri $CliAsset.browser_download_url -OutFile $CliFile -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            Log "OK" "CloudRedirectCLI.exe downloaded"
        }

        # Download cloud_redirect.dll
        $DllAsset = $Release.assets | Where-Object { $_.name -eq "cloud_redirect.dll" } | Select-Object -First 1
        if ($DllAsset) {
            Log "LOG" "Downloading cloud_redirect.dll..."
            Invoke-WebRequest -Uri $DllAsset.browser_download_url -OutFile $DllFile -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            Log "OK" "cloud_redirect.dll downloaded"
        }
    }
    catch {
        Log "ERR" "Failed to download latest files"
        Log "ERR" $_.Exception.Message
        exit 1
    }

    # ===================== EXECUTE CLI =====================
    for ($i = 5; $i -ge 1; $i--) {
        Log "INFO" "Starting CloudRedirect Fixer in $i second$(if($i -gt 1){'s'})..." $true
        Start-Sleep -Seconds 1
    }
    Write-Host ""

    Log "INFO" "Running CloudRedirect Fixer..."
    try {
        & $CliFile /stfixer
        Log "OK" "CloudRedirectCLI executed successfully"
    }
    catch {
        Log "ERR" "Error while executing CloudRedirectCLI"
        Log "ERR" $_.Exception.Message
    }

    # ===================== INSTALL DLL =====================
    Log "INFO" "Installing cloud_redirect.dll to Steam folder..."
    $TargetDll = Join-Path $steam "cloud_redirect.dll"

    try {
        Copy-Item -Path $DllFile -Destination $TargetDll -Force -ErrorAction Stop
        Log "OK" "cloud_redirect.dll installed successfully"
    }
    catch {
        Log "ERR" "Failed to copy cloud_redirect.dll"
        Log "ERR" $_.Exception.Message
    }

    # ===================== CLEANUP =====================
    Start-Sleep -Seconds 2
    Log "INFO" "Cleaning temporary files..."
    Remove-Item -Path $CliFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $DllFile -Force -ErrorAction SilentlyContinue
    Log "OK" "Temporary files removed"

    Write-Host ""

    # ===================== FINAL =====================
    Log "OK" "Operation completed successfully!"
    Log "WARN" "Steam startup may take longer than usual."
    Write-Host ""

    $exe = Join-Path $steam "steam.exe"
    if (Test-Path $exe) {
        Log "INFO" "Starting Steam..."
        Start-Process $exe -ArgumentList "-clearbeta"
    }

    Write-Host ""
    Log "INFO" "Press any key to close this window..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit

    # ---- Return to main menu after Branch 8 ----
    $Host.UI.RawUI.WindowTitle = "Shadowclutch Tool Suite | github.com/Shadowclutch"
    while ($true) {
        Write-MainMenu
        $sel = Read-Host "Select an option"
        switch ($sel.Trim().ToUpper()) {
            "1" { $Branch = 1; break }
            "2" { $Branch = 2; break }
            "3" { $Branch = 3; break }
            "4" { $Branch = 4; break }
            "5" { $Branch = 5; break }
            "6" {
                $Branch = 6
                $defChoice = Read-Host "Skip Windows Defender exclusions? (y/N)"
                if ($defChoice.Trim() -ieq "y") { $SkipDefender = $true }
                break
            }
            "7" { $Branch = 7; break }
            "8" { $Branch = 8; break }
            "9" { $Branch = 9; break }
            "10" { $Branch = 10; break }
            "11" { $Branch = 11; break }
            "Q" { exit 0 }
            default { continue }
        }
        if ($Branch -ne 0) { break }
    }
    Blank
    continue MainLoop
}



#### Branch 9: Download / Launch CloudRedirect GUI (App by SelectivelyGood | Script by Shadowclutch) ####
if ($Branch -eq 9) {
    $Host.UI.RawUI.WindowTitle = "CloudRedirect GUI | github.com/Shadowclutch"

    $cloudRedirectDir  = "C:\Program Files (x86)\Steam\CloudRedirect"
    $cloudRedirectExe  = Join-Path $cloudRedirectDir "CloudRedirect.exe"
    $cloudRedirectUrl  = "https://github.com/Selectively11/CloudRedirect/releases/latest/download/CloudRedirect.exe"

    function Write-CloudRedirectHeader {
        Clear-Host
        Write-Host ("  " + ([char]0x2588).ToString() * 61) -ForegroundColor DarkGreen
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGreen
        Write-Host " CLOUDREDIRECT GUI " -NoNewline -ForegroundColor Cyan
        Write-Host "]  " -NoNewline -ForegroundColor DarkGreen
        Write-Host "App by SelectivelyGood  |  Script by Shadowclutch" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Downloads and launches CloudRedirect — fixes Steam connectivity issues." -ForegroundColor White
        Write-Host ""
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Blank
    }

    function Get-CloudRedirectInstalled {
        return (Test-Path $cloudRedirectExe)
    }

    function Write-CloudRedirectMenu {
        Write-CloudRedirectHeader
        $installed = Get-CloudRedirectInstalled
        $statusText  = if ($installed) { "[INSTALLED]" } else { "[NOT INSTALLED]" }
        $statusColor = if ($installed) { "Green" } else { "Red" }

        Write-Host "  Path:   " -NoNewline -ForegroundColor DarkGray
        Write-Host $cloudRedirectDir -ForegroundColor White
        Write-Host "  Status: " -NoNewline -ForegroundColor DarkGray
        Write-Host $statusText -ForegroundColor $statusColor
        Blank
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Blank

        Write-Host "  " -NoNewline
        Write-Host " 1 " -NoNewline -ForegroundColor Black -BackgroundColor Green
        Write-Host "  Download & Launch CloudRedirect  " -NoNewline -ForegroundColor White
        Write-Host "(always gets latest)" -ForegroundColor DarkGray

        Write-Host "  " -NoNewline
        Write-Host " 2 " -NoNewline -ForegroundColor Black -BackgroundColor Cyan
        if ($installed) {
            Write-Host "  Launch CloudRedirect" -ForegroundColor White
        } else {
            Write-Host "  Launch CloudRedirect  " -NoNewline -ForegroundColor DarkGray
            Write-Host "(download first)" -ForegroundColor DarkGray
        }

        Blank
        Write-Host "  " -NoNewline
        Write-Host " Q " -NoNewline -ForegroundColor Black -BackgroundColor DarkRed
        Write-Host "  Back to Main Menu" -ForegroundColor DarkGray
        Blank
    }

    while ($true) {
        Write-CloudRedirectMenu
        $crChoice = Read-Host "Select an option"

        switch ($crChoice.Trim().ToUpper()) {
            "1" {
                Clear-Host
                Sep
                Write-Host "  Downloading CloudRedirect..." -ForegroundColor Cyan
                Sep
                Blank

                Log "INFO" "Creating install directory..."
                try {
                    New-Item -Path $cloudRedirectDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Log "OK" "Directory ready: $cloudRedirectDir"
                } catch {
                    Log "ERR" "Could not create directory: $($_.Exception.Message)"
                    Blank
                    Read-Host "Press Enter to go back"
                    break
                }

                Log "INFO" "Downloading CloudRedirect.exe from GitHub..."
                try {
                    Invoke-WebRequest -Uri $cloudRedirectUrl -OutFile $cloudRedirectExe -ErrorAction Stop
                    Log "OK" "Saved to: $cloudRedirectExe"
                } catch {
                    Log "ERR" "Download failed: $($_.Exception.Message)"
                    Blank
                    Read-Host "Press Enter to go back"
                    break
                }

                Blank
                Log "INFO" "Launching CloudRedirect..."
                try {
                    Start-Process -FilePath $cloudRedirectExe -ErrorAction Stop
                    Log "OK" "CloudRedirect launched."
                } catch {
                    Log "ERR" "Failed to launch CloudRedirect: $($_.Exception.Message)"
                }

                Blank
                Read-Host "Press Enter to go back to the menu"
                break
            }
            "2" {
                if (-not (Get-CloudRedirectInstalled)) {
                    Clear-Host
                    Sep
                    Log "WARN" "CloudRedirect is not installed yet."
                    Log "INFO" "Please use option 1 to download it first."
                    Sep
                    Blank
                    Read-Host "Press Enter to go back"
                    break
                }

                Clear-Host
                Sep
                Write-Host "  Launching CloudRedirect..." -ForegroundColor Cyan
                Sep
                Blank

                Log "INFO" "Starting CloudRedirect from: $cloudRedirectExe"
                try {
                    Start-Process -FilePath $cloudRedirectExe -ErrorAction Stop
                    Log "OK" "CloudRedirect launched."
                } catch {
                    Log "ERR" "Failed to launch CloudRedirect: $($_.Exception.Message)"
                }

                Blank
                Read-Host "Press Enter to go back to the menu"
                break
            }
            "Q" {
                $Host.UI.RawUI.WindowTitle = "Shadowclutch Tool Suite | github.com/Shadowclutch"

                while ($true) {
                    Write-MainMenu
                    $sel = Read-Host "Select an option"
                    switch ($sel.Trim().ToUpper()) {
                        "1" { $Branch = 1; break }
                        "2" { $Branch = 2; break }
                        "3" { $Branch = 3; break }
                        "4" { $Branch = 4; break }
                        "5" { $Branch = 5; break }
                        "6" {
                            $Branch = 6
                            $defChoice = Read-Host "Skip Windows Defender exclusions? (y/N)"
                            if ($defChoice.Trim() -ieq "y") { $SkipDefender = $true }
                            break
                        }
                        "7" { $Branch = 7; break }
                        "8" { $Branch = 8; break }
                        "9" { $Branch = 9; break }
                        "10" { $Branch = 10; break }
                        "11" { $Branch = 11; break }
                        "Q" { exit 0 }
                        default { continue }
                    }
                    if ($Branch -ne 0) { break }
                }
                Blank
                continue MainLoop
            }
        }
    }
}


#### Branch 10: Millennium & SteamTools Reinstaller (by clem.la & melly) ####
if ($Branch -eq 10) {
    $Host.UI.RawUI.WindowTitle = "Millennium & ST Reinstaller | github.com/Shadowclutch"

    # ---- Branch 10: Inner functions ----

    function Write-ReinstallHeader {
        Clear-Host
        Write-Host ("  " + ([char]0x2588).ToString() * 61) -ForegroundColor DarkGreen
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Write-Host ""
        Write-Host "  [" -NoNewline -ForegroundColor DarkGreen
        Write-Host " MILLENNIUM & ST REINSTALLER " -NoNewline -ForegroundColor Cyan
        Write-Host "]  " -NoNewline -ForegroundColor DarkGreen
        Write-Host "by clem.la & melly" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Performs a clean reinstall of Millennium and SteamTools." -ForegroundColor White
        Write-Host "  Also fixes hardlink errors caused by corrupt or leftover files." -ForegroundColor White
        Write-Host ""
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Blank
    }

    function Write-ReinstallMenu {
        Write-ReinstallHeader
        Write-Host "  [" -NoNewline -ForegroundColor DarkGreen
        Write-Host " WHAT THIS DOES " -NoNewline -ForegroundColor DarkGray
        Write-Host "]" -ForegroundColor DarkGreen
        Write-Host "  [+] Stops Steam completely" -ForegroundColor Green
        Write-Host "  [+] Removes leftover/conflicting DLLs and config files" -ForegroundColor Green
        Write-Host "      (steam.cfg, beta flag, version.dll, old DLLs, Tencent cache)" -ForegroundColor DarkGray
        Write-Host "  [+] Clears SteamTools registry unlock flags" -ForegroundColor Green
        Write-Host "  [+] Adds Defender exclusions for the new DLLs" -ForegroundColor Green
        Write-Host "  [+] Downloads fresh xinput1_4.dll + dwmapi.dll" -ForegroundColor Green
        Write-Host "  [+] Reinstalls Millennium silently (no restart)" -ForegroundColor Green
        Write-Host "  [+] Sets iscdkey=false and relaunches Steam" -ForegroundColor Green
        Blank
        Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
        Blank
        Write-Host "  " -NoNewline
        Write-Host " 1 " -NoNewline -ForegroundColor Black -BackgroundColor Green
        Write-Host "  Run clean reinstall" -ForegroundColor White
        Blank
        Write-Host "  " -NoNewline
        Write-Host " Q " -NoNewline -ForegroundColor Black -BackgroundColor DarkRed
        Write-Host "  Back to Main Menu" -ForegroundColor DarkGray
        Blank
    }

    # Locate Steam path — tries all three registry locations like the rest of the script
    $b10SteamPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
    if (-not $b10SteamPath) { $b10SteamPath = (Get-ItemProperty "HKLM:\SOFTWARE\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath }
    if (-not $b10SteamPath) { $b10SteamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath }

    if (-not $b10SteamPath -or -not (Test-Path $b10SteamPath)) {
        Write-ReinstallHeader
        Log "ERR" "Steam installation not found. Is Steam installed?"
        Blank
        Read-Host "Press Enter to return to the menu"
        $Branch = 0
        $Host.UI.RawUI.WindowTitle = "Shadowclutch Tool Suite | github.com/Shadowclutch"
        while ($true) {
            Write-MainMenu
            $sel = Read-Host "Select an option"
            switch ($sel.Trim().ToUpper()) {
                "1"  { $Branch = 1; break }
                "2"  { $Branch = 2; break }
                "3"  { $Branch = 3; break }
                "4"  { $Branch = 4; break }
                "5"  { $Branch = 5; break }
                "6"  {
                    $Branch = 6
                    $defChoice = Read-Host "Skip Windows Defender exclusions? (y/N)"
                    if ($defChoice.Trim() -ieq "y") { $SkipDefender = $true }
                    break
                }
                "7"  { $Branch = 7; break }
                "8"  { $Branch = 8; break }
                "9"  { $Branch = 9; break }
                "10" { $Branch = 10; break }
                "11" { $Branch = 11; break }
                "Q"  { exit 0 }
                default { continue }
            }
            if ($Branch -ne 0) { break }
        }
        Blank
        continue MainLoop
    }

    $b10SteamToolsRegPath = 'HKCU:\Software\Valve\Steamtools'
    $b10LocalPath         = Join-Path $env:LOCALAPPDATA "steam"

    while ($true) {
        Write-ReinstallMenu
        $b10Choice = Read-Host "Select an option"

        switch ($b10Choice.Trim().ToUpper()) {
            "1" {
                Clear-Host
                Sep
                Write-Host "  Running Millennium & SteamTools Reinstaller..." -ForegroundColor Cyan
                Sep
                Blank

                # --- Stop Steam ---
                Log "WARN" "Stopping Steam..."
                $b10ForceStop = {
                    param($procName)
                    Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    if (Get-Process $procName -ErrorAction SilentlyContinue) {
                        Start-Process cmd -ArgumentList "/c taskkill /f /im $procName.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
                    }
                }
                & $b10ForceStop "steam"
                & $b10ForceStop "steamwebhelper"
                & $b10ForceStop "steamerrorreporter"
                Start-Sleep -Seconds 1
                Log "OK" "Steam stopped."
                Blank

                # --- Ensure local appdata folder exists ---
                if (-not (Test-Path $b10LocalPath)) {
                    New-Item $b10LocalPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }

                # --- Remove leftover / conflicting files ---
                Log "INFO" "Removing conflicting files..."

                $b10FilesToRemove = @(
                    (Join-Path $b10SteamPath "steam.cfg"),
                    (Join-Path $b10SteamPath "package\beta"),
                    (Join-Path $env:LOCALAPPDATA "Microsoft\Tencent"),
                    (Join-Path $b10SteamPath "version.dll"),
                    (Join-Path $b10SteamPath "user32.dll"),
                    (Join-Path $b10SteamPath "xinput1_4.dll"),
                    (Join-Path $b10SteamPath "dwmapi.dll")
                )

                foreach ($f in $b10FilesToRemove) {
                    if (Test-Path $f) {
                        try {
                            Remove-Item -Path $f -Force -Recurse -ErrorAction Stop
                            Log "OK" "Removed: $(Split-Path $f -Leaf)"
                        } catch {
                            Log "WARN" "Could not remove: $(Split-Path $f -Leaf) — $($_.Exception.Message)"
                        }
                    }
                }
                Log "OK" "Cleanup done."
                Blank

                # --- Clear SteamTools registry unlock flags ---
                Log "INFO" "Clearing SteamTools registry flags..."
                if (-not (Test-Path $b10SteamToolsRegPath)) {
                    New-Item -Path $b10SteamToolsRegPath -Force | Out-Null
                }
                Remove-ItemProperty -Path $b10SteamToolsRegPath -Name "ActivateUnlockMode"  -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $b10SteamToolsRegPath -Name "AlwaysStayUnlocked"  -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $b10SteamToolsRegPath -Name "notUnlockDepot"       -ErrorAction SilentlyContinue
                Set-ItemProperty    -Path $b10SteamToolsRegPath -Name "iscdkey" -Value "false" -Type String
                Log "OK" "Registry flags cleared."
                Blank

                # --- Add Defender exclusions ---
                $b10XinputPath = Join-Path $b10SteamPath "xinput1_4.dll"
                $b10DwmapiPath = Join-Path $b10SteamPath "dwmapi.dll"
                Log "INFO" "Adding Defender exclusions..."
                try { Add-MpPreference -ExclusionPath $b10XinputPath -ErrorAction SilentlyContinue } catch {}
                try { Add-MpPreference -ExclusionPath $b10DwmapiPath -ErrorAction SilentlyContinue } catch {}
                Log "OK" "Exclusions added."
                Blank

                # --- Download fresh SteamTools DLLs ---
                Log "INFO" "Downloading SteamTools DLLs..."
                $b10DllMap = @{
                    $b10XinputPath = "http://update.steamcdn.com/update"
                    $b10DwmapiPath = "http://update.steamcdn.com/dwmapi"
                }
                foreach ($dest in $b10DllMap.Keys) {
                    $uri     = $b10DllMap[$dest]
                    $dllName = Split-Path $dest -Leaf
                    Log "LOG" "Downloading $dllName..."
                    try {
                        Invoke-RestMethod -Uri $uri -OutFile $dest -ErrorAction Stop
                        Log "OK" "$dllName downloaded."
                    } catch {
                        # If file already exists (old copy), back it up and retry
                        if (Test-Path $dest) {
                            Move-Item -Path $dest -Destination "$dest.old" -Force -ErrorAction SilentlyContinue
                            try {
                                Invoke-RestMethod -Uri $uri -OutFile $dest -ErrorAction SilentlyContinue
                                Log "OK" "$dllName downloaded (after backup)."
                            } catch {
                                Log "WARN" "Could not download $dllName — $($_.Exception.Message)"
                            }
                        } else {
                            Log "WARN" "Could not download $dllName — $($_.Exception.Message)"
                        }
                    }
                }
                Log "OK" "DLLs done."
                Blank

                # --- Reinstall Millennium (silent, no Steam restart) ---
                Log "INFO" "Reinstalling Millennium (silent)..."
                try {
                    $b10MillenniumInstaller = [ScriptBlock]::Create((Invoke-RestMethod "https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1"))
                    & $b10MillenniumInstaller -NoLog -DontStart -SteamPath $b10SteamPath
                    Log "OK" "Millennium reinstalled."
                } catch {
                    Log "WARN" "Millennium reinstall failed: $($_.Exception.Message)"
                    Log "WARN" "You can reinstall manually at https://steambrew.app/"
                }
                Blank

                # --- Launch Steam ---
                Log "INFO" "Launching Steam..."
                $b10SteamExe = Join-Path $b10SteamPath "steam.exe"
                if (Test-Path $b10SteamExe) {
                    Start-Process $b10SteamExe
                    Start-Process "steam://"
                    Log "OK" "Steam launched. Log in to complete activation."
                } else {
                    Log "WARN" "steam.exe not found at expected path — launch Steam manually."
                }

                Blank
                Sep
                Write-Host "  Done! Reinstall complete." -ForegroundColor Green
                Sep
                Blank
                Read-Host "Press Enter to go back to the menu"
                break
            }
            "Q" {
                $Branch = 0
                $Host.UI.RawUI.WindowTitle = "Rafiekunsimp Tool Suite | github.com/Rafie-kun"
                while ($true) {
                    Write-MainMenu
                    $sel = Read-Host "Select an option"
                    switch ($sel.Trim().ToUpper()) {
                        "1"  { $Branch = 1; break }
                        "2"  { $Branch = 2; break }
                        "3"  { $Branch = 3; break }
                        "4"  { $Branch = 4; break }
                        "5"  { $Branch = 5; break }
                        "6"  {
                            $Branch = 6
                            $defChoice = Read-Host "Skip Windows Defender exclusions? (y/N)"
                            if ($defChoice.Trim() -ieq "y") { $SkipDefender = $true }
                            break
                        }
                        "7"  { $Branch = 7; break }
                        "8"  { $Branch = 8; break }
                        "9"  { $Branch = 9; break }
                        "10" { $Branch = 10; break }
                        "11" { $Branch = 11; break }
                        "Q"  { exit 0 }
                        default { continue }
                    }
                    if ($Branch -ne 0) { break }
                }
                Blank
                continue MainLoop
            }
        }
    }
}





#### Branch 11: Steamless Game Patcher (GUI) ####
if ($Branch -eq 11) {
    $Host.UI.RawUI.WindowTitle = "Steamless Patcher | github.com/Rafie-kun"

    # =========================================================================
    # HELPERS
    # =========================================================================

    function Get-B11SteamRoot {
        foreach ($reg in @("HKCU:\Software\Valve\Steam","HKLM:\SOFTWARE\WOW6432Node\Valve\Steam","HKLM:\SOFTWARE\Valve\Steam")) {
            try {
                $v = (Get-ItemProperty $reg -Name "SteamPath" -ErrorAction Stop).SteamPath
                if ($v) { return ($v.Trim('"') -replace '/','\') }
            } catch {}
        }
        return "C:\Program Files (x86)\Steam"
    }

    function Get-B11LibraryPaths([string]$SteamRoot) {
        $libs = @($SteamRoot)
        $vdf  = Join-Path $SteamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $raw = Get-Content $vdf -Raw -ErrorAction SilentlyContinue
            [regex]::Matches($raw, '"path"\s+"([^"]+)"') | ForEach-Object {
                $p = $_.Groups[1].Value -replace '\\\\','\' -replace '/','\' 
                if ($p -and (Test-Path $p)) { $libs += $p }
            }
        }
        return $libs | Select-Object -Unique
    }

    # Build a lookup table: AppId -> installed game info (from appmanifest_*.acf files)
    function Get-B11InstalledIndex([string[]]$LibPaths) {
        $index = @{}
        foreach ($lib in $LibPaths) {
            $appsDir = Join-Path $lib "steamapps"
            if (-not (Test-Path $appsDir)) { continue }
            Get-ChildItem $appsDir -Filter "appmanifest_*.acf" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $mc    = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                    $idM   = [regex]::Match($mc, '"appid"\s+"(\d+)"')
                    $nameM = [regex]::Match($mc, '"name"\s+"([^"]+)"')
                    $dirM  = [regex]::Match($mc, '"installdir"\s+"([^"]+)"')
                    if ($idM.Success -and $nameM.Success -and $dirM.Success) {
                        $appId   = $idM.Groups[1].Value
                        $gameDir = Join-Path $lib "steamapps\common\$($dirM.Groups[1].Value)"
                        if (Test-Path $gameDir) {
                            $index[$appId] = [PSCustomObject]@{
                                AppId   = $appId
                                Name    = $nameM.Groups[1].Value
                                GameDir = $gameDir
                                LibPath = $lib
                            }
                        }
                    }
                } catch {}
            }
        }
        return $index
    }

    # Scan stplug-in — the canonical source of truth for what luas exist.
    # Files named <appid>.lua are ENABLED. Files named <appid>.lua.disabled are DISABLED.
    function Get-B11LuaFiles([string]$SteamRoot) {
        $stPluginDir = Join-Path $SteamRoot "config\stplug-in"
        $results = @()
        if (-not (Test-Path $stPluginDir)) { return $results }

        Get-ChildItem $stPluginDir -ErrorAction SilentlyContinue | ForEach-Object {
            $fname = $_.Name
            $appId = $null
            $enabled = $false

            # Enabled: exactly <digits>.lua  (one dot, ends in .lua)
            if ($fname -match '^(\d+)\.lua$') {
                $appId   = $matches[1]
                $enabled = $true
            }
            # Disabled: exactly <digits>.lua.disabled  (two dots)
            elseif ($fname -match '^(\d+)\.lua\.disabled$') {
                $appId   = $matches[1]
                $enabled = $false
            }

            if ($appId) {
                $results += [PSCustomObject]@{
                    AppId    = $appId
                    Enabled  = $enabled
                    LuaPath  = $_.FullName
                    FileName = $fname
                }
            }
        }
        return $results
    }

    # Get the exe Steam uses to launch the game — 3 strategies.
    function Get-B11LaunchExe([string]$AppId, [string]$SteamRoot, [string]$GameDir, [string]$GameName) {

        # Strategy 1: appinfo.vdf binary — find the "executable" key in the launch config section
        $vdf = Join-Path $SteamRoot "appcache\appinfo.vdf"
        if (Test-Path $vdf) {
            try {
                $bytes   = [IO.File]::ReadAllBytes($vdf)
                $idBytes = [BitConverter]::GetBytes([uint32]$AppId)
                $idx = 0
                for ($i = 0; $i -lt $bytes.Length - 4; $i++) {
                    if ($bytes[$i] -eq $idBytes[0] -and $bytes[$i+1] -eq $idBytes[1] -and
                        $bytes[$i+2] -eq $idBytes[2] -and $bytes[$i+3] -eq $idBytes[3]) { $idx = $i; break }
                }
                if ($idx -gt 0) {
                    $window  = [Math]::Min($idx + 30000, $bytes.Length - 1)
                    $str     = [System.Text.Encoding]::ASCII.GetString($bytes[$idx..$window])
                    $exeHits = [regex]::Matches($str, "\x00executable\x00([^\x00]+\.exe)")
                    foreach ($m in $exeHits) {
                        $candidate = $m.Groups[1].Value.Trim() -replace '/','\' 
                        $full = if ($candidate -match '\\') { Join-Path $GameDir $candidate }
                                else {
                                    $f = Get-ChildItem $GameDir -Filter $candidate -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                                    if ($f) { $f.FullName } else { Join-Path $GameDir $candidate }
                                }
                        if (Test-Path $full) { return $full }
                    }
                }
            } catch {}
        }

        # Strategy 2: localconfig.vdf per-user override
        $userdataDir = Join-Path $SteamRoot "userdata"
        if (Test-Path $userdataDir) {
            Get-ChildItem $userdataDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $lcPath = Join-Path $_.FullName "config\localconfig.vdf"
                if (Test-Path $lcPath) {
                    try {
                        $lc         = Get-Content $lcPath -Raw -ErrorAction SilentlyContinue
                        $appSection = [regex]::Match($lc, "(?s)`"$AppId`".*?(?=`"\d{6,}`"|$)")
                        if ($appSection.Success) {
                            $exeM = [regex]::Match($appSection.Value, '"[Ee]xe"\s+"([^"]+\.exe)"')
                            if ($exeM.Success) {
                                $rel  = $exeM.Groups[1].Value -replace '/','\' 
                                $full = if (Test-Path $rel) { $rel } else { Join-Path $GameDir $rel }
                                if (Test-Path $full) { return $full }
                            }
                        }
                    } catch {}
                }
            }
        }

        # Strategy 3: Scan game folder — prefer root-level exes matching game name, then largest
        if (Test-Path $GameDir) {
            $blacklist = 'unins|setup|redist|vcredist|directx|crash|report|UnityCrashHandler|dxsetup|vc_redist|dotnet'
            $exes = Get-ChildItem $GameDir -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch $blacklist }
            if ($exes) {
                $words  = ($GameName -replace '[^a-zA-Z0-9 ]',' ').ToLower() -split '\s+' | Where-Object { $_.Length -gt 2 }
                $scored = $exes | ForEach-Object {
                    $lower = $_.BaseName.ToLower()
                    $score = ($words | Where-Object { $lower -like "*$_*" }).Count
                    $depth = if ($_.DirectoryName -eq $GameDir) { 2 } else { 0 }
                    [PSCustomObject]@{ File = $_; Score = ($score + $depth); Size = $_.Length }
                }
                $best = ($scored | Sort-Object Score,Size -Descending | Select-Object -First 1).File
                if ($best) { return $best.FullName }
            }
        }
        return $null
    }

    # Download Steamless CLI once, cache in %TEMP%
    function Get-B11SteamlessCli {
        $tmp     = Join-Path $env:TEMP "steamless_patcher"
        $cliPath = Join-Path $tmp "Steamless.CLI.exe"
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        if (-not (Test-Path $cliPath)) {
            $zipPath = Join-Path $tmp "steamless.zip"
            Invoke-WebRequest "https://github.com/atom0s/Steamless/releases/download/v3.1.0.5/Steamless.v3.1.0.5.-.by.atom0s.zip" -OutFile $zipPath -ErrorAction Stop
            Expand-Archive $zipPath $tmp -Force
        }
        if (-not (Test-Path $cliPath)) { throw "Steamless.CLI.exe not found after extraction." }
        return $cliPath
    }

    # Run Steamless CLI against an exe, stream output to the WPF log box
    function Invoke-B11Steamless([string]$ExePath, [System.Windows.Controls.TextBox]$LogBox) {
        function B11Log([string]$msg) {
            $LogBox.Dispatcher.Invoke([action]{
                $LogBox.AppendText("$msg`n")
                $LogBox.ScrollToEnd()
            })
        }

        B11Log "Target: $ExePath"
        $tmp = Join-Path $env:TEMP "steamless_patcher"

        B11Log "Getting Steamless CLI..."
        try {
            $cliPath = Get-B11SteamlessCli
            B11Log "CLI ready."
        } catch {
            B11Log "ERROR: $($_.Exception.Message)"
            return $false
        }

        B11Log "Patching — please wait..."
        try {
            Start-Process -FilePath $cliPath -ArgumentList "`"$ExePath`"" -Wait -NoNewWindow `
                -RedirectStandardOutput "$tmp\out.txt" -RedirectStandardError "$tmp\err.txt" -ErrorAction Stop
            (Get-Content "$tmp\out.txt" -ErrorAction SilentlyContinue) | ForEach-Object { B11Log $_ }
            (Get-Content "$tmp\err.txt" -ErrorAction SilentlyContinue) | ForEach-Object { B11Log "[err] $_" }
        } catch {
            B11Log "ERROR: $($_.Exception.Message)"
            return $false
        }

        $unpacked = "$ExePath.unpacked.exe"
        if (Test-Path $unpacked) {
            B11Log "Replacing original exe..."
            try {
                Remove-Item $ExePath -Force -ErrorAction Stop
                Rename-Item $unpacked $ExePath -ErrorAction Stop
                B11Log "Done!  $([System.IO.Path]::GetFileName($ExePath)) patched successfully."
                return $true
            } catch {
                B11Log "ERROR: Could not replace exe: $($_.Exception.Message)"
                return $false
            }
        } else {
            B11Log "WARNING: No .unpacked.exe produced. The game may already be DRM-free, or Steamless does not support this exe."
            return $false
        }
    }

    # =========================================================================
    # DATA LOAD  — lua files are the primary list; installed games are the index
    # =========================================================================
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

    $b11SteamRoot  = Get-B11SteamRoot
    $b11LibPaths   = Get-B11LibraryPaths   $b11SteamRoot
    $b11Installed  = Get-B11InstalledIndex $b11LibPaths          # hashtable AppId -> game info
    $b11LuaFiles   = Get-B11LuaFiles       $b11SteamRoot         # array of lua file objects

    # Build the item list — one row per lua file
    $b11AllItems = $b11LuaFiles | ForEach-Object {
        $lua      = $_
        $appId    = $lua.AppId
        $game     = $b11Installed[$appId]    # $null if not installed
        $installed = $null -ne $game

        # Name: use manifest name if installed, otherwise just the AppId
        $displayName = if ($installed) { $game.Name } else { "AppID $appId (not installed)" }

        # EXE resolution — only possible if the game is installed
        $exePath = $null
        if ($installed) {
            $exePath = Get-B11LaunchExe $appId $b11SteamRoot $game.GameDir $game.Name
        }

        # Determine status badge and patchability
        if (-not $lua.Enabled) {
            $badge = "Disabled";      $badgeColor = "#44445a"; $canPatch = $false
        } elseif (-not $installed) {
            $badge = "Not installed"; $badgeColor = "#f59e0b"; $canPatch = $false
        } elseif (-not $exePath) {
            $badge = "EXE not found"; $badgeColor = "#f87171"; $canPatch = $false
        } else {
            $badge = "Ready";         $badgeColor = "#6bdc8a"; $canPatch = $true
        }

        [PSCustomObject]@{
            AppId        = $appId
            Name         = $displayName
            IconUrl      = "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/capsule_sm_120.jpg"
            LuaPath      = $lua.LuaPath
            LuaEnabled   = $lua.Enabled
            Installed    = $installed
            GameDir      = if ($installed) { $game.GameDir } else { $null }
            ExePath      = $exePath
            CanPatch     = $canPatch
            StatusLabel  = $badge
            StatusColor  = $badgeColor
            _ManualExe   = $null
        }
    } | Sort-Object { if ($_.CanPatch) { 0 } elseif ($_.Installed) { 1 } else { 2 } }, Name

    # =========================================================================
    # WPF XAML
    # =========================================================================
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Steamless Patcher  |  github.com/Rafie-kun"
        Width="860" Height="640"
        MinWidth="620" MinHeight="480"
        WindowStartupLocation="CenterScreen"
        Background="#0f0f14"
        FontFamily="Segoe UI"
        FontSize="13">
    <Window.Resources>
        <Style x:Key="CardStyle" TargetType="Border">
            <Setter Property="Background" Value="#16161f"/>
            <Setter Property="CornerRadius" Value="6"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
        </Style>
        <Style x:Key="LuaItemStyle" TargetType="ListBoxItem">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#c8c8d4"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1e1e2e"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#2a2a4a"/>
                    <Setter Property="Foreground" Value="#a78bfa"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#4f46e5"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#6366f1"/></Trigger>
                            <Trigger Property="IsPressed"   Value="True"><Setter Property="Background" Value="#3730a3"/></Trigger>
                            <Trigger Property="IsEnabled"   Value="False">
                                <Setter Property="Background" Value="#1e1e2e"/>
                                <Setter Property="Foreground" Value="#44445a"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1a1a26"/>
            <Setter Property="Foreground" Value="#c8c8d4"/>
            <Setter Property="BorderBrush" Value="#2a2a3f"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="CaretBrush" Value="#a78bfa"/>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="150"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="Steamless Game Patcher" FontSize="20" FontWeight="Bold" Foreground="#a78bfa" Margin="0,0,0,3"/>
            <TextBlock Foreground="#6b6b88" FontSize="11" TextWrapping="Wrap">
                Shows all .lua files in your stplug-in folder. Games marked Ready are installed and patchable.
                Not installed means the game needs to be installed on Steam first.
            </TextBlock>
        </StackPanel>

        <!-- Search + filter bar -->
        <Border Grid.Row="1" Style="{StaticResource CardStyle}">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="SearchBox" Grid.Column="0" FontSize="13"/>
                <TextBlock x:Name="SearchPH" Grid.Column="0" Text="Search by name or AppID..."
                           Foreground="#44445a" IsHitTestVisible="False"
                           VerticalAlignment="Center" Margin="10,0,0,0" FontSize="13"/>
                <CheckBox x:Name="OnlyReady" Grid.Column="1" Content="Ready only"
                          Foreground="#6b6b88" VerticalAlignment="Center" Margin="12,0,8,0"
                          IsChecked="False"/>
                <CheckBox x:Name="HideDisabled" Grid.Column="2" Content="Hide disabled"
                          Foreground="#6b6b88" VerticalAlignment="Center" Margin="0,0,8,0"
                          IsChecked="False"/>
                <TextBlock x:Name="CountLabel" Grid.Column="3"
                           Foreground="#44445a" VerticalAlignment="Center" FontSize="11"/>
            </Grid>
        </Border>

        <!-- Lua / game list -->
        <Border Grid.Row="2" Style="{StaticResource CardStyle}" Padding="0">
            <ListBox x:Name="GameList"
                     Background="Transparent" BorderThickness="0"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled"
                     VirtualizingPanel.IsVirtualizing="True"
                     VirtualizingPanel.VirtualizationMode="Recycling"
                     ItemContainerStyle="{StaticResource LuaItemStyle}">
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Grid Margin="0,1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="36"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="100"/>
                            </Grid.ColumnDefinitions>

                            <!-- Game capsule icon -->
                            <Border Grid.Column="0" Width="30" Height="30" CornerRadius="4"
                                    Background="#1a1a26">
                                <Image Source="{Binding IconUrl}" Stretch="UniformToFill"
                                       RenderOptions.BitmapScalingMode="HighQuality">
                                    <Image.Clip>
                                        <RectangleGeometry Rect="0,0,30,30" RadiusX="4" RadiusY="4"/>
                                    </Image.Clip>
                                </Image>
                            </Border>

                            <!-- Name + AppId + lua file path -->
                            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,0,8,0">
                                <TextBlock Text="{Binding Name}"
                                           Foreground="{Binding RelativeSource={RelativeSource AncestorType=ListBoxItem}, Path=Foreground}"
                                           FontWeight="Medium" TextTrimming="CharacterEllipsis"/>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="{Binding AppId}" Foreground="#44445a" FontSize="10"/>
                                    <TextBlock Text=" · " Foreground="#2a2a3f" FontSize="10"/>
                                    <TextBlock Text="{Binding LuaPath}" Foreground="#2a2a4a" FontSize="10"
                                               TextTrimming="CharacterEllipsis" MaxWidth="380"/>
                                </StackPanel>
                            </StackPanel>

                            <!-- Status badge -->
                            <Border Grid.Column="2" CornerRadius="3" Padding="7,3"
                                    HorizontalAlignment="Right" VerticalAlignment="Center"
                                    Background="#0f0f14">
                                <TextBlock Text="{Binding StatusLabel}"
                                           Foreground="{Binding StatusColor}"
                                           FontSize="10" FontWeight="SemiBold"/>
                            </Border>
                        </Grid>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>
        </Border>

        <!-- Action bar -->
        <Grid Grid.Row="3" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="SelLabel" Grid.Column="0" Foreground="#6b6b88"
                       VerticalAlignment="Center" FontSize="11" Text="No game selected" TextTrimming="CharacterEllipsis"/>
            <Button x:Name="BrowseBtn" Grid.Column="1" Content="Browse EXE"
                    Background="#1e1e2e" Margin="0,0,8,0" IsEnabled="False"/>
            <Button x:Name="PatchBtn"  Grid.Column="2" Content="Patch Game"
                    IsEnabled="False"/>
        </Grid>

        <!-- Log output -->
        <Border Grid.Row="4" Style="{StaticResource CardStyle}" Padding="10,8">
            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                <TextBox x:Name="LogBox" Background="Transparent" BorderThickness="0"
                         Foreground="#6bdc8a" FontFamily="Cascadia Code, Consolas, monospace"
                         FontSize="11" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True"/>
            </ScrollViewer>
        </Border>
    </Grid>
</Window>
"@

    # =========================================================================
    # WIRE UP CONTROLS
    # =========================================================================
    [xml]$xamlDoc = $xaml
    $reader  = [System.Xml.XmlNodeReader]::new($xamlDoc)
    $window  = [System.Windows.Markup.XamlReader]::Load($reader)

    $searchBox   = $window.FindName("SearchBox")
    $searchPH    = $window.FindName("SearchPH")
    $onlyReady   = $window.FindName("OnlyReady")
    $hideDisabled= $window.FindName("HideDisabled")
    $countLabel  = $window.FindName("CountLabel")
    $gameList    = $window.FindName("GameList")
    $selLabel    = $window.FindName("SelLabel")
    $browseBtn   = $window.FindName("BrowseBtn")
    $patchBtn    = $window.FindName("PatchBtn")
    $logBox      = $window.FindName("LogBox")

    $b11Filtered = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
    $gameList.ItemsSource = $b11Filtered

    # ---- Populate log with summary on load ----
    if ($b11LuaFiles.Count -eq 0) {
        $logBox.Text = "No .lua files found in $b11SteamRoot\config\stplug-in`nInstall SteamTools and add some games first."
    } else {
        $ready    = ($b11AllItems | Where-Object { $_.CanPatch }).Count
        $noInst   = ($b11AllItems | Where-Object { -not $_.Installed -and $_.LuaEnabled }).Count
        $disabled = ($b11AllItems | Where-Object { -not $_.LuaEnabled }).Count
        $logBox.Text = "Found $($b11LuaFiles.Count) lua files.  Ready: $ready  |  Not installed: $noInst  |  Disabled: $disabled`nSteam root: $b11SteamRoot`nstplug-in:  $(Join-Path $b11SteamRoot 'config\stplug-in')`n"
    }

    # ---- Filter function ----
    function Update-B11List {
        $q        = $searchBox.Text.Trim().ToLower()
        $readyOnly= $onlyReady.IsChecked
        $hideDis  = $hideDisabled.IsChecked
        $b11Filtered.Clear()
        $b11AllItems | Where-Object {
            ($q -eq '' -or $_.Name.ToLower() -like "*$q*" -or $_.AppId -like "*$q*") -and
            (-not $readyOnly  -or $_.CanPatch) -and
            (-not $hideDis    -or $_.LuaEnabled)
        } | ForEach-Object { $b11Filtered.Add($_) }
        $countLabel.Text = "$($b11Filtered.Count) / $($b11AllItems.Count)"
    }
    Update-B11List

    $searchBox.Add_TextChanged({
        $searchPH.Visibility = if ($searchBox.Text) { "Collapsed" } else { "Visible" }
        Update-B11List
    })
    $onlyReady.Add_Checked({   Update-B11List })
    $onlyReady.Add_Unchecked({ Update-B11List })
    $hideDisabled.Add_Checked({   Update-B11List })
    $hideDisabled.Add_Unchecked({ Update-B11List })

    # ---- Selection ----
    $gameList.Add_SelectionChanged({
        $sel = $gameList.SelectedItem
        if (-not $sel) {
            $selLabel.Text       = "No game selected"
            $patchBtn.IsEnabled  = $false
            $browseBtn.IsEnabled = $false
            return
        }

        $exeDisplay = if ($sel._ManualExe) { "(manual) $([System.IO.Path]::GetFileName($sel._ManualExe))" }
                      elseif ($sel.ExePath) { $([System.IO.Path]::GetFileName($sel.ExePath)) }
                      else { "EXE not found" }

        $instDisplay = if ($sel.Installed) { $sel.GameDir } else { "not installed on Steam" }
        $selLabel.Text = "$($sel.Name)  |  $exeDisplay  |  $instDisplay"

        # Patch is enabled only if installed AND (exe resolved OR manual set)
        $hasExe = ($sel._ManualExe -and (Test-Path $sel._ManualExe)) -or ($sel.ExePath -and (Test-Path $sel.ExePath))
        $patchBtn.IsEnabled  = $sel.Installed -and $hasExe
        $browseBtn.IsEnabled = $sel.Installed   # can browse if installed, even if auto-detect failed
    })

    # ---- Browse for EXE ----
    $browseBtn.Add_Click({
        $sel = $gameList.SelectedItem
        if (-not $sel -or -not $sel.Installed) { return }
        $dlg = [System.Windows.Forms.OpenFileDialog]::new()
        $dlg.Title            = "Select EXE for $($sel.Name)"
        $dlg.Filter           = "Executables (*.exe)|*.exe"
        $dlg.InitialDirectory = if ($sel.GameDir -and (Test-Path $sel.GameDir)) { $sel.GameDir } else { "C:\" }
        if ($dlg.ShowDialog() -eq "OK") {
            $sel._ManualExe     = $dlg.FileName
            $logBox.Text        = "Manual EXE set: $($dlg.FileName)`n"
            $patchBtn.IsEnabled = $true
            $selLabel.Text      = "$($sel.Name)  |  (manual) $([System.IO.Path]::GetFileName($dlg.FileName))"
        }
    })

    # ---- Patch button ----
    $patchBtn.Add_Click({
        $sel = $gameList.SelectedItem
        if (-not $sel) { return }

        $exePath = if ($sel._ManualExe -and (Test-Path $sel._ManualExe)) { $sel._ManualExe }
                   elseif ($sel.ExePath -and (Test-Path $sel.ExePath))   { $sel.ExePath }
                   else { $null }

        if (-not $exePath) {
            $logBox.Text = "ERROR: No valid EXE path. Use Browse EXE to set it manually.`n"
            return
        }

        $patchBtn.IsEnabled  = $false
        $browseBtn.IsEnabled = $false
        $logBox.Text         = ""

        $dispatcher = $window.Dispatcher
        $job = [System.Threading.Tasks.Task]::Run([System.Action]{
            $success = Invoke-B11Steamless $exePath $logBox
            $dispatcher.Invoke([action]{
                if ($success) {
                    $sel.StatusLabel = "Patched"
                    $sel.StatusColor = "#6bdc8a"
                } else {
                    $sel.StatusLabel = "Failed"
                    $sel.StatusColor = "#f87171"
                }
                $patchBtn.IsEnabled  = $true
                $browseBtn.IsEnabled = $true
            })
        })
    })

    # ---- Show ----
    $window.ShowDialog() | Out-Null

    # ---- Return to main menu ----
    $Host.UI.RawUI.WindowTitle = "Shadowclutch Tool Suite | github.com/Shadowclutch"
    while ($true) {
        Write-MainMenu
        $sel2 = Read-Host "Select an option"
        switch ($sel2.Trim().ToUpper()) {
            "1"  { $Branch = 1; break }
            "2"  { $Branch = 2; break }
            "3"  { $Branch = 3; break }
            "4"  { $Branch = 4; break }
            "5"  { $Branch = 5; break }
            "6"  {
                $Branch = 6
                $defChoice = Read-Host "Skip Windows Defender exclusions? (y/N)"
                if ($defChoice.Trim() -ieq "y") { $SkipDefender = $true }
                break
            }
            "7"  { $Branch = 7; break }
            "8"  { $Branch = 8; break }
            "9"  { $Branch = 9; break }
            "10" { $Branch = 10; break }
            "11" { $Branch = 11; break }
            "Q"  { exit 0 }
            default { continue }
        }
        if ($Branch -ne 0) { break }
    }
    Blank
    continue MainLoop
}


#### Branch 12: Steamless Error 54 Fix (by Peron4TheWin) ####
if ($Branch -eq 12) {
    $Host.UI.RawUI.WindowTitle = "Steamless Error 54 Fix | github.com/Shadowclutch"
    Clear-Host
    Write-Host ("  " + ([char]0x2588).ToString() * 61) -ForegroundColor DarkGreen
    Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
    Write-Host ""
    Write-Host "  [" -NoNewline -ForegroundColor DarkGreen
    Write-Host " STEAMLESS ERROR 54 FIX " -NoNewline -ForegroundColor Yellow
    Write-Host "]  " -NoNewline -ForegroundColor DarkGreen
    Write-Host "by Peron4TheWin" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Runs the Steamless patcher for a specific game to fix Error 54." -ForegroundColor White
    Write-Host "  Example AppID: " -NoNewline -ForegroundColor White
    Write-Host "1672970" -ForegroundColor Green
    Write-Host ""
    Write-Host ("  " + ([char]0x2593).ToString() * 61) -ForegroundColor Green
    Blank

    $appId = Ask "Enter the AppID of the game"
    $appId = $appId.Trim()

    if ($appId -notmatch '^\d+$') {
        Log "ERR" "Invalid AppID — must be numbers only."
        Blank
        Read-Host "Press Enter to go back"
        continue MainLoop
    }

    Log "INFO" "Running Steamless Error 54 fix for AppID $appId..."
    Blank
    try {
        & ([scriptblock]::Create((Invoke-RestMethod "https://raw.githubusercontent.com/Peron4TheWin/ps1collection/refs/heads/main/steamless.ps1"))) -AppId $appId
        Log "OK" "Steamless Error 54 fix finished."
    } catch {
        Log "ERR" "Steamless Error 54 fix failed: $($_.Exception.Message)"
    }

    Blank
    Read-Host "Press Enter to go back"
    continue MainLoop
}




if ($Branch -eq 1 -or $Branch -eq 2) {

    # Wire install-plugin vars to the main script's already-resolved values
    $Script:DownloadLink = $DownloadLink
    $Script:PluginName   = $PluginName
    $Script:Branch       = $Branch   # use the Branch already chosen in the main menu — do NOT reset it
    $Script:Culture      = $env:LT_CULTURE
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # fix SSL/TSL Error
    $Script:ProgressPreference = 'SilentlyContinue'
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $null = chcp 65001
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.Net.Http

    # ---------------------------------------------------------------------------
    # Locale defaults
    # ---------------------------------------------------------------------------
    function Get-DefaultStrings {
        param([string]$Culture)

        $tables = @{
            "en" = @{
                Title                 = "Shadowclutch plugin installer | github.com/Shadowclutch"
                SteamRegNotFound      = "Steam registry key not found. Is Steam installed?"
                SteamKilling          = "Stopping Steam"
                SteamKilled           = "Steam stopped"
                SteamtoolsFound       = "Steamtools already installed"
                SteamtoolsNotFound    = "Steamtools not found"
                SteamtoolsInstalling  = "Installing Steamtools"
                SteamtoolsInstalled   = "Steamtools installed"
                SteamtoolsRetrying    = "Steamtools installation failed, retrying..."
                SteamtoolsFailed      = "Steamtools installation failed after 5 attempts"
                MillenniumNotFound    = "Millennium not found"
                MillenniumCountdown   = "Millennium will be installed in {0} second(s)... Press any key to cancel"
                MillenniumCancelled   = "Installation cancelled by user"
                MillenniumInstalling  = "Installing Millennium"
                MillenniumInstalled   = "Millennium installed"
                MillenniumAlready     = "Millennium already installed"
                MillenniumFirstBoot   = "Steam startup may be slower on first boot -- let it sit."
                PluginUpdating        = "Plugin already installed, updating"
                PluginDownloading     = "Downloading {0}"
                PluginDownloadFailed  = "Failed to download {0}"
                PluginExtracting      = "Extracting {0}"
                PluginExtractFailed   = "Extraction failed, trying built-in Expand-Archive"
                PluginInstalled       = "{0} installed"
                PluginEnabled         = "Plugin enabled"
                RemovingBeta          = "Cleaning up beta flag"
                RemovingCfg           = "Cleaning up steam.cfg"
                RemovingForceX86      = "Cleaning up ForceX86 registry flags (32 bits)"
                StartingSteam         = "Starting Steam"
                UpdateCheckDisabled   = "Millennium auto-updates disabled to prevent startup hangs."
                UpdateCheckManual     = "Check for Millennium updates manually if you want the latest."

                ErrorTitle            = "Shadowclutch installer - ERROR"
                ErrorHeader           = "AN ERROR OCCURRED"
                ErrorBody             = "The Rafiekunsimp plugin installer encountered a problem and could not complete. This is often caused by your ISP blocking the download servers we use."
                ErrorFaq              = "Visit the server (github.com/Rafie-kun) for more information & fixes."
                ErrorExit             = "Press any key to exit."
            }

            "pt-BR" = @{
                Title                 = "Instalador do Shadowclutch | github.com/Shadowclutch"
                SteamRegNotFound      = "Steam não encontrada no registro. Sua Steam ta instalada?"
                SteamKilling          = "Parando a Steam"
                SteamKilled           = "Steam Encerrada"
                SteamtoolsFound       = "Steamtools ja instalado"
                SteamtoolsNotFound    = "Steamtools não encontrado"
                SteamtoolsInstalling  = "Instalando Steamtools"
                SteamtoolsInstalled   = "Steamtools instalado"
                SteamtoolsRetrying    = "Falha ao instalar Steamtools, tentando denovo..."
                SteamtoolsFailed      = "Falha ao instalar Steamtools após 5 tentativas"
                MillenniumNotFound    = "Millennium não encontrado"
                MillenniumCountdown   = "Millennium vai ser instalado em {0} segundo(s)... Aperte qualquer tecla pra cancelar"
                MillenniumCancelled   = "Instalação cancelada pelo usuário"
                MillenniumInstalling  = "Instalando Millennium"
                MillenniumInstalled   = "Millennium instalado"
                MillenniumAlready     = "O Millennium ja está instalado"
                MillenniumFirstBoot   = "A Steam pode demorar um pouco pra abrir pela primeira vez -- deixa rolar."
                PluginUpdating        = "Plugin já instalado, atualizando"
                PluginDownloading     = "Baixando {0}"
                PluginDownloadFailed  = "Falha ao baixar {0}"
                PluginExtracting      = "Extraindo {0}"
                PluginExtractFailed   = "Falha ao extrair, tentando via Expand-Archive"
                PluginInstalled       = "{0} instalado"
                PluginEnabled         = "Plugin habilitado"
                RemovingBeta          = "Limpando flag de beta da Steam"
                RemovingCfg           = "Apagando steam.cfg"
                RemovingForceX86      = "limpando as flags de registro do ForceX86 (32 bits)"
                StartingSteam         = "Abrindo a Steam"
                UpdateCheckDisabled   = "Atualizações automáticas do Millennium desabilitadas pra evitar travamentos ao iniciar"
                UpdateCheckManual     = "Verifique manualmente por atualizações do Millennium caso você queira a ultima versão"

                ErrorTitle            = "Instalador do Rafiekunsimp - ERRO"
                ErrorHeader           = "OCORREU UM ERRO"
                ErrorBody             = "O instalador do Rafiekunsimp encontrou um problema e não pôde ser concluído. Isso geralmente é causado pela tua internet bloqueando nossos servidores de Download"
                ErrorFaq              = "Visite o servidor (github.com/Rafie-kun) pra mais informações e detalhes em como consertar"
                ErrorExit             = "Aperte qualquer botão pra sair."
            }

            "es" = @{
                Title                 = "Instalador del plugin de Shadowclutch | github.com/Shadowclutch"
                SteamRegNotFound      = "La clave de registro de Steam no se ha encontrado. Está Steam instalado?"
                SteamKilling          = "Deteniendo Steam"
                SteamKilled           = "Steam se ha detenido"
                SteamtoolsFound       = "Steamtools ya está instalado"
                SteamtoolsNotFound    = "Steamtools no se ha encontrado"
                SteamtoolsInstalling  = "Instalando Steamtools"
                SteamtoolsInstalled   = "Steamtools se ha instalado"
                SteamtoolsRetrying    = "La instalación de Steamtools ha fallado, reintentando..."
                SteamtoolsFailed      = "La instalación de Steamtools ha fallado despues de 5 intentos"
                MillenniumNotFound    = "Millenium no encontrado"
                MillenniumCountdown   = "Millenium sera instalado en {0} segundo(s) ... Presiona cualquier tecla para cancelar"
                MillenniumCancelled   = "Instalación cancelada por el usuario"
                MillenniumInstalling  = "Instalando Millenium"
                MillenniumInstalled   = "Millenium instalado"
                MillenniumAlready     = "Millenium ya estaba instalado"
                MillenniumFirstBoot   = "La carga de steam puede ser más lenta la primera vez para cargar las dependencias -- espera pacientemente"
                PluginUpdating        = "El plugin ya esta instalado, actualizando"
                PluginDownloading     = "Descargando {0}"
                PluginDownloadFailed  = "Error al descargar {0}"
                PluginExtracting      = "Extrayendo {0}"
                PluginExtractFailed   = "Extracción fallida, intentando descomprimir archivos"
                PluginInstalled       = "{0} instalado"
                PluginEnabled         = "Plugin establecido"
                RemovingBeta          = "Limpiando indicador beta"
                RemovingCfg           = "Limpiando steam.cfg"
                RemovingForceX86      = "Limpiando los registros de ForceX86 (32 bits)"
                StartingSteam         = "Iniciando Steam"
                UpdateCheckDisabled   = "Las auto-actualizaciones de Millenium están deshabilitadas para prevenir cuelgues al inicio"
                UpdateCheckManual     = "Comprueba las actualizaciones de Millenium manualmente si necesitas la última versión"

                ErrorTitle            = "Error con el instalador Rafiekunsimp - ERROR"
                ErrorHeader           = "UN ERROR HA OCURRIDO"
                ErrorBody             = "El instalador del plugin Shadowclutch encontró un problema y no pudo completarse. Esto suele ocurrir cuando tu proveedor de internet (ISP) bloquea los servidores de descarga que utilizamos."
                ErrorFaq              = "Visita el servidor (github.com/Shadowclutch) para mas información o fixes."
                ErrorExit             = "Presiona cualquier tecla para salir."
            }

            "fr" = @{
                Title                 = "Installateur du plugin Shadowclutch | github.com/Shadowclutch"
                SteamRegNotFound      = "Clé de registre steam introuvable. Est ce que Steam est installé?"
                SteamKilling          = "Arrêt de Steam"
                SteamKilled           = "Steam arreté"
                SteamtoolsFound       = "Steamtools déjà installé"
                SteamtoolsNotFound    = "Steamtools introuvable"
                SteamtoolsInstalling  = "Installation de Steamtools"
                SteamtoolsInstalled   = "Steamtools installé"
                SteamtoolsRetrying    = "L'instalation de Steamtools a echoué, nouvelle tentative..."
                SteamtoolsFailed      = "L'installation de Steamtools a echoué apres 5 tentatives"
                MillenniumNotFound    = "Millennium introuvable"
                MillenniumCountdown   = "Millennium sera installé dans {0} seconde(s)... Appuyez sur une touche pour annuler"
                MillenniumCancelled   = "Installation annuléee par l'utilisateur"
                MillenniumInstalling  = "Installation de Millennium"
                MillenniumInstalled   = "Millennium installé"
                MillenniumAlready     = "Millennium déjà installé"
                MillenniumFirstBoot   = "Le prochain lancement de Steam sera plus long -- laisser le temps."
                PluginUpdating        = "Plugin déjà installé, mise à jour"
                PluginDownloading     = "Installation {0}"
                PluginDownloadFailed  = "Echec de l'installation {0}"
                PluginExtracting      = "Extraction {0}"
                PluginExtractFailed   = "Extraction echouée, tentative avec la fonction native"
                PluginInstalled       = "{0} installé"
                PluginEnabled         = "Plugin activé"
                RemovingBeta          = "Nettoyage de la beta"
                RemovingCfg           = "Nettoyage de steam.cfg"
                RemovingForceX86      = "Nettoyage des registres ForceX86 (32 bits)"
                StartingSteam         = "Lancement de Steam"
                UpdateCheckDisabled   = "Les mises à jour de Millennium ont été désactivée pour éviter les blocages au demarrage."
                UpdateCheckManual     = "Vérifiez manuellement les mises à jour de Millennium si vous souhaitez la derniere version."

                ErrorTitle            = "Installateur Rafiekunsimp - ERREUR"
                ErrorHeader           = "UNE ERREUR EST SURVENUE"
                ErrorBody             = "L'installation du plugin Rafiekunsimp a rencontré un problème et n'a pas pu se terminer. Ça se produit souvent quand votre fournisseur d'internet (ISP) bloque les serveurs de téléchargement."
                ErrorFaq              = "Allez voir le serveur (github.com/Rafie-kun) pour plus d'informations & corrections."
                ErrorExit             = "Appuyez sur une touche pour quitter."
            }
        }

        foreach ($key in @($Culture, $Culture.Split('-')[0], "en")) {
            if ($tables.ContainsKey($key)) {
                return $tables[$key]
            }
        }
        return $tables["en"]
    }

    # ---------------------------------------------------------------------------
    # Resolve messages based on locale
    # ---------------------------------------------------------------------------
    $DetectedCulture = if ($Script:Culture) { $Script:Culture } else { [System.Globalization.CultureInfo]::CurrentUICulture.Name }
    $L = Get-DefaultStrings -Culture $DetectedCulture

    # ---------------------------------------------------------------------------
    # Global error trap -- catches ANY terminating error and shows error page
    # MUST be placed after $L is populated so error strings are available
    # ---------------------------------------------------------------------------
    $Script:OriginalErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Stop"

    trap {
        $errMsg = $_.Exception.Message

        # Ensure $L has something even if the hashtable failed
        if (-not $L) { $L = Get-DefaultStrings -Culture "en" }

        $host.UI.RawUI.CursorPosition = @{ X=0; Y=0 }
        $errTitle = if ($L.ContainsKey("ErrorTitle")) { $L["ErrorTitle"] } else { "Shadowclutch installer - ERROR" }
        $host.UI.RawUI.WindowTitle = $errTitle
        Clear-Host

        $width = $host.UI.RawUI.WindowSize.Width

        Write-Host ("=" * $width) -ForegroundColor Red
        Write-Host ""

        $header = if ($L.ContainsKey("ErrorHeader")) { $L["ErrorHeader"] } else { "AN ERROR OCCURRED" }
        $pad = [Math]::Max(0, [int](($width - $header.Length) / 2))
        Write-Host (" " * $pad) -NoNewline
        Write-Host $header -ForegroundColor Red -BackgroundColor Black
        Write-Host ""

        $body = if ($L.ContainsKey("ErrorBody")) { $L["ErrorBody"] } else { "The installer encountered a problem." }
        Write-Host $body -ForegroundColor White
        Write-Host ""

        Write-Host ">>> " -NoNewline -ForegroundColor Yellow
        Write-Host $errMsg -ForegroundColor Gray
        Write-Host ""

        $faq = if ($L.ContainsKey("ErrorFaq")) { $L["ErrorFaq"] } else { "Visit (github.com/Shadowclutch)" }
        Write-Host $faq -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("=" * $width) -ForegroundColor Red
        Write-Host ""

        $exitMsg = if ($L.ContainsKey("ErrorExit")) { $L["ErrorExit"] } else { "Press any key to exit." }
        Write-Host $exitMsg -ForegroundColor Yellow
        try { $null = [System.Console]::ReadKey($true) } catch {}

        $ErrorActionPreference = $Script:OriginalErrorAction
        break
    }

    # ---------------------------------------------------------------------------
    # Console helpers
    # ---------------------------------------------------------------------------
    $Host.UI.RawUI.WindowTitle = $L["Title"]

    $LogColors = @{
        "OK"   = "Green"
        "INFO" = "Cyan"
        "ERR"  = "Red"
        "WARN" = "Yellow"
        "LOG"  = "Magenta"
        "AUX"  = "DarkGray"
    }

    function Write-Log {
        param(
            [ValidateSet("OK","INFO","ERR","WARN","LOG","AUX")]
            [string]$Type,
            [string]$Message,
            [switch]$NoNewline
        )
        $color = $LogColors[$Type]
        $ts = Get-Date -Format "HH:mm:ss"
        if ($NoNewline) {
            Write-Host "`r[$ts] " -ForegroundColor Cyan -NoNewline
            Write-Host "[$Type] $Message" -ForegroundColor $color -NoNewline
        } else {
            Write-Host "[$ts] " -ForegroundColor Cyan -NoNewline
            Write-Host "[$Type] $Message" -ForegroundColor $color
        }
    }

    # ---------------------------------------------------------------------------
    # Config -- use the main script's already-resolved $name / $link / $upperName
    # ---------------------------------------------------------------------------
    $Script:Name = $name
    $Script:Link = $link
    $MillenniumTimer  = 5

    # $name and $link are already set correctly by the main script
    # (branch 2 override happens before this block in the main :MainLoop)
    if ($Script:DownloadLink) { $Script:Link = $Script:DownloadLink }
    if ($Script:PluginName)   { $Script:Name = $Script:PluginName }

    $DisplayName = $upperName

    # ---------------------------------------------------------------------------
    # Steam path
    # ---------------------------------------------------------------------------
    function Get-SteamPath {
        $registries = @(
            "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
            "HKLM:\SOFTWARE\Valve\Steam",
            "HKCU:\SOFTWARE\Valve\Steam"
        )

        foreach ($reg in $registries) {
            if (!(Test-Path $reg)) { continue }

            $path = (Get-ItemProperty -Path $reg -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
            $potentialExe = Join-Path $path "steam.exe"
            if ((Test-Path $path) -and (Test-Path $potentialExe)) {
                return $path
            }
        }
        Write-Log -Type ERR -Message $L["SteamRegNotFound"]
    }

    # ---------------------------------------------------------------------------
    # Steamtools -- REQUIRED, no user choice
    # ---------------------------------------------------------------------------
    function Test-Steamtools {
        param([string]$SteamPath)
        foreach ($f in @("dwmapi.dll", "xinput1_4.dll")) {
            if (Test-Path (Join-Path $SteamPath $f)) { return $true }
        }
        return $false
    }

    # Todo: add ost compatibility
    function Install-Steamtools {
        param([string]$SteamPath)

        Write-Log -Type WARN -Message $L["SteamtoolsInstalling"]

        # ---- st.ps1 logic embedded directly (by SelectivelyGood / Rafiekunsimp) ----
        # Steam is already stopped by the main script before this is called.
        # We do NOT launch Steam here — the main script does that after everything is installed.

        $stLocalPath        = Join-Path $env:LOCALAPPDATA "steam"
        $stSteamRegPath     = 'HKCU:\Software\Valve\Steam'
        $stSteamToolsRegPath = 'HKCU:\Software\Valve\Steamtools'

        function ST-RemoveIfExists($path) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            }
        }

        # Clean up leftover get.ps1
        ST-RemoveIfExists (Join-Path $env:USERPROFILE "get.ps1")

        # Resolve the Steam path from registry (same as st.ps1 does)
        $stSteamPath = $SteamPath
        if ([string]::IsNullOrWhiteSpace($stSteamPath)) {
            if (Test-Path $stSteamRegPath) {
                $props = Get-ItemProperty -Path $stSteamRegPath -ErrorAction SilentlyContinue
                if ($props -and 'SteamPath' -in $props.PSObject.Properties.Name) {
                    $stSteamPath = $props.SteamPath
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($stSteamPath) -or -not (Test-Path $stSteamPath -PathType Container)) {
            throw $L["SteamtoolsFailed"]
        }

        $stHidPath    = Join-Path $stSteamPath "xinput1_4.dll"
        $stXinputPath = Join-Path $stSteamPath "user32.dll"
        ST-RemoveIfExists $stHidPath
        ST-RemoveIfExists $stXinputPath

        if (-not (Test-Path $stLocalPath)) {
            New-Item $stLocalPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }

        ST-RemoveIfExists (Join-Path $stSteamPath "steam.cfg")
        ST-RemoveIfExists (Join-Path $stSteamPath "packageeta")
        ST-RemoveIfExists (Join-Path $env:LOCALAPPDATA "Microsoft\Tencent")

        try { Add-MpPreference -ExclusionPath $stHidPath -ErrorAction SilentlyContinue } catch {}

        ST-RemoveIfExists (Join-Path $stSteamPath "version.dll")

        $downloadHidDll = "http://update.steamcdn.com/update"
        try {
            Invoke-RestMethod -Uri $downloadHidDll -OutFile $stHidPath -ErrorAction Stop
        } catch {
            if (Test-Path $stHidPath) {
                Move-Item -Path $stHidPath -Destination "$stHidPath.old" -Force -ErrorAction SilentlyContinue
                Invoke-RestMethod -Uri $downloadHidDll -OutFile $stHidPath -ErrorAction SilentlyContinue
            }
        }

        $stDwmapiPath    = Join-Path $stSteamPath "dwmapi.dll"
        $downloadDwmapi  = "http://update.steamcdn.com/dwmapi"
        try { Add-MpPreference -ExclusionPath $stDwmapiPath -ErrorAction SilentlyContinue } catch {}
        try {
            Invoke-RestMethod -Uri $downloadDwmapi -OutFile $stDwmapiPath -ErrorAction Stop
        } catch {
            if (Test-Path $stDwmapiPath) {
                Move-Item -Path $stDwmapiPath -Destination "$stDwmapiPath.old" -Force -ErrorAction SilentlyContinue
                Invoke-RestMethod -Uri $downloadDwmapi -OutFile $stDwmapiPath -ErrorAction SilentlyContinue
            }
        }

        if (-not (Test-Path $stSteamToolsRegPath)) {
            New-Item -Path $stSteamToolsRegPath -Force | Out-Null
        }

        Remove-ItemProperty -Path $stSteamToolsRegPath -Name "ActivateUnlockMode"  -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $stSteamToolsRegPath -Name "AlwaysStayUnlocked"  -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $stSteamToolsRegPath -Name "notUnlockDepot"      -ErrorAction SilentlyContinue
        Set-ItemProperty    -Path $stSteamToolsRegPath -Name "iscdkey" -Value "false" -Type String

        for ($attempt = 1; $attempt -le 5; $attempt++) {
            Write-Log -Type LOG -Message $L["SteamtoolsInstalling"]
            if (Test-Steamtools $SteamPath) {
                Write-Log -Type OK -Message $L["SteamtoolsInstalled"]
                return
            }
            Write-Log -Type ERR -Message $L["SteamtoolsRetrying"]
            Start-Sleep -Seconds 2
        }

        throw $L["SteamtoolsFailed"]
    }
    # ---------------------------------------------------------------------------
    # Millennium
    # ---------------------------------------------------------------------------
    function Test-Millennium {
        param([string]$SteamPath)
        foreach ($f in @("millennium.dll", "python311.dll")) {
            if (-not (Test-Path (Join-Path $SteamPath $f))) { return $false }
        }
        return $true
    }

    function Install-Millennium {
        param([string]$SteamPath)

        Write-Log -Type INFO -Message $L["MillenniumInstalling"]
        $msUrls = @(
            # "https://github.com/madoiscool/lt_api_links/raw/refs/heads/main/millennium-py.ps1",
            # "https://luatools.vercel.app/millennium-py.ps1",
            "https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1"
        )
        $msCode = $null
        foreach ($url in $msUrls) {
            try {
                $msCode = Invoke-RestMethod $url -TimeoutSec 30
                if ($msCode) { break }
            } catch {}
        }
        if (-not $msCode) { throw $L["MillenniumNotFound"] }
        Invoke-Expression "& { $msCode } -NoLog -DontStart -SteamPath '$SteamPath'"

        if (Test-Millennium $SteamPath) {
            Write-Log -Type OK -Message $L["MillenniumInstalled"]
        }
    }

    # ---------------------------------------------------------------------------
    # Plugin install / update
    # ---------------------------------------------------------------------------
    function Install-Plugin {
        param([string]$SteamPath, [string]$Name, [string]$Link)

        $pluginsDir = Join-Path $millDir "plugins"
        if (-not (Test-Path $pluginsDir)) {
            $null = New-Item -Path $pluginsDir -ItemType Directory -Force
        }

        $targetDir = Join-Path $pluginsDir $Name
        foreach ($dir in (Get-ChildItem $pluginsDir -Directory)) {
            $j = Join-Path $dir.FullName "plugin.json"
            if (Test-Path $j) {
                try {
                    $m = Get-Content $j -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($m.name -eq $Name) {
                        Write-Log -Type INFO -Message $L["PluginUpdating"]
                        $targetDir = $dir.FullName
                        break
                    }
                } catch {}
            }
        }

        $zipPath = Join-Path $env:TEMP "$Name.zip"

        Write-Log -Type LOG -Message ($L["PluginDownloading"] -f $Name)
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [System.TimeSpan]::FromSeconds(60)
        $client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Shadowclutch Installer)")

        $stream = $client.GetStreamAsync($Link).Result
        $fileStream = [System.IO.File]::Create($zipPath)
        $stream.CopyTo($fileStream)

        $fileStream.Close()
        $stream.Close()
        $client.Dispose()

        # Invoke-WebRequest -Uri $Link -OutFile $zipPath -TimeoutSec 60

        if (-not (Test-Path $zipPath)) {
            throw ($L["PluginDownloadFailed"] -f $Name)
        }

        Write-Log -Type LOG -Message ($L["PluginExtracting"] -f $Name)

        # Kill any processes that may be locking files inside the target directory
        $lockKillNames = @("steam","steamwebhelper","steamservice","steamerrorreporter","millennium","millennium.luavm64","GameOverlayUI","steamtours")
        foreach ($lkn in $lockKillNames) {
            Get-Process -Name $lkn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1

        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')) { continue }
                $dest   = Join-Path $targetDir $entry.FullName
                $parent = Split-Path $dest -Parent

                $relParts = $parent.Substring($targetDir.Length).TrimStart('\','/') -split '[/\\]' | Where-Object { $_ }
                $cursor = $targetDir
                foreach ($part in $relParts) {
                    $cursor = Join-Path $cursor $part
                    if (Test-Path $cursor) {
                        $item = Get-Item $cursor -ErrorAction SilentlyContinue
                        if ($item -and -not $item.PSIsContainer) {
                            # Retry delete up to 3 times in case file is briefly locked
                            for ($rd = 1; $rd -le 3; $rd++) {
                                try { Remove-Item $cursor -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 500 }
                            }
                        }
                    }
                }

                $null = [System.IO.Directory]::CreateDirectory($parent)

                # Retry extract up to 3 times in case file is briefly locked
                for ($re = 1; $re -le 3; $re++) {
                    try {
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
                        break
                    } catch {
                        if ($re -eq 3) { throw }
                        Start-Sleep -Milliseconds 500
                    }
                }
            }
            $zip.Dispose()
            $zip = $null
        } catch {
            if ($zip) { $zip.Dispose(); $zip = $null }
            Write-Log -Type WARN -Message $L["PluginExtractFailed"]
            Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
        }

        if (Test-Path $zipPath) { Remove-Item $zipPath -ErrorAction SilentlyContinue }
        Write-Log -Type OK -Message ($L["PluginInstalled"] -f $DisplayName)
    }

    # ---------------------------------------------------------------------------
    # Config
    # ---------------------------------------------------------------------------
    function Enable-Plugin {
        param([string]$SteamPath, [string]$Name)


        $configDir = Join-Path $millDir "config"
        $configPath = Join-Path $configDir "config.json"
        # Brang back old code cause newest wasn't working for some reason..
        # + Attempt to turn back on updates, hopefully the bug is fixed

        if (-not (Test-Path $configPath)) {
        $config = @{
            plugins = @{
                enabledPlugins = @($name)
            }
            # general = @{
            #     checkForMillenniumUpdates = $false
            # }
        }
        New-Item -Path (Split-Path $configPath) -ItemType Directory -Force | Out-Null
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    }
    else {
        $config = (Get-Content $configPath -Raw -Encoding UTF8) | ConvertFrom-Json


        function _EnsureProperty {
            param($Object, $PropertyName, $DefaultValue)
            if (-not $Object.$PropertyName) {
                $Object | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $DefaultValue -Force
            }
        }

        # _EnsureProperty $config "general" @{}
        # _EnsureProperty $config "general.checkForMillenniumUpdates" $false
        # $config.general.checkForMillenniumUpdates = $false

        _EnsureProperty $config "plugins" @{ enabledPlugins = @() }
        _EnsureProperty $config "plugins.enabledPlugins" @()

        $pluginsList = @($config.plugins.enabledPlugins)
        if ($pluginsList -notcontains $name) {
            $pluginsList += $name
            $config.plugins.enabledPlugins = $pluginsList
        }

        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    }

        Write-Log -Type OK -Message $L["PluginEnabled"]
    }

    # ---------------------------------------------------------------------------
    # Cleanup
    # ---------------------------------------------------------------------------
    function Remove-BetaFlag {
        param([string]$SteamPath)
        $beta = Join-Path $SteamPath "package\beta"
        if (Test-Path $beta) {
            Write-Log -Type AUX -Message $L["RemovingBeta"]
            Remove-Item $beta -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function Remove-ForceX86Flags {
        Write-Log -Type AUX -Message $L["RemovingForceX86"]
        @("HKCU:\Software\Valve\Steam","HKLM:\SOFTWARE\Valve\Steam","HKLM:\SOFTWARE\WOW6432Node\Valve\Steam") | ForEach-Object {
            Remove-ItemProperty -Path $_ -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue
        }
    }

    function Remove-SteamCfg {
        param([string]$SteamPath)
        $cfg = Join-Path $SteamPath "steam.cfg"
        if (Test-Path $cfg) {
            Write-Log -Type AUX -Message $L["RemovingCfg"]
            Remove-Item $cfg -Force -ErrorAction SilentlyContinue
        }
    }

    # ---------------------------------------------------------------------------
    # Main
    # ---------------------------------------------------------------------------
    function Main {

        $steamPath = Get-SteamPath
        $script:millDir = Join-Path $steamPath "millennium"
        if (-not (Test-Path $millDir)) {
            $null = New-Item -Path $millDir -ItemType Directory -Force
        }

        Write-Log -Type INFO -Message $L["SteamKilling"]
        $killNames = @("steam","steamwebhelper","steamservice","steamerrorreporter","millennium","millennium.luavm64","GameOverlayUI","steamtours")
        foreach ($kn in $killNames) {
            Get-Process -Name $kn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        # Second pass for anything that survived
        foreach ($kn in $killNames) {
            Get-Process -Name $kn -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 500

        if (Test-Steamtools $steamPath) {
            Write-Log -Type INFO -Message $L["SteamtoolsFound"]
        } else {
            Write-Log -Type ERR -Message $L["SteamtoolsNotFound"]
            Install-Steamtools $steamPath
        }

        # Temporary (or not) forcing to get stable lua only backend
        # $millenniumWasInstalled = Test-Millennium $steamPath
        # if ($millenniumWasInstalled) {
        #     Write-Log -Type INFO -Message $L["MillenniumAlready"]
        # }
        Install-Millennium $steamPath

        Install-Plugin $steamPath $Script:Name $Script:Link

        Remove-BetaFlag $steamPath
        Remove-SteamCfg $steamPath
        Remove-ForceX86Flags

        Enable-Plugin $steamPath $Script:Name

        Write-Host
        if (-not $millenniumWasInstalled) {
            Write-Log -Type WARN -Message $L["MillenniumFirstBoot"]
        }
        # Write-Log -Type WARN -Message $L["UpdateCheckDisabled"]
        # Write-Log -Type OK   -Message $L["UpdateCheckManual"]

        Write-Log -Type INFO -Message $L["StartingSteam"]
        Start-Process (Join-Path $steamPath "steam.exe") -ArgumentList "-clearbeta"
        $ErrorActionPreference = $Script:OriginalErrorAction
    }

    Main
    exit 0

    # By clem
    # Waike contributed a lot

} # end if Branch 1 or 2

} # end :MainLoop
