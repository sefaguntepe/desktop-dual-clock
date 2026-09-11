<#
    Masaüstü Saat için kısayolları kurar.

    İKİ kısayol oluşturulur, ikisi de aynı komutu çağırır:
      1. Başlangıç klasörü  — Windows açılışında kendiliğinden çalışsın diye.
      2. Başlat menüsü      — saati KAPATTIKTAN sonra elle açabilmek için.
         Başlangıç klasörü elle açmak için uygun bir yer değil.

    Kayıt defterine veya sistem ayarlarına dokunulmaz.

    Not: Başlatıcı olarak .vbs kullanılmıyor — bazı kurumsal uç-nokta koruma
    yazılımları .vbs oluşturmayı engelliyor.
#>

param([switch]$Masaustune)   # -Masaustune : ayrıca masaüstüne de kısayol koyar

$ErrorActionPreference = 'Stop'

$klasor = Split-Path -Parent $MyInvocation.MyCommand.Path
$betik  = Join-Path $klasor 'saat.ps1'
if (-not (Test-Path $betik)) { throw "saat.ps1 bulunamadi: $betik" }

$KISAYOL_ADI = 'Masaustu Saat.lnk'

# Neden conhost.exe üzerinden?
#
# Doğrudan powershell.exe çağrıldığında, kullanıcının varsayılan terminal
# uygulaması Windows Terminal ise konsol orada açılıyor ve `-WindowStyle
# Hidden` işe yaramıyor: PowerShell'in gizlemeye çalıştığı pencere sözde
# konsol (CASCADIA_HOSTING_WINDOW_CLASS), gerçek pencerenin sahibi Terminal.
# Sonuç: masaüstünde boş bir terminal açık kalıyor.
#
# conhost.exe klasik konsol barındırıcısını zorlar. (saat.ps1 ayrıca
# Hide-Konsol ile kendi konsolunu gizleyip bırakıyor — iki savunma birlikte.)
$psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$arg   = "$psExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$betik`""

function New-Kisayol {
    param([string]$Dizin, [string]$Aciklama)
    if (-not (Test-Path $Dizin)) { New-Item -ItemType Directory -Path $Dizin -Force | Out-Null }

    $yol = Join-Path $Dizin $KISAYOL_ADI
    $sh  = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($yol)
    $lnk.TargetPath       = "$env:WINDIR\System32\conhost.exe"
    $lnk.Arguments        = $arg
    $lnk.WorkingDirectory = $klasor
    $lnk.Description      = $Aciklama
    $lnk.IconLocation     = "$env:WINDIR\System32\shell32.dll,14"
    $lnk.WindowStyle      = 7
    $lnk.Save()
    Write-Host "  $yol"
}

Write-Host 'Kisayollar:' -ForegroundColor Green
New-Kisayol -Dizin ([Environment]::GetFolderPath('Startup'))  -Aciklama 'Masaustu Saat - Windows acilisinda baslar'
New-Kisayol -Dizin ([Environment]::GetFolderPath('Programs')) -Aciklama 'Masaustu Saat - iki sehir saati'
if ($Masaustune) {
    New-Kisayol -Dizin ([Environment]::GetFolderPath('Desktop')) -Aciklama 'Masaustu Saat - iki sehir saati'
}

Write-Host ''
Write-Host 'Saat kapandiginda: Baslat''a "Masaustu Saat" yazip acabilirsiniz.'
Write-Host 'Masaustune de    : .\kur-baslangic.ps1 -Masaustune'
Write-Host 'Kaldirmak icin   : .\kaldir-baslangic.ps1'
