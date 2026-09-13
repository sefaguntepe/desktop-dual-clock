#requires -Version 5.1
<#
    Masaüstü Saat  —  iki şehir yan yana (sağ tık → Şehir seç)
    Sefa Güntepe

    Kenarlıksız, şeffaf, masaüstü seviyesinde duran WPF widget'ı.
    Kurulum gerektirmez; Windows PowerShell 5.1 ve WPF ile çalışır.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ─────────────────────────────────────────────────────────────────────────────
# Win32 köprüsü — masaüstüne gömme, imleç konumu, pencere stili
# ─────────────────────────────────────────────────────────────────────────────
if (-not ([System.Management.Automation.PSTypeName]'Widget.Win32').Type) {
Add-Type -Namespace Widget -Name Win32 -MemberDefinition @'
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    // Pencere odak almadigi icin (WS_EX_NOACTIVATE) WPF'in Keyboard.Modifiers'i
    // guvenilir degil; Shift/Ctrl durumunu dogrudan sistemden okuyoruz.
    [DllImport("user32.dll")]
    public static extern short GetKeyState(int nVirtKey);

    // Sag tik menusunu kapatma nobetcisi icin (odaktan bagimsiz yoklama).
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT p);

    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int pid);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int X, int Y, int cx, int cy, uint flags);

    // Betigi calistiran konsol. Bkz. Hide-Konsol.
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("kernel32.dll")]
    public static extern bool FreeConsole();

'@
}

# Arkada duran boş konsol penceresini yok et.
#
# Kısayol `-WindowStyle Hidden` ile açıyor ama bu YETMİYOR: kullanıcının
# varsayılan konsol barındırıcısı Windows Terminal ise pencere sınıfı
# `CASCADIA_HOSTING_WINDOW_CLASS` oluyor, yani PowerShell'in gizlemeye
# çalıştığı pencere gerçek sahibi değil — ekranda boş bir terminal açık
# kalıyor. Aynısı betik çift tıkla çalıştırıldığında da oluyor.
#
# İki adım birden: klasik conhost için pencereyi gizle, Windows Terminal için
# konsolu tamamen bırak. Saat penceresi WPF; konsola hiç ihtiyacı yok.
function Hide-Konsol {
    try {
        $konsol = [Widget.Win32]::GetConsoleWindow()
        if ($konsol -eq [IntPtr]::Zero) { return }
        [void][Widget.Win32]::ShowWindow($konsol, 0)   # SW_HIDE
        [void][Widget.Win32]::FreeConsole()
    } catch { }
}
Hide-Konsol

# Pencereyi z-sırasının dibinde tutmanın DOĞRU yolu.
#
# Önceki sürüm bunu 2 saniyede bir SetWindowPos çağırarak yapıyordu ve
# masaüstünü kullanılamaz hâle getiriyordu: sağ tık menüsü açılıyor, ilk
# yoklamada kapanıyordu; simge seçmek için sürüklenen çerçeve de bozuluyordu.
#
# Doğrusu yoklama değil, olay yakalamak: Windows pencerenin konumunu/z-sırasını
# değiştirmek üzereyken WM_WINDOWPOSCHANGING gönderir. O mesajdaki
# hwndInsertAfter alanını HWND_BOTTOM yapıp SWP_NOZORDER bayrağını temizlemek
# yeterli. Böylece pencere kendiliğinden dipte kalır ve masaüstüne hiç
# dokunulmaz.
if (-not ([System.Management.Automation.PSTypeName]'ZDuzeniSaat').Type) {
Add-Type -ReferencedAssemblies WindowsBase, PresentationCore -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;

public static class ZDuzeniSaat
{
    const int WM_WINDOWPOSCHANGING = 0x0046;
    const int SWP_NOZORDER = 0x0004;

    static IntPtr Hook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_WINDOWPOSCHANGING)
        {
            // WINDOWPOS: hwnd, hwndInsertAfter, x, y, cx, cy, flags
            Marshal.WriteIntPtr(lParam, IntPtr.Size, (IntPtr)1);   // HWND_BOTTOM
            int bayrakOfset = IntPtr.Size * 2 + 16;
            int bayraklar = Marshal.ReadInt32(lParam, bayrakOfset);
            Marshal.WriteInt32(lParam, bayrakOfset, bayraklar & ~SWP_NOZORDER);
        }
        return IntPtr.Zero;
    }

    public static void Bagla(IntPtr hwnd)
    {
        HwndSource src = HwndSource.FromHwnd(hwnd);
        if (src != null) src.AddHook(new HwndSourceHook(Hook));
    }
}
'@
}

$GWL_EXSTYLE       = -20
$WS_EX_TOOLWINDOW  = 0x00000080   # Alt+Tab ve gorev cubugunda gorunme
$WS_EX_NOACTIVATE  = 0x08000000   # tiklayinca one gelme / odagi calma
$HWND_BOTTOM       = [IntPtr]1    # z-sirasinin dibi (8 DEGIL — yaygin hata)
$SW_SHOWNOACTIVATE = 4
$SWP_NOSIZE        = 0x0001
$SWP_NOMOVE        = 0x0002
$SWP_NOZORDER      = 0x0004
$SWP_NOACTIVATE    = 0x0010

# ─────────────────────────────────────────────────────────────────────────────
# Ayarlar (konum + arka plan yoğunluğu) — %APPDATA%\MasaustuSaat\ayarlar.json
# ─────────────────────────────────────────────────────────────────────────────
$AyarKlasor = Join-Path $env:APPDATA 'MasaustuSaat'
$AyarDosya  = Join-Path $AyarKlasor 'ayarlar.json'

# TEK ÖRNEK KORUMASI
#
# İki kopya aynı anda çalışırsa ikisi de ayarlar.json'a yazıyor: biri
# sürüklenince diğeri eski konumu geri yazıyor, şehir seçimleri birbirini
# eziyor. Üstelik üst üste duran iki saat "kapattım ama duruyor" gibi görünüyor.
#
# Kilit adı AYAR KLASÖRÜNDEN türüyor: yalıtılmış APPDATA ile çalışan testler
# birbirini ve üretimi engellemesin.
$kilitAdi = 'Local\MasaustuSaat_' + (
    ([System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($AyarKlasor.ToLowerInvariant())
    ) | ForEach-Object { $_.ToString('x2') }) -join '')
$script:TekOrnek = New-Object System.Threading.Mutex($false, $kilitAdi)
$kilitAlindi = $false
try {
    $kilitAlindi = $script:TekOrnek.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    # Önceki süreç aniden kapandıysa kilit terk edilmiş olabilir; kilit yine de bu iş parçacığına geçer.
    $kilitAlindi = $true
}
if (-not $kilitAlindi) { exit 0 }   # zaten açık

$SABLONLAR = [ordered]@{
    'apple-dark' = @{
        Ad = 'apple-dark'
        KoseYaricap = 22
        KenarlikKalinlik = 1
        KenarlikFirca = '#38FFFFFF'
        BgYok = '#00000000'
        BgHafif = '#731C1C1E'
        BgKoyu = '#CC1C1C1E'
        GolgeRenk = '#FF000000'
        GolgeBulaniklik = 22
        GolgeOpaklik = 0.45
        GolgeDerinlik = 3
        MetinAna = '#FFFFFFFF'
        MetinIkincil = '#99EBEBF5'
        SaatRenk = '#F5F5F7'
        AyiriciRenk = '#1FFFFFFF'
        GunesRenk = '#FF9F0A'
        AyRenk = '#0A84FF'
        PlanZemin = '#26FF9F0A'
        PlanVurguRenk = '#FF9F0A'
        PlanButonZemin = '#26FFFFFF'
        PlanButonHover = '#4DFFFFFF'
        PlanButonMetin = '#F0F4FA'
    }
    'apple-light' = @{
        Ad = 'apple-light'
        KoseYaricap = 22
        KenarlikKalinlik = 1
        KenarlikFirca = '#40FFFFFF'
        BgYok = '#00000000'
        BgHafif = '#D9F2F2F7'
        BgKoyu = '#F2F2F7'
        GolgeRenk = '#FF000000'
        GolgeBulaniklik = 16
        GolgeOpaklik = 0.18
        GolgeDerinlik = 2
        MetinAna = '#1C1C1E'
        MetinIkincil = '#636366'
        SaatRenk = '#1C1C1E'
        AyiriciRenk = '#1F000000'
        GunesRenk = '#FF9500'
        AyRenk = '#007AFF'
        PlanZemin = '#26FF9500'
        # Açık zeminde vurgu rengi koyu olmak zorunda: #D97706 şeride karşı
        # yalnızca 2.6:1 veriyordu (hem PLANLAMA başlığı hem çapa saati bunu
        # kullanıyor). #B45309 aynı kehribar kimliği, 4.0:1.
        PlanVurguRenk = '#B45309'
        PlanButonZemin = '#1A000000'
        PlanButonHover = '#33000000'
        PlanButonMetin = '#1C1C1E'
    }
    'neon' = @{
        Ad = 'neon'
        KoseYaricap = 14
        KenarlikKalinlik = 1
        KenarlikFirca = '#6600E5FF'
        BgYok = '#00000000'
        BgHafif = '#E608090C'
        BgKoyu = '#F208090C'
        GolgeRenk = '#FF00E5FF'
        GolgeBulaniklik = 14
        GolgeOpaklik = 0.35
        GolgeDerinlik = 0
        MetinAna = '#F0F6FC'
        MetinIkincil = '#8B949E'
        SaatRenk = '#00E5FF'
        AyiriciRenk = '#2600E5FF'
        GunesRenk = '#FFB800'
        AyRenk = '#00E5FF'
        PlanZemin = '#2600E5FF'
        PlanVurguRenk = '#00E5FF'
        PlanButonZemin = '#1F00E5FF'
        PlanButonHover = '#4D00E5FF'
        PlanButonMetin = '#F0F6FC'
    }
    'klasik' = @{
        Ad = 'klasik'
        KoseYaricap = 16
        KenarlikKalinlik = 0
        KenarlikFirca = '#00000000'
        BgYok = '#00000000'
        BgHafif = '#59000000'
        BgKoyu = '#A6000000'
        GolgeRenk = '#FF000000'
        GolgeBulaniklik = 7
        GolgeOpaklik = 0.9
        GolgeDerinlik = 0
        MetinAna = '#E8EDF5'
        MetinIkincil = '#E8EDF5'
        SaatRenk = '#F5F8FC'
        AyiriciRenk = '#26FFFFFF'
        GunesRenk = '#FFC24B'
        AyRenk = '#9FB6D9'
        PlanZemin = '#1FE8A33D'
        PlanVurguRenk = '#E8A33D'
        PlanButonZemin = '#26FFFFFF'
        PlanButonHover = '#4DFFFFFF'
        PlanButonMetin = '#F0F4FA'
    }
    # Sıcak koyu tema. Diğer dördü nötr ya da soğuk (mavi/camgöbeği) olduğu için
    # palette sıcak bir seçenek yoktu. Ay ikonu bilerek soğuk lavanta: kehribar
    # güneşin yanında gece/gündüz ayrımı renkten de okunuyor.
    'kehribar' = @{
        Ad = 'kehribar'
        KoseYaricap = 18
        KenarlikKalinlik = 1
        KenarlikFirca = '#3DFFB86C'
        BgYok = '#00000000'
        BgHafif = '#8C1A1410'
        BgKoyu = '#D91A1410'
        GolgeRenk = '#FF000000'
        GolgeBulaniklik = 18
        GolgeOpaklik = 0.5
        GolgeDerinlik = 2
        MetinAna = '#F5E6D3'
        # Tarih satırı ve planlama şeridinin ikincil metinleri bunu kullanıyor.
        # Daha soluk bir ton (#A89078) açık duvar kağıdı üzerinde 2.5:1'e
        # düşüyordu — zemin yarı saydam olduğu için duvar kağıdı önemli.
        MetinIkincil = '#D6C3AC'
        SaatRenk = '#FFD9A0'
        AyiriciRenk = '#26FFB86C'
        GunesRenk = '#FFB86C'
        AyRenk = '#B4A0D9'
        # Çapa vurgusu saat renginden AYRI bir tonda: saat zaten kehribar,
        # aynı rengi vurgu için kullanmak "hangi satır çapa" bilgisini yok eder.
        PlanZemin = '#26FF7B72'
        PlanVurguRenk = '#FF9E80'
        PlanButonZemin = '#26FFE8D0'
        PlanButonHover = '#4DFFE8D0'
        PlanButonMetin = '#F5E6D3'
    }
}

