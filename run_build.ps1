Set-Location "C:\Users\zispaas\Documents\Default Project\penrose-scholar\frontend"
& "C:\flutter\flutter\bin\flutter.bat" build web --release 2>&1 | Out-File "C:\Users\zispaas\Documents\Default Project\penrose-scholar\build_output.log"
Write-Host "BUILD DONE"
