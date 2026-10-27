# Collects the md2 desktop binary (built with `tauri build --no-bundle`)
# into a self-contained portable ("green") folder and zips it for offline
# distribution. The frontend is embedded in the exe; the only runtime
# requirement is the WebView2 Runtime (preinstalled on Windows 10/11).
$ErrorActionPreference = "Stop"

$desktopRoot = Split-Path -Parent $PSScriptRoot   # apps/desktop
$releaseDir  = Join-Path $desktopRoot "src-tauri\target\release"
$outRoot     = Join-Path $desktopRoot "portable"
$appDir      = Join-Path $outRoot "md2"

# The exe name can be the cargo package name (md2-desktop.exe) or the
# Tauri productName (md2.exe) depending on toolchain behavior - accept both.
$exe = Get-ChildItem $releaseDir -Filter "*.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @("md2.exe", "md2-desktop.exe") } |
    Select-Object -First 1
if (-not $exe) {
    Write-Error "md2 exe not found in $releaseDir - run 'pnpm desktop:portable' (or 'tauri build --no-bundle') first."
    exit 1
}

if (Test-Path $appDir) { Remove-Item -Recurse -Force $appDir }
New-Item -ItemType Directory -Path $appDir -Force | Out-Null

Copy-Item $exe.FullName (Join-Path $appDir "md2.exe")

# Ship any runtime DLLs the build placed next to the exe (e.g. WebView2Loader.dll), if any.
$dlls = Get-ChildItem $releaseDir -Filter "*.dll" -ErrorAction SilentlyContinue
foreach ($dll in $dlls) { Copy-Item $dll.FullName $appDir }

$readmeText = @"
md2 便携版 (portable)
=====================

运行: 双击 md2.exe
要求: Windows 10/11 (需系统自带 WebView2 Runtime)

说明:
- 前端资源已内嵌于 md2.exe, 无需安装, 解压即用
- 所有 Markdown 渲染均在本地完成
"@
$readmePath = Join-Path $appDir "README.txt"
[System.IO.File]::WriteAllText($readmePath, $readmeText, (New-Object System.Text.UTF8Encoding($true)))

$zipPath = Join-Path $outRoot "md2-portable-win-x64.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path $appDir -DestinationPath $zipPath -Force

$appSize  = (Get-ChildItem $appDir -Recurse | Measure-Object Length -Sum).Sum
$zipSize  = (Get-Item $zipPath).Length
Write-Output ("Portable folder : {0}  ({1:N1} MB)" -f $appDir, ($appSize / 1MB))
Write-Output ("Offline zip     : {0}  ({1:N1} MB)" -f $zipPath, ($zipSize / 1MB))