# Windows'un açık/koyu tema ayarını izleyen sözde şablon.
#
# $SABLONLAR içine KONMUYOR: gerçek bir palet değil, çalışma anında
# apple-light veya apple-dark'a çözülen bir yönlendirme. Ayar dosyasında
# 'apple-auto' olarak saklanır; çözüm her okunduğunda yeniden yapılır.
$SABLON_OTO = 'apple-auto'

function Get-SistemAcikTemaMi {
    try {
        $p = Get-ItemProperty -ErrorAction Stop `
             -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
             -Name 'AppsUseLightTheme'
        return ($p.AppsUseLightTheme -eq 1)
    } catch {
        # Anahtar yok (eski Windows) ya da okunamadı — koyu varsay.
        return $false
    }
}

# Ayar dosyasındaki şablon adını GERÇEK bir palet anahtarına çevirir.
function Resolve-SablonAdi {
    param([string]$Ad)
    if ($Ad -eq $SABLON_OTO) {
        return $(if (Get-SistemAcikTemaMi) { 'apple-light' } else { 'apple-dark' })
    }
    if ([string]::IsNullOrEmpty($Ad) -or -not $SABLONLAR.Contains($Ad)) { return 'apple-dark' }
    return $Ad
}

function Get-Ayarlar {
    $vars = [ordered]@{ sol = $null; ust = $null; arkaPlan = 'hafif'; sablon = 'apple-dark'
                        gorunum = 'dijital'
                        sehirUst = 'istanbul'; sehirAlt = 'losangeles' }
    if (Test-Path $AyarDosya) {
        try {
            $j = Get-Content $AyarDosya -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @('sol', 'ust', 'arkaPlan', 'sablon', 'gorunum', 'sehirUst', 'sehirAlt')) {
                if ($j.PSObject.Properties.Name -contains $k -and $null -ne $j.$k) { $vars[$k] = $j.$k }
            }
        } catch {
            # Bozuk ayar dosyası widget'ı engellemesin — varsayılana dön.
        }
    }
    [pscustomobject]$vars
}

function Save-Ayarlar {
    param($Ayar)
    try {
        if (-not (Test-Path $AyarKlasor)) { New-Item -ItemType Directory -Path $AyarKlasor -Force | Out-Null }
        $Ayar | ConvertTo-Json | Set-Content -Path $AyarDosya -Encoding UTF8
    } catch {
        # Yazamadıysak sessizce geç; saat çalışmaya devam etsin.
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Zaman dilimleri — sabit ofset YOK, Windows tz veritabanı (DST otomatik)
# ─────────────────────────────────────────────────────────────────────────────
function Get-ZamanDilimi {
    param([string]$Windows, [string]$Iana)
    try {
        return [TimeZoneInfo]::FindSystemTimeZoneById($Windows)
    } catch {
        try {
            return [TimeZoneInfo]::FindSystemTimeZoneById($Iana)
        } catch {
            return [TimeZoneInfo]::Utc
        }
    }
}

# Şehir kataloğu. Sıra UTC ofsetine göre (batıdan doğuya) — menüde şehir
# aramak yerine "kabaca nerede" diye bakmak daha hızlı.
# Her satır: Ad, Windows saat dilimi kimliği, IANA yedeği.
#
# ÖNEMLİ: ayar dosyasında GÖRÜNEN AD değil ANAHTAR saklanır. Görünen ad dile
# göre değiştiği için ("İstanbul" / "Istanbul"), adı saklamak dil değişince
# kaydı bozardı.
$SEHIRLER = @(
    @{ Anahtar = 'losangeles'; Tr = 'Los Angeles'; En = 'Los Angeles'; Win = 'Pacific Standard Time'; Iana = 'America/Los_Angeles' }
    @{ Anahtar = 'denver'; Tr = 'Denver'; En = 'Denver'; Win = 'Mountain Standard Time'; Iana = 'America/Denver' }
    @{ Anahtar = 'chicago'; Tr = 'Chicago'; En = 'Chicago'; Win = 'Central Standard Time'; Iana = 'America/Chicago' }
    @{ Anahtar = 'newyork'; Tr = 'New York'; En = 'New York'; Win = 'Eastern Standard Time'; Iana = 'America/New_York' }
    @{ Anahtar = 'toronto'; Tr = 'Toronto'; En = 'Toronto'; Win = 'Eastern Standard Time'; Iana = 'America/Toronto' }
    @{ Anahtar = 'saopaulo'; Tr = 'São Paulo'; En = 'São Paulo'; Win = 'E. South America Standard Time'; Iana = 'America/Sao_Paulo' }
    @{ Anahtar = 'utc'; Tr = 'UTC'; En = 'UTC'; Win = 'UTC'; Iana = 'UTC' }
    @{ Anahtar = 'london'; Tr = 'Londra'; En = 'London'; Win = 'GMT Standard Time'; Iana = 'Europe/London' }
    @{ Anahtar = 'paris'; Tr = 'Paris'; En = 'Paris'; Win = 'Romance Standard Time'; Iana = 'Europe/Paris' }
    @{ Anahtar = 'madrid'; Tr = 'Madrid'; En = 'Madrid'; Win = 'Romance Standard Time'; Iana = 'Europe/Madrid' }
    @{ Anahtar = 'milan'; Tr = 'Milano'; En = 'Milan'; Win = 'W. Europe Standard Time'; Iana = 'Europe/Rome' }
    @{ Anahtar = 'berlin'; Tr = 'Berlin'; En = 'Berlin'; Win = 'W. Europe Standard Time'; Iana = 'Europe/Berlin' }
    @{ Anahtar = 'cairo'; Tr = 'Kahire'; En = 'Cairo'; Win = 'Egypt Standard Time'; Iana = 'Africa/Cairo' }
    @{ Anahtar = 'istanbul'; Tr = 'İstanbul'; En = 'Istanbul'; Win = 'Turkey Standard Time'; Iana = 'Europe/Istanbul' }
    @{ Anahtar = 'moscow'; Tr = 'Moskova'; En = 'Moscow'; Win = 'Russian Standard Time'; Iana = 'Europe/Moscow' }
    @{ Anahtar = 'doha'; Tr = 'Doha'; En = 'Doha'; Win = 'Arab Standard Time'; Iana = 'Asia/Qatar' }
    @{ Anahtar = 'riyadh'; Tr = 'Riyad'; En = 'Riyadh'; Win = 'Arab Standard Time'; Iana = 'Asia/Riyadh' }
    @{ Anahtar = 'dubai'; Tr = 'Dubai'; En = 'Dubai'; Win = 'Arabian Standard Time'; Iana = 'Asia/Dubai' }
    @{ Anahtar = 'baku'; Tr = 'Bakü'; En = 'Baku'; Win = 'Azerbaijan Standard Time'; Iana = 'Asia/Baku' }
    @{ Anahtar = 'tashkent'; Tr = 'Taşkent'; En = 'Tashkent'; Win = 'West Asia Standard Time'; Iana = 'Asia/Tashkent' }
    @{ Anahtar = 'delhi'; Tr = 'Delhi'; En = 'Delhi'; Win = 'India Standard Time'; Iana = 'Asia/Kolkata' }
    @{ Anahtar = 'singapore'; Tr = 'Singapur'; En = 'Singapore'; Win = 'Singapore Standard Time'; Iana = 'Asia/Singapore' }
    @{ Anahtar = 'shanghai'; Tr = 'Şanghay'; En = 'Shanghai'; Win = 'China Standard Time'; Iana = 'Asia/Shanghai' }
    @{ Anahtar = 'tokyo'; Tr = 'Tokyo'; En = 'Tokyo'; Win = 'Tokyo Standard Time'; Iana = 'Asia/Tokyo' }
    @{ Anahtar = 'sydney'; Tr = 'Sidney'; En = 'Sydney'; Win = 'AUS Eastern Standard Time'; Iana = 'Australia/Sydney' }
)

function Get-SehirAdi { param($Sehir) if ($DIL -eq 'tr') { $Sehir.Tr } else { $Sehir.En } }

function Get-Sehir {
    param([string]$Anahtar)
    # Anahtarla ara; bulunamazsa eski sürümlerden kalma AD ile ara (geriye
    # dönük uyum); o da yoksa çökmek yerine İstanbul'a dön.
    $s = $SEHIRLER | Where-Object { $_.Anahtar -eq $Anahtar } | Select-Object -First 1
    if ($null -eq $s) { $s = $SEHIRLER | Where-Object { $_.Tr -eq $Anahtar -or $_.En -eq $Anahtar } | Select-Object -First 1 }
    if ($null -eq $s) { $s = $SEHIRLER | Where-Object { $_.Anahtar -eq 'istanbul' } | Select-Object -First 1 }
    return $s
}

function Get-SehirDilimi {
    param([string]$Anahtar)
    $s = Get-Sehir -Anahtar $Anahtar
    return (Get-ZamanDilimi -Windows $s.Win -Iana $s.Iana)
}
# ─────────────────────────────────────────────────────────────────────────────
# Dil — Windows görüntü diline göre otomatik (yalnızca tr / en)
# ─────────────────────────────────────────────────────────────────────────────
$DIL = if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'tr') { 'tr' } else { 'en' }
$Kultur = [System.Globalization.CultureInfo]::GetCultureInfo($(if ($DIL -eq 'tr') { 'tr-TR' } else { 'en-US' }))

$METINLER = @{
    tr = @{
        MENU_SABLON   = 'Şablon';      SABLON_APPLE_DARK  = 'Apple Koyu (macOS)'
        SABLON_APPLE_LIGHT = 'Apple Açık'; SABLON_NEON    = 'Neon Akrilik'; SABLON_KLASIK = 'Klasik Koyu'
        SABLON_APPLE_OTO = 'Apple Otomatik (sistemi izler)'; SABLON_KEHRIBAR = 'Kehribar'
        MENU_GORUNUM  = 'Görünüm';     GORUNUM_DIJITAL = 'Dijital'; GORUNUM_ANALOG = 'Analog kadran'
        MENU_ARKAPLAN = 'Arka plan';   MENU_YOK   = 'Yok (tam şeffaf)'
        MENU_HAFIF    = 'Hafif';       MENU_KOYU  = 'Koyu'
        MENU_SEHIR    = 'Şehir seç';   MENU_UST   = 'Üst satır';  MENU_ALT = 'Alt satır'
        MENU_PLAN     = 'Planlama modu'
        MENU_BASLANGIC = 'Windows açılışında başlat'
        MENU_SIFIRLA  = 'Konumu sıfırla (sağ üst)'
        MENU_KAPAT    = 'Kapat'
        PLAN_BASLIK   = 'PLANLAMA';    PLAN_SIMDI = 'şimdi'
        PLAN_FARK     = 'fark {0} sa'
        PLAN_IPUCU    = 'tekerlek 15dk · Shift 1sa'
    }
    en = @{
        MENU_SABLON   = 'Theme / Style'; SABLON_APPLE_DARK  = 'Apple Dark (macOS)'
        SABLON_APPLE_LIGHT = 'Apple Light'; SABLON_NEON    = 'Neon Acrylic'; SABLON_KLASIK = 'Classic Dark'
        SABLON_APPLE_OTO = 'Apple Auto (follows system)'; SABLON_KEHRIBAR = 'Amber Dusk'
        MENU_GORUNUM  = 'View';        GORUNUM_DIJITAL = 'Digital'; GORUNUM_ANALOG = 'Analog dial'
        MENU_ARKAPLAN = 'Background';  MENU_YOK   = 'None (transparent)'
        MENU_HAFIF    = 'Light';       MENU_KOYU  = 'Dark'
        MENU_SEHIR    = 'Select city'; MENU_UST   = 'Top row';    MENU_ALT = 'Bottom row'
        MENU_PLAN     = 'Planning mode'
        MENU_BASLANGIC = 'Start with Windows'
        MENU_SIFIRLA  = 'Reset position (top right)'
        MENU_KAPAT    = 'Close'
        PLAN_BASLIK   = 'PLANNING';    PLAN_SIMDI = 'now'
        PLAN_FARK     = '{0} h apart'
        PLAN_IPUCU    = 'wheel 15min · Shift 1h'
    }
}

function T { param([string]$Anahtar) return $METINLER[$DIL][$Anahtar] }

# Segoe MDL2 Assets ikon kodları (emoji yerine — kodlama sorunu çıkarmaz)
$IkonGunes = [char]0xE706
$IkonAy    = [char]0xE708

function Get-MevcutSablon {
    return $SABLONLAR[(Resolve-SablonAdi $script:Ayar.sablon)]
}

# Fırça önbelleği.
#
# Update-Saat saniyede bir çalışıyor ve her çağrıda yeni BrushConverter üretip
# aynı renk dizgilerini baştan ayrıştırıyordu. Renk sayısı sabit ve küçük;
# bir kez üretip donduruyoruz. Frozen Freezable'lar paylaşılabilir ve WPF
# tarafında daha hızlı işlenir.
$script:FircaOnbellek = @{}

function Get-Firca {
    param([string]$Hex)
    if (-not $script:FircaOnbellek.ContainsKey($Hex)) {
        $f = [Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
        $f.Freeze()
        $script:FircaOnbellek[$Hex] = $f
    }
    return $script:FircaOnbellek[$Hex]
}

# ─── KATKI NOKTASI ───────────────────────────────────────────────────────────
# Bir şehrin o anki saatine bakıp gündüz/gece durumunu döndürür.
# Şablona göre güneş ve ay ikon renkleri dinamik belirlenir.
function Get-GunDurumu {
    param([datetime]$Yerel)

    $sablon = Get-MevcutSablon
    if ($Yerel.Hour -ge 7 -and $Yerel.Hour -lt 19) {
        return [pscustomobject]@{ Ikon = $IkonGunes; Renk = $sablon.GunesRenk }   # gündüz
    }
    return [pscustomobject]@{ Ikon = $IkonAy; Renk = $sablon.AyRenk }          # gece
}
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Arayüz
# ─────────────────────────────────────────────────────────────────────────────
$xamlMetin = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Desktop Dual Clock"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" Topmost="False" ResizeMode="NoResize"
        SizeToContent="WidthAndHeight" WindowStartupLocation="Manual"
        UseLayoutRounding="True" TextOptions.TextRenderingMode="ClearType">

  <Window.ContextMenu>
    <ContextMenu>
      <MenuItem Header="@@MENU_SABLON@@">
        <MenuItem x:Name="MnuSablonAppleOto"   Header="@@SABLON_APPLE_OTO@@"   IsCheckable="True"/>
        <MenuItem x:Name="MnuSablonAppleDark"  Header="@@SABLON_APPLE_DARK@@"  IsCheckable="True"/>
        <MenuItem x:Name="MnuSablonAppleLight" Header="@@SABLON_APPLE_LIGHT@@" IsCheckable="True"/>
        <Separator/>
        <MenuItem x:Name="MnuSablonKehribar"   Header="@@SABLON_KEHRIBAR@@"    IsCheckable="True"/>
        <MenuItem x:Name="MnuSablonNeon"       Header="@@SABLON_NEON@@"        IsCheckable="True"/>
        <MenuItem x:Name="MnuSablonKlasik"     Header="@@SABLON_KLASIK@@"      IsCheckable="True"/>
      </MenuItem>
      <!-- Görünüm ŞABLONDAN AYRI bir eksen: şablon renk paleti, görünüm
           yerleşim. Analog kadran altı şablonun da renklerini kullanıyor;
           tersi olsaydı her şablon için ayrı bir analog kopya gerekirdi. -->
      <MenuItem Header="@@MENU_GORUNUM@@">
        <MenuItem x:Name="MnuGorunumDijital" Header="@@GORUNUM_DIJITAL@@" IsCheckable="True"/>
        <MenuItem x:Name="MnuGorunumAnalog"  Header="@@GORUNUM_ANALOG@@"  IsCheckable="True"/>
      </MenuItem>
      <MenuItem Header="@@MENU_ARKAPLAN@@">
        <MenuItem x:Name="MnuBgYok"   Header="@@MENU_YOK@@"   IsCheckable="True"/>
        <MenuItem x:Name="MnuBgHafif" Header="@@MENU_HAFIF@@" IsCheckable="True"/>
        <MenuItem x:Name="MnuBgKoyu"  Header="@@MENU_KOYU@@"  IsCheckable="True"/>
      </MenuItem>
      <Separator/>
      <MenuItem x:Name="MnuPlan" Header="@@MENU_PLAN@@" IsCheckable="True"/>
      <Separator/>
      <MenuItem x:Name="MnuSifirla" Header="@@MENU_SIFIRLA@@"/>
      <MenuItem Header="@@MENU_SEHIR@@">
        <MenuItem x:Name="MnuSehirUst" Header="@@MENU_UST@@"/>
        <MenuItem x:Name="MnuSehirAlt" Header="@@MENU_ALT@@"/>
      </MenuItem>
      <Separator/>
      <MenuItem x:Name="MnuBaslangic" Header="@@MENU_BASLANGIC@@" IsCheckable="True"/>
      <Separator/>
      <MenuItem x:Name="MnuKapat"   Header="@@MENU_KAPAT@@"/>
    </ContextMenu>
  </Window.ContextMenu>

  <Border x:Name="Kapsul" CornerRadius="22" BorderThickness="1" BorderBrush="#38FFFFFF" Padding="18,13,20,13" Background="#731C1C1E">
    <StackPanel>
      <StackPanel.Effect>
        <DropShadowEffect x:Name="KapsulGolge" BlurRadius="22" ShadowDepth="3" Opacity="0.45" Color="#FF000000"/>
      </StackPanel.Effect>

      <!-- DIJITAL GOVDE — Görünüm: Dijital seçiliyken görünür -->
      <StackPanel x:Name="DijitalKok">

      <!-- ISTANBUL -->
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="IkonIst" Grid.Column="0" FontFamily="Segoe MDL2 Assets" FontSize="15"
                   VerticalAlignment="Center" Margin="0,0,11,0" Foreground="#FFC24B"/>
        <StackPanel Grid.Column="1" VerticalAlignment="Center" MinWidth="104">
          <TextBlock x:Name="AdIst" FontFamily="Segoe UI" FontSize="10.5" FontWeight="SemiBold"
                     Foreground="#E8EDF5" Opacity="0.82"/>
          <TextBlock x:Name="TarihIst" FontFamily="Segoe UI" FontSize="10.5"
                     Foreground="#E8EDF5" Opacity="0.55" Margin="0,1,0,0"/>
        </StackPanel>
        <TextBlock x:Name="SaatIst" Grid.Column="2" FontFamily="Segoe UI Light" FontSize="30"
                   Foreground="#F5F8FC" VerticalAlignment="Center" TextAlignment="Right"
                   MinWidth="86" Margin="14,0,0,0" Typography.NumeralAlignment="Tabular"/>
      </Grid>

      <Rectangle x:Name="Ayirici" Height="1" Fill="#1FFFFFFF" Margin="0,9,0,9"/>

      <!-- LOS ANGELES -->
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="IkonLa" Grid.Column="0" FontFamily="Segoe MDL2 Assets" FontSize="15"
                   VerticalAlignment="Center" Margin="0,0,11,0" Foreground="#9FB6D9"/>
        <StackPanel Grid.Column="1" VerticalAlignment="Center" MinWidth="104">
          <TextBlock x:Name="AdLa" FontFamily="Segoe UI" FontSize="10.5" FontWeight="SemiBold"
                     Foreground="#E8EDF5" Opacity="0.82"/>
          <TextBlock x:Name="TarihLa" FontFamily="Segoe UI" FontSize="10.5"
                     Foreground="#E8EDF5" Opacity="0.55" Margin="0,1,0,0"/>
        </StackPanel>
        <TextBlock x:Name="SaatLa" Grid.Column="2" FontFamily="Segoe UI Light" FontSize="30"
                   Foreground="#F5F8FC" VerticalAlignment="Center" TextAlignment="Right"
                   MinWidth="86" Margin="14,0,0,0" Typography.NumeralAlignment="Tabular"/>
      </Grid>

      </StackPanel>
      <!-- /DIJITAL GOVDE -->

      <!-- ANALOG GOVDE — iki kadran yan yana. Kadranların içi (çentikler,
           ibreler) XAML'de DEĞİL kodda üretiliyor: 12 çentik × 2 kadran =
           elle yazılacak 24 satır, ve ibrelerin dönüş merkezi zaten koddan
           hesaplanıyor. Bkz. New-Kadran. -->
      <Grid x:Name="AnalogKok" Visibility="Collapsed">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Column="0" Margin="0,0,9,0">
          <Canvas x:Name="KadranUst" Width="82" Height="82" HorizontalAlignment="Center"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0">
            <TextBlock x:Name="IkonAnaUst" FontFamily="Segoe MDL2 Assets" FontSize="11"
                       VerticalAlignment="Center" Margin="0,0,5,0" Foreground="#FFC24B"/>
            <TextBlock x:Name="AdAnaUst" FontFamily="Segoe UI" FontSize="10.5" FontWeight="SemiBold"
                       VerticalAlignment="Center" Foreground="#E8EDF5" Opacity="0.82"/>
          </StackPanel>
          <TextBlock x:Name="SaatAnaUst" FontFamily="Segoe UI Light" FontSize="19" Margin="0,1,0,0"
                     HorizontalAlignment="Center" Foreground="#F5F8FC"
                     Typography.NumeralAlignment="Tabular"/>
          <TextBlock x:Name="TarihAnaUst" FontFamily="Segoe UI" FontSize="10"
                     HorizontalAlignment="Center" Foreground="#E8EDF5" Opacity="0.55"/>
        </StackPanel>

        <StackPanel Grid.Column="1" Margin="9,0,0,0">
          <Canvas x:Name="KadranAlt" Width="82" Height="82" HorizontalAlignment="Center"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0">
            <TextBlock x:Name="IkonAnaAlt" FontFamily="Segoe MDL2 Assets" FontSize="11"
                       VerticalAlignment="Center" Margin="0,0,5,0" Foreground="#9FB6D9"/>
            <TextBlock x:Name="AdAnaAlt" FontFamily="Segoe UI" FontSize="10.5" FontWeight="SemiBold"
                       VerticalAlignment="Center" Foreground="#E8EDF5" Opacity="0.82"/>
          </StackPanel>
          <TextBlock x:Name="SaatAnaAlt" FontFamily="Segoe UI Light" FontSize="19" Margin="0,1,0,0"
                     HorizontalAlignment="Center" Foreground="#F5F8FC"
                     Typography.NumeralAlignment="Tabular"/>
          <TextBlock x:Name="TarihAnaAlt" FontFamily="Segoe UI" FontSize="10"
                     HorizontalAlignment="Center" Foreground="#E8EDF5" Opacity="0.55"/>
        </StackPanel>
      </Grid>
      <!-- /ANALOG GOVDE -->

      <!-- planlama seridi -->
      <Border x:Name="PlanSerit" Visibility="Collapsed" Margin="0,12,0,0" CornerRadius="9"
              Background="#1FE8A33D" Padding="9,7,9,8">
        <StackPanel>
          <!-- Bu üç metnin rengi KODDAN veriliyor (Set-Sablon). XAML'de sabit
               renk bırakmak Apple Açık temasında beyaz-üstüne-beyaz yapıyordu;
               buradaki değerler yalnızca XAML tasarım anı için yedek. -->
          <Grid Margin="0,0,0,7">
            <TextBlock x:Name="PlanBaslik" Text="@@PLAN_BASLIK@@" FontFamily="Segoe UI" FontSize="9"
                       FontWeight="SemiBold" Foreground="#E8A33D"/>
            <TextBlock x:Name="PlanFark" HorizontalAlignment="Right" FontFamily="Segoe UI"
                       FontSize="9" Foreground="#E8EDF5" Opacity="0.9"/>
          </Grid>
          <StackPanel Orientation="Horizontal">
            <Border x:Name="BtnEksi" Cursor="Hand" CornerRadius="6" Background="#26FFFFFF" Padding="11,3,11,4" Margin="0,0,5,0">
              <TextBlock Text="−" FontFamily="Segoe UI" FontSize="12" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnArti" Cursor="Hand" CornerRadius="6" Background="#26FFFFFF" Padding="11,3,11,4" Margin="0,0,5,0">
              <TextBlock Text="+" FontFamily="Segoe UI" FontSize="12" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnSimdi" Cursor="Hand" CornerRadius="6" Background="#26FFFFFF" Padding="8,4,8,5" Margin="0,0,5,0">
              <TextBlock Text="@@PLAN_SIMDI@@" FontFamily="Segoe UI" FontSize="10" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnCikis" Cursor="Hand" CornerRadius="6" Background="#26FFFFFF" Padding="9,4,9,5">
              <TextBlock Text="✕" FontFamily="Segoe UI" FontSize="9.5" Foreground="#F0F4FA"/>
            </Border>
          </StackPanel>
          <TextBlock x:Name="PlanIpucu" FontFamily="Segoe UI" FontSize="8.5" Opacity="0.8"
                     Foreground="#E8EDF5" Margin="0,7,0,0" Text="@@PLAN_IPUCU@@"/>
        </StackPanel>
      </Border>
    </StackPanel>
  </Border>
</Window>
'@

# XAML'deki @@ANAHTAR@@ yer tutucuları dile göre dolduruluyor. Böylece her
# metin öğesine x:Name verip koddan tek tek atamak gerekmiyor.
foreach ($a in $METINLER[$DIL].Keys) { $xamlMetin = $xamlMetin.Replace("@@$a@@", $METINLER[$DIL][$a]) }
[xml]$xaml = $xamlMetin
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

function Get-Ogesi { param([string]$Ad) $win.FindName($Ad) }

# Tanı günlüğü — yalnızca SAAT_TANI=1 iken yazar (%TEMP%\masaustu-saat-tani.log)
function Write-Tani {
    param([string]$Mesaj)
    if ($env:SAAT_TANI -ne '1') { return }
    try {
        Add-Content -Path (Join-Path $env:TEMP 'masaustu-saat-tani.log') `
                    -Value ("{0:HH:mm:ss.fff}  {1}" -f [DateTime]::Now, $Mesaj) -Encoding UTF8
    } catch { }
}

