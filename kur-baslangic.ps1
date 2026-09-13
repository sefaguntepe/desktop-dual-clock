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

$KISAYOL_ADI = 'Dual Clock.lnk'

# Onceki surumlerde kisayol bu adla kuruluyordu; kurulumda temizlenmezse
# Baslangic klasorunde iki kisayol kalir ve saat iki kez acilmaya calisir.
$ESKI_ADLAR  = @('Masaustu Saat.lnk')

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
# Kisayol ikonu: depo icindeki dual-clock.ico, yoksa shell32'deki saat ikonu.
$ikon = Join-Path $klasor 'dual-clock.ico'
if (-not (Test-Path $ikon)) { $ikon = "$env:WINDIR\System32\shell32.dll,14" }

$arg   = "$psExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$betik`""

# DİKKAT: Başlangıç kısayolunun içeriği saat.ps1'deki Set-BaslangictaBaslat
# ile AYNI olmalı — widget sağ tık menüsündeki "Windows açılışında başlat"
# seçeneği aynı kısayolu kendisi de oluşturup siliyor. İkisi ayrı duruyor
# çünkü saat.ps1'in açılış yolunda başka bir dosyaya bağımlı olmaması gerek.
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
    $lnk.IconLocation     = $ikon
    $lnk.WindowStyle      = 7
    $lnk.Save()

    foreach ($eski in $ESKI_ADLAR) {
        $eskiYol = Join-Path $Dizin $eski
        if (Test-Path $eskiYol) { Remove-Item $eskiYol -Force; Write-Host "  (eski kaldirildi) $eskiYol" }
    }
    Write-Host "  $yol"
}

Write-Host 'Kisayollar:' -ForegroundColor Green
New-Kisayol -Dizin ([Environment]::GetFolderPath('Startup'))  -Aciklama 'Dual Clock - Windows acilisinda baslar'
New-Kisayol -Dizin ([Environment]::GetFolderPath('Programs')) -Aciklama 'Dual Clock - iki sehir saati'
if ($Masaustune) {
    New-Kisayol -Dizin ([Environment]::GetFolderPath('Desktop')) -Aciklama 'Dual Clock - iki sehir saati'
}

Write-Host ''
Write-Host 'Saat kapandiginda: Baslat''a "Dual Clock" yazip acabilirsiniz.'
Write-Host 'Masaustune de    : .\kur-baslangic.ps1 -Masaustune'
Write-Host 'Kaldirmak icin   : .\kaldir-baslangic.ps1'
