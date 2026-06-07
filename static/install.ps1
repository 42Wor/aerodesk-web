Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          AeroDesk Windows Installer              " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Setup Active Roaming Directory Path
$AeroDeskDir = "$Home\AppData\Roaming\AeroDesk"
If (!(Test-Path -Path $AeroDeskDir)) {
    New-Item -ItemType Directory -Force -Path $AeroDeskDir | Out-Null
    Write-Host "[+] Created AeroDesk System Directory: $AeroDeskDir" -ForegroundColor Green
}

# 2. Dependency Verification
Write-Host "[*] Validating development dependencies..." -ForegroundColor Yellow
$GoInstalled = $null -ne (Get-Command go -ErrorAction SilentlyContinue)
$GitInstalled = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

If (!$GoInstalled) {
    Write-Host "[-] Go Compiler is missing. Please install Go (https://go.dev/dl/) first." -ForegroundColor Red
    Exit 1
}
If (!$GitInstalled) {
    Write-Host "[-] Git is missing. Please install Git (https://git-scm.com/) first." -ForegroundColor Red
    Exit 1
}

# 3. Clone and Compile Source Artifacts
Write-Host "[*] Fetching source code..." -ForegroundColor Yellow
$TempDir = Join-Path $env:TEMP "AeroDeskBuild"
If (Test-Path -Path $TempDir) { Remove-Item -Recurse -Force $TempDir }

git clone https://github.com/Maazwaheed/live-wallpaper-assets.git $TempDir 2>$null

$BuildPath = $TempDir
If (!(Test-Path -Path (Join-Path $BuildPath "main.go")) -and (Test-Path -Path ".\main.go")) {
    $BuildPath = "."
}

Write-Host "[*] Compiling executable..." -ForegroundColor Yellow
cd $BuildPath
go build -ldflags="-s -w" -o aerodesk.exe main.go

# Place executable inside AppData folder
$BinDir = Join-Path $AeroDeskDir "bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Move-Item -Force .\aerodesk.exe $BinDir\

# Clean temporary files
cd $Home
If (Test-Path -Path $TempDir) { Remove-Item -Recurse -Force $TempDir }

# 4. System Environment Pathing Verification
Write-Host "[*] Verifying Environment Path registration..." -ForegroundColor Yellow
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
If ($UserPath -notlike "*AppData\Roaming\AeroDesk\bin*") {
    $UpdatedPath = $UserPath + ";" + $BinDir
    [Environment]::SetEnvironmentVariable("Path", $UpdatedPath, "User")
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "[✔] AeroDesk registered to system Environment Path successfully!" -ForegroundColor Green
} Else {
    Write-Host "[✔] Path registration already exists." -ForegroundColor Green
}

Write-Host "==================================================" -ForegroundColor Green
Write-Host "       AeroDesk Windows Installation Successful!  " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Open a fresh terminal window and type: " -ForegroundColor Yellow
Write-Host "  'aerodesk list'  - To explore available wallpapers" -ForegroundColor Cyan
Write-Host "  'aerodesk apply <id>' - To apply a wallpaper dynamically" -ForegroundColor Cyan