$Kapsul      = Get-Ogesi 'Kapsul'
$KapsulGolge = Get-Ogesi 'KapsulGolge'
$Ayirici     = Get-Ogesi 'Ayirici'
$IkonIst     = Get-Ogesi 'IkonIst';  $AdIst = Get-Ogesi 'AdIst'
$TarihIst    = Get-Ogesi 'TarihIst'; $SaatIst = Get-Ogesi 'SaatIst'
$IkonLa      = Get-Ogesi 'IkonLa';   $AdLa  = Get-Ogesi 'AdLa'
$TarihLa     = Get-Ogesi 'TarihLa';  $SaatLa  = Get-Ogesi 'SaatLa'
$PlanSerit   = Get-Ogesi 'PlanSerit'; $PlanFark = Get-Ogesi 'PlanFark'
$PlanBaslik  = Get-Ogesi 'PlanBaslik'; $PlanIpucu = Get-Ogesi 'PlanIpucu'

$DijitalKok  = Get-Ogesi 'DijitalKok'; $AnalogKok = Get-Ogesi 'AnalogKok'
$IkonAnaUst  = Get-Ogesi 'IkonAnaUst'; $AdAnaUst  = Get-Ogesi 'AdAnaUst'
$SaatAnaUst  = Get-Ogesi 'SaatAnaUst'; $TarihAnaUst = Get-Ogesi 'TarihAnaUst'
$IkonAnaAlt  = Get-Ogesi 'IkonAnaAlt'; $AdAnaAlt  = Get-Ogesi 'AdAnaAlt'
$SaatAnaAlt  = Get-Ogesi 'SaatAnaAlt'; $TarihAnaAlt = Get-Ogesi 'TarihAnaAlt'

