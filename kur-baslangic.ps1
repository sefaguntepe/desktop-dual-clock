<#
    Masaüstü Saat'i Windows açılışına ekler.

    Kullanıcı düzeyinde Başlangıç klasörüne bir kısayol koyar — kayıt defterine
    veya sistem ayarlarına dokunmaz. Kaldırmak için: kaldir-baslangic.ps1

    Not: Başlatıcı olarak .vbs kullanılmıyor. Bazı kurumsal uç-nokta koruma
    yazılımları .vbs dosyası oluşturmayı engeller; kısayol bu yüzden doğrudan
    powershell.exe'yi gizli pencere ile çağırıyor.
#>

$ErrorActionPreference = 'Stop'

$klasor    = Split-Path -Parent $MyInvocation.MyCommand.Path
$betik     = Join-Path $klasor 'saat.ps1'
$baslangic = [Environment]::GetFolderPath('Startup')
$kisayol   = Join-Path $baslangic 'Masaustu Saat.lnk'

if (-not (Test-Path $betik)) { throw "saat.ps1 bulunamadi: $betik" }

$sh  = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut($kisayol)
$lnk.TargetPath       = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$lnk.Arguments        = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$betik`""
$lnk.WorkingDirectory = $klasor
$lnk.Description      = 'Masaustu Saat - Los Angeles + Istanbul'
$lnk.IconLocation     = "$env:WINDIR\System32\shell32.dll,14"
$lnk.WindowStyle      = 7   # simge durumunda baslat
$lnk.Save()

Write-Host 'Baslangica eklendi:' -ForegroundColor Green
Write-Host "  $kisayol"
Write-Host 'Kaldirmak icin: kaldir-baslangic.ps1'
