$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$repo\frontend"
& "C:\Users\zispaas\Downloads\flutter_windows_3.47.0-0.4.pre-beta\flutter\bin\flutter.bat" build web --release 2>&1 | Out-File "$repo\build_output.log"
Write-Host "BUILD DONE"