$script:Ayar = Get-Ayarlar

# Şehir anahtarlarını ŞİMDİ normalize et.
#
# Get-Sehir bilinmeyen anahtarda İstanbul'a düşüyor ama ayar nesnesi bozuk
# değeri taşımaya devam ediyordu: ekranda İSTANBUL yazıyor, menüde hiçbir
# şehir işaretli değil, ve bozuk değer her kayıtta geri yazılıyordu. Çözülmüş
# anahtarı geri yazmak bunu kalıcı olarak onarır (eski sürümlerden kalan
# AD tabanlı kayıtları da anahtara taşır).
$script:Ayar.sehirUst = (Get-Sehir -Anahtar $script:Ayar.sehirUst).Anahtar
$script:Ayar.sehirAlt = (Get-Sehir -Anahtar $script:Ayar.sehirAlt).Anahtar

# Seçili şehirlerin saat dilimleri. Şehir değiştiğinde yeniden çözülür.
$script:TzUst = Get-SehirDilimi -Anahtar $script:Ayar.sehirUst
$script:TzAlt = Get-SehirDilimi -Anahtar $script:Ayar.sehirAlt

function Update-SehirAdlari {
    $ustAd = (Get-SehirAdi (Get-Sehir -Anahtar $script:Ayar.sehirUst)).ToUpper($Kultur)
    $altAd = (Get-SehirAdi (Get-Sehir -Anahtar $script:Ayar.sehirAlt)).ToUpper($Kultur)
    $AdIst.Text = $ustAd;    $AdLa.Text = $altAd
    $AdAnaUst.Text = $ustAd; $AdAnaAlt.Text = $altAd
}

# ─────────────────────────────────────────────────────────────────────────────
# Analog kadran
#
# Çentikler ve ibreler XAML'de değil burada üretiliyor: 12 çentik × 2 kadran
# elle yazılacak 24 satır eder, ve ibrelerin dönüş merkezi zaten kadran
# boyutundan hesaplanıyor — tek yerde tutmak daha az hata demek.
#
# İbreler 12 yönünde (yukarı) çizilip RotateTransform ile döndürülüyor;
# böylece güncellemede tek bir Angle ataması yetiyor, geometri yeniden
# hesaplanmıyor.
# ─────────────────────────────────────────────────────────────────────────────
function New-Kadran {
    param($Tuval)

    $d = [double]$Tuval.Width
    $c = $d / 2

    $k = @{ Cerceve = $null; Centikler = New-Object System.Collections.ArrayList
            SaatIbre = $null; DakikaIbre = $null; Merkez = $null
            SaatDonus = $null; DakikaDonus = $null }

    $k.Cerceve = New-Object System.Windows.Shapes.Ellipse
    $k.Cerceve.Width = $d - 2
    $k.Cerceve.Height = $d - 2
    $k.Cerceve.StrokeThickness = 1
    $k.Cerceve.Opacity = 0.40
    [System.Windows.Controls.Canvas]::SetLeft($k.Cerceve, 1)
    [System.Windows.Controls.Canvas]::SetTop($k.Cerceve, 1)
    [void]$Tuval.Children.Add($k.Cerceve)

    # 12 çentik; 12/3/6/9 daha uzun ve kalın.
    for ($i = 0; $i -lt 12; $i++) {
        $a = $i * 30 * [Math]::PI / 180
        $anaCentik = ($i % 3 -eq 0)
        $rDis = $c - 4
        $rIc  = $rDis - $(if ($anaCentik) { 7 } else { 4 })
        $l = New-Object System.Windows.Shapes.Line
        $l.X1 = $c + $rIc  * [Math]::Sin($a); $l.Y1 = $c - $rIc  * [Math]::Cos($a)
        $l.X2 = $c + $rDis * [Math]::Sin($a); $l.Y2 = $c - $rDis * [Math]::Cos($a)
        $l.StrokeThickness = $(if ($anaCentik) { 1.8 } else { 1.0 })
        $l.Opacity = $(if ($anaCentik) { 0.85 } else { 0.55 })
        [void]$Tuval.Children.Add($l)
        [void]$k.Centikler.Add($l)
    }

    foreach ($tanim in @(@{ Ad = 'Saat'; Boy = $c * 0.50; Kalin = 3.2 },
                         @{ Ad = 'Dakika'; Boy = $c * 0.74; Kalin = 2.0 })) {
        $ib = New-Object System.Windows.Shapes.Line
        $ib.X1 = $c; $ib.Y1 = $c + 5        # merkezin biraz arkasından başlar
        $ib.X2 = $c; $ib.Y2 = $c - $tanim.Boy
        $ib.StrokeThickness = $tanim.Kalin
        $ib.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
        $ib.StrokeEndLineCap   = [System.Windows.Media.PenLineCap]::Round
        $dn = New-Object System.Windows.Media.RotateTransform
        $dn.CenterX = $c; $dn.CenterY = $c
        $ib.RenderTransform = $dn
        [void]$Tuval.Children.Add($ib)
        $k[($tanim.Ad + 'Ibre')]  = $ib
        $k[($tanim.Ad + 'Donus')] = $dn
    }

    $k.Merkez = New-Object System.Windows.Shapes.Ellipse
    $k.Merkez.Width = 5; $k.Merkez.Height = 5
    [System.Windows.Controls.Canvas]::SetLeft($k.Merkez, $c - 2.5)
    [System.Windows.Controls.Canvas]::SetTop($k.Merkez, $c - 2.5)
    [void]$Tuval.Children.Add($k.Merkez)

    return $k
}

function Set-KadranZamani {
    param($Kadran, [datetime]$Zaman)
    # Akrep dakikayla birlikte kayar (12:30'da tam 12 ile 1 arasında durur).
    $Kadran.SaatDonus.Angle   = ($Zaman.Hour % 12) * 30 + $Zaman.Minute * 0.5
    $Kadran.DakikaDonus.Angle = $Zaman.Minute * 6
}

function Set-KadranRenkleri {
    param($Kadran, $Sablon, [bool]$Vurgulu)
    # Planlama modunda ÜST kadranın ibreleri vurgu rengine geçiyor —
    # dijital görünümdeki amber saat ile aynı mantık.
    $ibre = Get-Firca $(if ($Vurgulu) { $Sablon.PlanVurguRenk } else { $Sablon.SaatRenk })
    $ikincil = Get-Firca $Sablon.MetinIkincil
    $Kadran.Cerceve.Stroke = $ikincil
    foreach ($c in $Kadran.Centikler) { $c.Stroke = $ikincil }
    $Kadran.SaatIbre.Stroke   = $ibre
    $Kadran.DakikaIbre.Stroke = $ibre
    $Kadran.Merkez.Fill       = $ibre
}

$script:KadranUst = New-Kadran (Get-Ogesi 'KadranUst')
$script:KadranAlt = New-Kadran (Get-Ogesi 'KadranAlt')

# Görünüm = yerleşim (dijital / analog). Şablondan bağımsız bir eksen.
function Set-Gorunum {
    param([string]$Ad)
    if (-not @('dijital', 'analog').Contains($Ad)) { $Ad = 'dijital' }
    $script:Ayar.gorunum = $Ad
    $analog = ($Ad -eq 'analog')
    $DijitalKok.Visibility = $(if ($analog) { 'Collapsed' } else { 'Visible' })
    $AnalogKok.Visibility  = $(if ($analog) { 'Visible' } else { 'Collapsed' })
    (Get-Ogesi 'MnuGorunumDijital').IsChecked = (-not $analog)
    (Get-Ogesi 'MnuGorunumAnalog').IsChecked  = $analog
    # Pencere SizeToContent olduğu için boyut kendiliğinden değişiyor.
    $script:SonCizimAnahtari = $null
    Update-Saat
}

# ─────────────────────────────────────────────────────────────────────────────
# Windows açılışında başlat
#
# Durumun TEK KAYNAĞI Başlangıç klasöründeki kısayolun VARLIĞI — ayarlar.json'a
# ayrıca bir bayrak yazmıyoruz. Yazsaydık iki doğruluk kaynağı olurdu ve
# kullanıcı kur-baslangic.ps1 / kaldir-baslangic.ps1'i elle çalıştırdığında
# menüdeki tik gerçeği yansıtmazdı.
#
# Kayıt defterine dokunulmuyor; projenin geri kalanı gibi yalnızca Başlangıç
# klasörü kullanılıyor.
#
# DİKKAT: Kısayolun içeriği kur-baslangic.ps1'deki New-Kisayol ile AYNI
# olmalı (conhost.exe üzerinden çağırma dahil — bkz. oradaki açıklama).
# İkisi ayrı duruyor çünkü saat.ps1'in açılış yolunda başka bir dosyaya
# bağımlı olmaması gerekiyor.
# ─────────────────────────────────────────────────────────────────────────────
$BaslangicKlasor  = [Environment]::GetFolderPath('Startup')
$BaslangicKisayol = Join-Path $BaslangicKlasor 'Dual Clock.lnk'

# Kisayol 'Masaustu Saat.lnk' adiyla kurulmustu. Eski adi da taniyoruz ki
# yukseltmeden sonra menudeki tik yanlis gostermesin ve kapatinca gercekten
# kapansin (yoksa eski kisayol sessizce acilista calismaya devam ederdi).
$BaslangicEskiler = @('Masaustu Saat.lnk') | ForEach-Object { Join-Path $BaslangicKlasor $_ }

# Kisayol ikonu betigin yanindaki dual-clock.ico. Dosya yoksa (birisi yalnizca
# saat.ps1'i kopyalamis olabilir) shell32'deki saat ikonuna dusuyoruz.
function Get-IkonYolu {
    param([string]$BetikYolu)
    $ico = Join-Path (Split-Path -Parent $BetikYolu) 'dual-clock.ico'
    if (Test-Path $ico) { return $ico }
    return (Join-Path $env:WINDIR 'System32\shell32.dll,14')
}

function Test-BaslangictaBasliyorMu {
    if (Test-Path $BaslangicKisayol) { return $true }
    foreach ($eski in $BaslangicEskiler) { if (Test-Path $eski) { return $true } }
    return $false
}

function Set-BaslangictaBaslat {
    param([bool]$Ac)
    try {
        if ($Ac) {
            $betik = $PSCommandPath
            $psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $sh  = New-Object -ComObject WScript.Shell
            $lnk = $sh.CreateShortcut($BaslangicKisayol)
            $lnk.TargetPath       = Join-Path $env:WINDIR 'System32\conhost.exe'
            $lnk.Arguments        = "$psExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$betik`""
            $lnk.WorkingDirectory = Split-Path -Parent $betik
            $lnk.Description      = 'Dual Clock - Windows acilisinda baslar'
            $lnk.IconLocation     = Get-IkonYolu -BetikYolu $betik
            $lnk.WindowStyle      = 7
            $lnk.Save()
            # Eski adli kisayol kalirsa iki kez acilmaya calisirdi.
            foreach ($eski in $BaslangicEskiler) { if (Test-Path $eski) { Remove-Item $eski -Force } }
        } else {
            if (Test-Path $BaslangicKisayol) { Remove-Item $BaslangicKisayol -Force }
            foreach ($eski in $BaslangicEskiler) { if (Test-Path $eski) { Remove-Item $eski -Force } }
        }
    } catch {
        Write-Tani ('baslangic kisayolu degistirilemedi: ' + $_.Exception.Message)
    }
    # Tiki DOSYA SİSTEMİNDEN tazele: yazma/silme başarısız olduysa menü
    # gerçekleşmemiş bir durumu göstermesin.
    Sync-BaslangicTiki
}

function Sync-BaslangicTiki {
    (Get-Ogesi 'MnuBaslangic').IsChecked = (Test-BaslangictaBasliyorMu)
}

function Set-ArkaPlan {
    param([string]$Ad)
    if (-not @('yok', 'hafif', 'koyu').Contains($Ad)) { $Ad = 'hafif' }
    $script:Ayar.arkaPlan = $Ad
    $s = Get-MevcutSablon
    $bgHex = switch ($Ad) {
        'yok'   { $s.BgYok }
        'hafif' { $s.BgHafif }
        'koyu'  { $s.BgKoyu }
    }
    $Kapsul.Background = Get-Firca $bgHex
    (Get-Ogesi 'MnuBgYok').IsChecked   = ($Ad -eq 'yok')
    (Get-Ogesi 'MnuBgHafif').IsChecked = ($Ad -eq 'hafif')
    (Get-Ogesi 'MnuBgKoyu').IsChecked  = ($Ad -eq 'koyu')
}

function Set-Sablon {
    param([string]$Ad)
    # 'apple-auto' gerçek bir palet değil ama geçerli bir SEÇİM — ayarda o
    # saklanır, palet çalışma anında sistemden çözülür.
    if ($Ad -ne $SABLON_OTO -and -not $SABLONLAR.Contains($Ad)) { $Ad = 'apple-dark' }
    $script:Ayar.sablon = $Ad
    $s = $SABLONLAR[(Resolve-SablonAdi $Ad)]

    $Kapsul.CornerRadius = New-Object System.Windows.CornerRadius($s.KoseYaricap)
    $Kapsul.BorderThickness = New-Object System.Windows.Thickness($s.KenarlikKalinlik)
    $Kapsul.BorderBrush = Get-Firca $s.KenarlikFirca

    if ($null -ne $KapsulGolge) {
        $KapsulGolge.Color = [Windows.Media.ColorConverter]::new().ConvertFromString($s.GolgeRenk)
        $KapsulGolge.BlurRadius = $s.GolgeBulaniklik
        $KapsulGolge.Opacity = $s.GolgeOpaklik
        $KapsulGolge.ShadowDepth = $s.GolgeDerinlik
    }

    if ($null -ne $Ayirici) {
        $Ayirici.Fill = Get-Firca $s.AyiriciRenk
    }

    $AdIst.Foreground = Get-Firca $s.MetinAna
    $AdLa.Foreground  = Get-Firca $s.MetinAna
    $TarihIst.Foreground = Get-Firca $s.MetinIkincil
    $TarihLa.Foreground  = Get-Firca $s.MetinIkincil

    $PlanSerit.Background = Get-Firca $s.PlanZemin

    # Planlama şeridinin üç metni. Bunlar eskiden XAML'de sabit koyu-tema
    # renkleriyle duruyordu; Apple Açık'ta beyaz zemin üstünde beyaz metin
    # oluyordu (kontrast ~1.03:1, yani görünmez). Başlık vurgu rengini,
    # diğer ikisi ikincil metin rengini alıyor.
    $PlanBaslik.Foreground = Get-Firca $s.PlanVurguRenk
    $PlanFark.Foreground   = Get-Firca $s.MetinIkincil
    $PlanIpucu.Foreground  = Get-Firca $s.MetinIkincil

    foreach ($btnAd in @('BtnEksi', 'BtnArti', 'BtnSimdi', 'BtnCikis')) {
        $b = Get-Ogesi $btnAd
        if ($null -ne $b) {
            $b.Background = Get-Firca $s.PlanButonZemin
            $txt = $b.Child
            if ($txt -is [System.Windows.Controls.TextBlock]) {
                $txt.Foreground = Get-Firca $s.PlanButonMetin
            }
        }
    }

    Set-ArkaPlan $script:Ayar.arkaPlan
    # Update-Saat aynı dakika için çizimi atlıyor; tema değişince zorla yeniden çiz.
    $script:SonCizimAnahtari = $null
    Update-Saat

    (Get-Ogesi 'MnuSablonAppleOto').IsChecked   = ($Ad -eq $SABLON_OTO)
    (Get-Ogesi 'MnuSablonAppleDark').IsChecked  = ($Ad -eq 'apple-dark')
    (Get-Ogesi 'MnuSablonAppleLight').IsChecked = ($Ad -eq 'apple-light')
    (Get-Ogesi 'MnuSablonKehribar').IsChecked   = ($Ad -eq 'kehribar')
    (Get-Ogesi 'MnuSablonNeon').IsChecked       = ($Ad -eq 'neon')
    (Get-Ogesi 'MnuSablonKlasik').IsChecked     = ($Ad -eq 'klasik')
}

# ─────────────────────────────────────────────────────────────────────────────
# Saat güncelleme
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# Planlama modu
#
# Bir şehirde saat belirlersiniz ("çapa"), diğerinin karşılığı görünür.
# Pencere odak almadığı için klavyeyle saat yazılamaz; kontroller fare ile.
# ─────────────────────────────────────────────────────────────────────────────
$script:PlanModu  = $false

# PLAN ZAMANININ TEK DOĞRULUK KAYNAĞI: BİR UTC ANI.
#
# Önceki sürüm bunu "çapa şehrinin duvar saati" olarak tutuyordu ve yaz saati
# geçişlerinde bozuluyordu — çünkü duvar saati ile an arasında birebir eşleme
# YOKTUR: ileri alma gecesinde bir saat hiç yaşanmaz, geri alma gecesinde bir
# saat iki kez yaşanır.
#
# Somut hata (çapa Londra, diğer New York, 28 Mart 2027, +15 dk ile ilerleme):
#     00:45 Londra → 20:45 NY      fark 4 sa
#     01:00 Londra → 21:00 NY      ← 01:00 Londra'da O GECE YOK
#     01:45 Londra → 21:45 NY
#     02:00 Londra → 21:00 NY      ← karşı saat 45 DAKİKA GERİ gitti
# Geri alma gecesinde de ters yönde: +15 dk basınca karşı saat 75 dk ileri
# atlıyordu, çünkü .NET belirsiz saatte sessizce standart ofseti seçiyor.
#
# Kök sebep, Convert-Zaman'ın IsInvalidTime düzeltmesini YEREL BİR KOPYAYA
# uygulayıp çapanın kendisini geçersiz değerde bırakmasıydı.
#
# An'ı UTC olarak tutunca sorun tanım gereği ortadan kalkıyor:
#   • adım atmak = UTC'ye dakika eklemek → her iki şehir de tam adım kadar
#     ilerler, asla geri gitmez, fark her zaman doğru,
#   • geçersiz/belirsiz duvar saati diye bir durum oluşmaz,
#   • çapa değiştirmek BEDAVA — an zaten ortak, çevirmeye gerek yok.
# İleri alma gecesinde çapa satırı 00:45'ten 02:00'a atlar; bu bir hata değil,
# o gece saatlerin gerçekten yaptığı şey.
$script:PlanUtc = $null       # Kind = Utc

# Duvar saatini güvenle UTC'ye çevirir: geçersiz saat (ileri alma gecesinde
# yaşanmayan saat) bir saat ileri alınır. Yalnızca "şimdi" ve gün adımı gibi
# duvar saatinden AN üretmek gereken yerlerde kullanılır.
function ConvertTo-UtcGuvenli {
    param([datetime]$Yerel, $Dilim)
    $u = [DateTime]::SpecifyKind($Yerel, [DateTimeKind]::Unspecified)
    if ($Dilim.IsInvalidTime($u)) { $u = $u.AddHours(1) }
    return [TimeZoneInfo]::ConvertTimeToUtc($u, $Dilim)
}

function Get-YuvarlaOnBes {
    param([datetime]$T)
    $kalan = $T.Minute % 15
    $ekle = if ($kalan -gt 0 -or $T.Second -gt 0 -or $T.Millisecond -gt 0) { 15 - $kalan } else { 0 }
    return $T.AddSeconds(-$T.Second).AddMilliseconds(-$T.Millisecond).AddMinutes($ekle)
}

function Reset-PlanZamani {
    $dilim = $script:TzUst
    $simdi = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $dilim)
    # Yuvarlama ÜST SATIRIN duvar saatinde yapılıyor — ayarlanan satır o.
    # (Yarım saatlik ofsetli şehirlerde — Delhi +5:30 — alt satır :15/:45'e
    # düşer; bu doğrudur.)
    $script:PlanUtc = ConvertTo-UtcGuvenli -Yerel (Get-YuvarlaOnBes -T $simdi) -Dilim $dilim
}

function Set-PlanModu {
    param([bool]$Ac)
    $script:PlanModu = $Ac
    if ($Ac) {
        if ($null -eq $script:PlanUtc) { Reset-PlanZamani }
    } else {
        # Kapatılınca eski plan zamanını sıfırla; bir sonraki açılış güncel saatten başlasın
        $script:PlanUtc = $null
    }
    $PlanSerit.Visibility = $(if ($Ac) { 'Visible' } else { 'Collapsed' })
    (Get-Ogesi 'MnuPlan').IsChecked = $Ac
    Update-Saat
}

# Dakika adımı: doğrudan AN'a ekleniyor. Her iki şehir de tam olarak bu kadar
# ilerler; yaz saati geçişi olsa bile hiçbir satır geri gitmez.
function Add-PlanDakika {
    param([int]$Dakika)
    if (-not $script:PlanModu -or $null -eq $script:PlanUtc) { return }
    $script:PlanUtc = $script:PlanUtc.AddMinutes($Dakika)
    Update-Saat
}

# Aynı dakika için yeniden çizimi atlamak üzere son çizilen durumun imzası.
# Zamanlayıcı saniyede bir tetikleniyor ama ekranda yalnızca HH:mm var.
$script:SonCizimAnahtari = $null

function Update-Saat {
    if ($script:PlanModu -and $null -ne $script:PlanUtc) {
        $an = $script:PlanUtc
    } else {
        $an = [DateTime]::UtcNow
    }
    # Tek an, iki şehir. Çapa hangisi olursa olsun ikisi de aynı kaynaktan
    # türediği için fark her zaman tutarlı.
    $ist = [TimeZoneInfo]::ConvertTimeFromUtc($an, $script:TzUst)
    $la  = [TimeZoneInfo]::ConvertTimeFromUtc($an, $script:TzAlt)

    $anahtar = '{0:yyyyMMddHHmm}|{1:yyyyMMddHHmm}|{2}' -f `
               $ist, $la, $script:PlanModu
    if ($anahtar -eq $script:SonCizimAnahtari) { return }
    $script:SonCizimAnahtari = $anahtar

    $SaatIst.Text  = $ist.ToString('HH:mm', $Kultur)
    $TarihIst.Text = $ist.ToString('d MMM ddd', $Kultur)
    $SaatLa.Text   = $la.ToString('HH:mm', $Kultur)
    $TarihLa.Text  = $la.ToString('d MMM ddd', $Kultur)

    $dIst = Get-GunDurumu -Yerel $ist
    $IkonIst.Text = $dIst.Ikon
    $IkonIst.Foreground = Get-Firca $dIst.Renk

    $dLa = Get-GunDurumu -Yerel $la
    $IkonLa.Text = $dLa.Ikon
    $IkonLa.Foreground = Get-Firca $dLa.Renk

    # Analog gövde aynı değerlerden besleniyor. Görünüm gizliyse de doldurmak
    # ucuz (dakikada bir) ve görünüme geçildiği an doğru olmasını garanti eder.
    $SaatAnaUst.Text = $SaatIst.Text; $TarihAnaUst.Text = $TarihIst.Text
    $SaatAnaAlt.Text = $SaatLa.Text;  $TarihAnaAlt.Text = $TarihLa.Text
    $IkonAnaUst.Text = $dIst.Ikon;    $IkonAnaUst.Foreground = Get-Firca $dIst.Renk
    $IkonAnaAlt.Text = $dLa.Ikon;     $IkonAnaAlt.Foreground = Get-Firca $dLa.Renk
    Set-KadranZamani $script:KadranUst $ist
    Set-KadranZamani $script:KadranAlt $la

    # AYARLANAN SATIR HER ZAMAN ÜST SATIR. Planlama modunda üst satırın saati
    # vurgu rengiyle yanar (analog görünümde üst kadranın ibreleri); alt satır
    # sonucu gösterir ve normal saat rengini korur.
    $sablon = Get-MevcutSablon
    $normal = Get-Firca $sablon.SaatRenk
    $vurgu  = Get-Firca $sablon.PlanVurguRenk
    $ustVurgulu = $script:PlanModu

    $SaatIst.Foreground    = $(if ($ustVurgulu) { $vurgu } else { $normal })
    $SaatLa.Foreground     = $normal
    $SaatAnaUst.Foreground = $(if ($ustVurgulu) { $vurgu } else { $normal })
    $SaatAnaAlt.Foreground = $normal
    Set-KadranRenkleri $script:KadranUst $sablon $ustVurgulu
    Set-KadranRenkleri $script:KadranAlt $sablon $false

    if ($script:PlanModu) {
        $farkSaat = [Math]::Abs(($ist - $la).TotalHours)
        # Ondalık ayırıcı $Kultur'den: saat ve tarih de onunla biçimlendiriliyor.
        # "{0:0.#}" iş parçacığı kültürünü kullanır; görüntü dili ile bölgesel
        # biçim farklı olduğunda (İngilizce arayüz + Türkçe biçim) tutarsızlık
        # çıkıyordu — Delhi gibi yarım saatlik ofsetlerde görünür.
        $farkMetin = if ($farkSaat % 1 -eq 0) { ([int]$farkSaat).ToString($Kultur) }
                     else { $farkSaat.ToString('0.#', $Kultur) }
        $PlanFark.Text = ((T 'PLAN_FARK') -f $farkMetin)
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Masaüstü seviyesi
#
# Not: Pencereyi SetParent ile Progman'ın çocuğu yapmak (klasik "wallpaper
# widget" numarası) WPF'te iki sorun çıkardı — koordinatlar ebeveyne göreli
# hâle gelip pencere ekran dışına kaçıyor, ve explorer.exe ile aynı girdi
# kuyruğuna bağlanmak kilitlenme riski taşıyor. Bunun yerine pencere normal
# üst düzey pencere olarak kalıyor ama:
#   • WS_EX_NOACTIVATE  → tıklayınca öne gelmez, odağı çalmaz
#   • WS_EX_TOOLWINDOW  → Alt+Tab ve görev çubuğunda görünmez
#   • HWND_BOTTOM       → z-sırasının dibinde, tüm uygulamaların altında durur
# Sonuç kullanıcı açısından aynı: masaüstünde durur, hiçbir işin önünü kesmez.
# ─────────────────────────────────────────────────────────────────────────────
function Get-Tutamac {
    return (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
}

function Set-MasaustuSeviyesi {
    $hwnd = Get-Tutamac
    if ($hwnd -eq [IntPtr]::Zero) { return }

    $ex = [Widget.Win32]::GetWindowLong($hwnd, $GWL_EXSTYLE)
    [void][Widget.Win32]::SetWindowLong($hwnd, $GWL_EXSTYLE,
        ($ex -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE))

    # Bundan sonrasını mesaj kancası hallediyor — periyodik yoklama YOK.
    [ZDuzeniSaat]::Bagla($hwnd)
    Push-Dibe
}

# Yalnızca başlangıçta bir kez çağrılır. Düzenli aralıkla çağırmayın:
# masaüstü sağ tık menüsünü kapatır ve simge seçimini bozar.
function Push-Dibe {
    $hwnd = Get-Tutamac
    if ($hwnd -eq [IntPtr]::Zero) { return }

    if ([Widget.Win32]::IsIconic($hwnd)) {
        [void][Widget.Win32]::ShowWindow($hwnd, $SW_SHOWNOACTIVATE)
    }

    [void][Widget.Win32]::SetWindowPos($hwnd, $HWND_BOTTOM, 0, 0, 0, 0,
        ($SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_NOACTIVATE))
}

# ─────────────────────────────────────────────────────────────────────────────
# Konumlandırma + sürükleme
# ─────────────────────────────────────────────────────────────────────────────
function Get-DpiOlcegi {
    $kaynak = [System.Windows.PresentationSource]::FromVisual($win)
    if ($null -ne $kaynak -and $null -ne $kaynak.CompositionTarget) {
        return $kaynak.CompositionTarget.TransformToDevice.M11
    }
    return 1.0
}

# Konumun tek doğruluk kaynağı: ekran koordinatı, DIP cinsinden.
$script:KonumSol = 0.0
$script:KonumUst = 0.0

function Set-PencereKonumu {
    param([double]$Sol, [double]$Ust)

    $script:KonumSol = $Sol
    $script:KonumUst = $Ust
    $win.Left = $Sol
    $win.Top  = $Ust
}

function Set-VarsayilanKonum {
    $win.UpdateLayout()
    $g = if ([double]::IsNaN($win.ActualWidth) -or $win.ActualWidth -le 0) { 250 } else { $win.ActualWidth }
    Write-Tani ("VarsayilanKonum: ActualWidth={0} ekranDIP={1}x{2} olcek={3}" -f `
        $win.ActualWidth, [System.Windows.SystemParameters]::PrimaryScreenWidth,
        [System.Windows.SystemParameters]::PrimaryScreenHeight, (Get-DpiOlcegi))
    Set-PencereKonumu -Sol ([Math]::Max(0, [System.Windows.SystemParameters]::PrimaryScreenWidth - $g - 28)) -Ust 28
}

$script:surukle = $null

$win.Add_MouseLeftButtonDown({
    $p = New-Object 'Widget.Win32+POINT'
    if ([Widget.Win32]::GetCursorPos([ref]$p)) {
        $script:surukle = @{ mx = $p.X; my = $p.Y; sol = $script:KonumSol; ust = $script:KonumUst }
        [void]$win.CaptureMouse()
    }
})

$win.Add_MouseMove({
    if ($null -ne $script:surukle) {
        $p = New-Object 'Widget.Win32+POINT'
        if ([Widget.Win32]::GetCursorPos([ref]$p)) {
            $olcek = Get-DpiOlcegi
            Set-PencereKonumu -Sol ($script:surukle.sol + ($p.X - $script:surukle.mx) / $olcek) `
                              -Ust ($script:surukle.ust + ($p.Y - $script:surukle.my) / $olcek)
        }
    }
})

$win.Add_MouseLeftButtonUp({
    if ($null -ne $script:surukle) {
        $win.ReleaseMouseCapture()
        $script:surukle = $null
        $script:Ayar.sol = $script:KonumSol
        $script:Ayar.ust = $script:KonumUst
        Save-Ayarlar -Ayar $script:Ayar
    }
})

$win.Add_LostMouseCapture({
    $script:surukle = $null
})

# ─────────────────────────────────────────────────────────────────────────────
# Menü olayları
# ─────────────────────────────────────────────────────────────────────────────
(Get-Ogesi 'MnuSablonAppleOto').Add_Click({   Set-Sablon $SABLON_OTO;   Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuSablonAppleDark').Add_Click({  Set-Sablon 'apple-dark';  Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuSablonAppleLight').Add_Click({ Set-Sablon 'apple-light'; Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuSablonKehribar').Add_Click({   Set-Sablon 'kehribar';    Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuSablonNeon').Add_Click({       Set-Sablon 'neon';        Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuSablonKlasik').Add_Click({     Set-Sablon 'klasik';      Save-Ayarlar -Ayar $script:Ayar })

(Get-Ogesi 'MnuGorunumDijital').Add_Click({ Set-Gorunum 'dijital'; Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuGorunumAnalog').Add_Click({  Set-Gorunum 'analog';  Save-Ayarlar -Ayar $script:Ayar })

(Get-Ogesi 'MnuBgYok').Add_Click({   Set-ArkaPlan 'yok';   Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuBgHafif').Add_Click({ Set-ArkaPlan 'hafif'; Save-Ayarlar -Ayar $script:Ayar })
(Get-Ogesi 'MnuBgKoyu').Add_Click({  Set-ArkaPlan 'koyu';  Save-Ayarlar -Ayar $script:Ayar })

(Get-Ogesi 'MnuSifirla').Add_Click({
    Set-VarsayilanKonum
    $script:Ayar.sol = $script:KonumSol
    $script:Ayar.ust = $script:KonumUst
    Save-Ayarlar -Ayar $script:Ayar
})

# Şehir menüleri kodla üretiliyor: 25 şehir × 2 satır = 50 XAML satırı yerine
# tek kaynak. Widget klavye odağı almadığı için şehir ADI YAZILAMAZ, listeden
# seçilir — eşik menüsündeki ile aynı kısıt.
# TUZAK: Bu gövde bilerek ayrı bir fonksiyonda duruyor.
#
# Menü tıklama işleyicisi .GetNewClosure() ile kuruluyor ve closure YENİ BİR
# MODÜL KAPSAMINA bağlanıyor — orada `$script:` artık betiğin script kapsamı
# değildir. Closure içinde `$script:Ayar.sehirUst = ...` yazmak `$null`a yazmak
# demekti ve widget çöküyordu. Aynı sebeple `$script:TzUst` ataması da gerçek
# betik değişkenine ulaşmıyordu.
#
# Closure artık yalnızca yerel değişkenleri ($Alan, $Kok) taşıyıp bu fonksiyonu
# çağırıyor; `$script:` erişimi normal betik kapsamında kalıyor.
function Set-SehirSecimi {
    param([string]$Alan, [string]$Anahtar, $Kok)

    $script:Ayar.$Alan = $Anahtar
    $script:TzUst = Get-SehirDilimi -Anahtar $script:Ayar.sehirUst
    $script:TzAlt = Get-SehirDilimi -Anahtar $script:Ayar.sehirAlt

    # Şehir değiştiğinde plan zamanını sıfırla — eski şehrin zaman dilimiyle karışmasın.
    if ($script:PlanModu) { Reset-PlanZamani } else { $script:PlanUtc = $null }

    Update-SehirAdlari
    Update-Saat
    Save-Ayarlar -Ayar $script:Ayar

    # Menüyü yeniden kurmuyoruz (tıklanan öğe hâlâ olayı işliyor); işaretleri
    # yerinde güncelliyoruz.
    foreach ($oge in $Kok.Items) { $oge.IsChecked = ([string]$oge.Tag -eq $Anahtar) }
}

function Build-SehirMenusu {
    param($Kok, [string]$Alan)

    $Kok.Items.Clear()
    foreach ($s in $SEHIRLER) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = Get-SehirAdi $s
        $mi.IsCheckable = $true
        $mi.IsChecked = ($script:Ayar.$Alan -eq $s.Anahtar)
        $mi.Tag = $s.Anahtar
        $mi.Add_Click({
            param($snd, $e)
            Set-SehirSecimi -Alan $Alan -Anahtar ([string]$snd.Tag) -Kok $Kok
        }.GetNewClosure())
        [void]$Kok.Items.Add($mi)
    }
}

Build-SehirMenusu -Kok (Get-Ogesi 'MnuSehirUst') -Alan 'sehirUst'
Build-SehirMenusu -Kok (Get-Ogesi 'MnuSehirAlt') -Alan 'sehirAlt'
Write-Tani ("sehir menusu: ust={0} alt={1} oge" -f `
    (Get-Ogesi 'MnuSehirUst').Items.Count, (Get-Ogesi 'MnuSehirAlt').Items.Count)
(Get-Ogesi 'MnuPlan').Add_Click({ Set-PlanModu (-not $script:PlanModu) })

# Buton: basma olayını "handled" işaretlemezsek pencere sürükleme kodu devreye
# girer ve butona basınca widget kayar.
function Register-Dugme {
    param($Oge, [scriptblock]$Eylem)
    $Oge.Add_MouseEnter({
        param($s, $e)
        $Oge.Background = Get-Firca (Get-MevcutSablon).PlanButonHover
    }.GetNewClosure())
    $Oge.Add_MouseLeave({
        param($s, $e)
        $Oge.Background = Get-Firca (Get-MevcutSablon).PlanButonZemin
    }.GetNewClosure())
    $Oge.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true })
    $Oge.Add_MouseLeftButtonUp({ param($s, $e) $e.Handled = $true; & $Eylem }.GetNewClosure())
}

Register-Dugme (Get-Ogesi 'BtnEksi')  { Add-PlanDakika -15 }
Register-Dugme (Get-Ogesi 'BtnArti')  { Add-PlanDakika 15 }
Register-Dugme (Get-Ogesi 'BtnSimdi') { Reset-PlanZamani; Update-Saat }
Register-Dugme (Get-Ogesi 'BtnCikis') { Set-PlanModu $false }

function Test-Tus { param([int]$Kod) return (([Widget.Win32]::GetKeyState($Kod) -band 0x8000) -ne 0) }

# Fare tekerleği: 15 dk, Shift ile 1 saat.
# (Windows'un "üzerine gelince etkin olmayan pencereleri kaydır" ayarı kapalıysa
#  tekerlek gelmeyebilir — o yüzden − / + butonları da var.)
$win.Add_MouseWheel({
    param($s, $e)
    if (-not $script:PlanModu) { return }
    $yon  = $(if ($e.Delta -gt 0) { 1 } else { -1 })
    $adim = $(if (Test-Tus 0x10) { 60 } else { 15 })   # Shift → 1 saat
    Add-PlanDakika ($adim * $yon)
    $e.Handled = $true
})
(Get-Ogesi 'MnuBaslangic').Add_Click({ Set-BaslangictaBaslat (-not (Test-BaslangictaBasliyorMu)) })

(Get-Ogesi 'MnuKapat').Add_Click({ $win.Close() })

# ─────────────────────────────────────────────────────────────────────────────
# Sağ tık menüsü kapatma nöbetçisi
#
# Pencere WS_EX_NOACTIVATE ile çalıştığı için hiçbir zaman odak almıyor.
# WPF'in "dışarı tıklanınca menüyü kapat" mekanizması odak / fare yakalama
# kaybına dayandığından bizde hiç tetiklenmiyor ve menü ekranda asılı kalıyordu.
# Menü açıkken fareyi yoklayıp dışarıdaki ilk tıklamada elle kapatıyoruz.
# "Dışarısı" = tıklanan noktadaki pencere bize ait değilse (alt menüler de bizim
# sürecimize ait olduğu için yanlışlıkla kapanmaz; widget'a tıklamak kapatır).
# ─────────────────────────────────────────────────────────────────────────────
$script:OncekiBasili = $true

$menuIzleyici = New-Object System.Windows.Threading.DispatcherTimer
$menuIzleyici.Interval = [TimeSpan]::FromMilliseconds(100)
$menuIzleyici.Add_Tick({
    $menu = $win.ContextMenu
    if ($null -eq $menu -or -not $menu.IsOpen) { $menuIzleyici.Stop(); return }

    $basili = ((([Widget.Win32]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0) -or
               (([Widget.Win32]::GetAsyncKeyState(0x02) -band 0x8000) -ne 0))

    if ($basili -and -not $script:OncekiBasili) {
        $p = New-Object 'Widget.Win32+POINT'
        if ([Widget.Win32]::GetCursorPos([ref]$p)) {
            $h = [Widget.Win32]::WindowFromPoint($p)
            $sahip = 0
            [void][Widget.Win32]::GetWindowThreadProcessId($h, [ref]$sahip)
            if ($sahip -ne $PID -or $h -eq (Get-Tutamac)) {
                $menu.IsOpen = $false
                Write-Tani 'menu disariya tiklandigi icin kapatildi'
            }
        }
    }
    $script:OncekiBasili = $basili
})

$win.ContextMenu.Add_Opened({
    $script:OncekiBasili = $true
    # Kısayol dışarıdan (kur-/kaldir-baslangic.ps1 ya da elle) değişmiş
    # olabilir; tiki her açılışta dosya sisteminden tazeliyoruz.
    Sync-BaslangicTiki
    $menuIzleyici.Start()
})
$win.ContextMenu.Add_Closed({ $menuIzleyici.Stop() })

# ─────────────────────────────────────────────────────────────────────────────
# Zamanlayıcı: saat güncelleme (1 sn)
#
# Aralık bilerek 1 saniye: dakika değişimini gecikmesiz yakalamanın en basit
# yolu. Ekranda yalnızca HH:mm olduğu için Update-Saat aynı dakika içindeki
# tiklerde $script:SonCizimAnahtari'na bakıp hemen çıkıyor — geriye iki
# zaman dilimi çevrimi ve bir dizgi karşılaştırması kalıyor.
# ─────────────────────────────────────────────────────────────────────────────
$saatTimer = New-Object System.Windows.Threading.DispatcherTimer
$saatTimer.Interval = [TimeSpan]::FromSeconds(1)
$saatTimer.Add_Tick({ Update-Saat })

# ─────────────────────────────────────────────────────────────────────────────
# Sistem teması izleyici — yalnızca "Apple Otomatik" seçiliyken iş yapar.
#
# Yoklama yerine olay: Windows açık/koyu tema değiştiğinde
# UserPreferenceChanged tetikleniyor. Olay BAŞKA bir iş parçacığından
# geliyor, bu yüzden arayüze dokunmadan önce dispatcher'a geçiyoruz.
# ─────────────────────────────────────────────────────────────────────────────
$script:SistemTemaIzleyici = $null
try {
    $script:SistemTemaIzleyici = [Microsoft.Win32.UserPreferenceChangedEventHandler]{
        param($gonderen, $olay)
        $win.Dispatcher.BeginInvoke([Action]{
            if ($script:Ayar.sablon -eq $SABLON_OTO) {
                Set-Sablon $SABLON_OTO
                Write-Tani ("sistem temasi degisti -> {0}" -f (Resolve-SablonAdi $SABLON_OTO))
            }
        }) | Out-Null
    }
    [Microsoft.Win32.SystemEvents]::add_UserPreferenceChanged($script:SistemTemaIzleyici)
} catch {
    # SystemEvents kullanılamazsa otomatik tema yalnızca açılışta çözülür;
    # elle tema seçmek her zaman çalışır.
    $script:SistemTemaIzleyici = $null
    Write-Tani ("sistem temasi izleyici kurulamadi: " + $_.Exception.Message)
}

# Win+D ("masaüstünü göster") pencereyi küçültür. Yoklama yerine olayı
# dinliyoruz — küçültüldüğü anda geri aç.
$win.Add_StateChanged({
    if ($win.WindowState -eq [System.Windows.WindowState]::Minimized) {
        $win.WindowState = [System.Windows.WindowState]::Normal
    }
})

# ─────────────────────────────────────────────────────────────────────────────
# Başlat
# ─────────────────────────────────────────────────────────────────────────────
Set-Sablon $script:Ayar.sablon
Set-ArkaPlan $script:Ayar.arkaPlan
Set-Gorunum $script:Ayar.gorunum
Sync-BaslangicTiki
Update-SehirAdlari
Update-Saat

# Planlama modu bilerek KALICI DEĞİL: açılışta donmuş bir saat görüp
# "widget bozulmuş" sanmayın diye her başlangıçta canlı moddan başlar.
# Test/tanı için SAAT_PLAN=1 ile açık başlatılabilir.
if ($env:SAAT_PLAN -eq '1') { Set-PlanModu $true }

# Öz-test (SAAT_OTOTEST=1): butonların olay bağlantısını ekran geometrisinden
# BAĞIMSIZ olarak sınar. Dışarıdan fareyle tıklayarak test etmek yanıltıcıdır —
# widget z-sırasının dibinde olduğu için tıklama üstteki pencereye gider.
function Invoke-Tik {
    param($Oge)
    $ea = New-Object System.Windows.Input.MouseButtonEventArgs `
        ([System.Windows.Input.Mouse]::PrimaryDevice, 0, [System.Windows.Input.MouseButton]::Left)
    $ea.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
    $Oge.RaiseEvent($ea)
}

$win.Add_ContentRendered({
    # Öz-test (SAAT_SEHIRTEST=1): şehir menüsü öğesine GERÇEKTEN tıklar.
    if ($env:SAAT_SEHIRTEST -eq '1') {
        try {
            $hedef = (Get-Ogesi 'MnuSehirUst').Items | Where-Object { [string]$_.Tag -eq 'tokyo' } | Select-Object -First 1
            Write-Tani ("SEHIRTEST once : sehirUst=$($script:Ayar.sehirUst) hedefVar=$($null -ne $hedef)")
            $hedef.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.MenuItem]::ClickEvent)))
            Write-Tani ("SEHIRTEST sonra: sehirUst=$($script:Ayar.sehirUst) ekran=$($AdIst.Text) saat=$($SaatIst.Text)")
        } catch {
            Write-Tani ("SEHIRTEST HATA: " + $_.Exception.Message)
        }
    }

    if ($env:SAAT_OTOTEST -ne '1') { return }
    $win.UpdateLayout()

    # Plan zamanı artık bir UTC anı; günlüğe İKİ SATIRIN gördüğü yerel saatle
    # birlikte yazılıyor — hatalar orada görünür hâle geliyor.
    function Get-OztestDurum {
        if ($null -eq $script:PlanUtc) { return 'zaman=<yok>' }
        return ('utc={0:yyyy-MM-dd HH:mm} ust={1} alt={2} fark={3}' -f `
                $script:PlanUtc, $SaatIst.Text, $SaatLa.Text, $PlanFark.Text)
    }

    Write-Tani ("OZTEST baslangic  : {0}" -f (Get-OztestDurum))
    Invoke-Tik (Get-Ogesi 'BtnArti')
    Write-Tani ("OZTEST +15        : {0}" -f (Get-OztestDurum))
    Invoke-Tik (Get-Ogesi 'BtnEksi')
    Invoke-Tik (Get-Ogesi 'BtnEksi')
    Write-Tani ("OZTEST -30        : {0}" -f (Get-OztestDurum))
    Invoke-Tik (Get-Ogesi 'BtnSimdi')
    Write-Tani ("OZTEST simdi      : {0}" -f (Get-OztestDurum))
})

function Test-PencereEkrandaMi {
    param([double]$Sol, [double]$Ust)
    $vx = [System.Windows.SystemParameters]::VirtualScreenLeft
    $vy = [System.Windows.SystemParameters]::VirtualScreenTop
    $vw = [System.Windows.SystemParameters]::VirtualScreenWidth
    $vh = [System.Windows.SystemParameters]::VirtualScreenHeight

    return ($Sol -ge $vx -and $Sol -lt ($vx + $vw - 50) -and `
            $Ust -ge $vy -and $Ust -lt ($vy + $vh - 50))
}

$win.Add_SourceInitialized({
    if ($null -ne $script:Ayar.sol -and $null -ne $script:Ayar.ust -and `
        (Test-PencereEkrandaMi -Sol ([double]$script:Ayar.sol) -Ust ([double]$script:Ayar.ust))) {
        Set-PencereKonumu -Sol ([double]$script:Ayar.sol) -Ust ([double]$script:Ayar.ust)
    } else {
        Set-VarsayilanKonum
    }
})

$win.Add_ContentRendered({
    Write-Tani ("ContentRendered oncesi: WPF Left={0} Top={1}" -f $win.Left, $win.Top)
    Set-MasaustuSeviyesi
    Write-Tani ("ContentRendered sonrasi: WPF Left={0} Top={1}" -f $win.Left, $win.Top)
    $saatTimer.Start()
})

$win.Add_Closed({
    $saatTimer.Stop()
    # SystemEvents STATİK bir olay: aboneliği bırakmazsak kapanışta hem sızıntı
    # hem de kendi iş parçacığı üzerinden ölü pencereye çağrı riski var.
    if ($null -ne $script:SistemTemaIzleyici) {
        try { [Microsoft.Win32.SystemEvents]::remove_UserPreferenceChanged($script:SistemTemaIzleyici) } catch { }
    }
    try {
        $script:TekOrnek.ReleaseMutex()
        $script:TekOrnek.Dispose()
    } catch { }
})

[void]$win.ShowDialog()
