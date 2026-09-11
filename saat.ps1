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
Add-Type -Namespace Widget -Name Win32 -MemberDefinition @'
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

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
    ([System.Security.Cryptography.MD5]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($AyarKlasor.ToLowerInvariant())
    ) | ForEach-Object { $_.ToString('x2') }) -join '')
$script:TekOrnek = New-Object System.Threading.Mutex($false, $kilitAdi)
if (-not $script:TekOrnek.WaitOne(0)) { exit 0 }   # zaten açık

$ArkaPlanlar = @{
    yok   = '#00000000'
    hafif = '#59000000'
    koyu  = '#A6000000'
}

function Get-Ayarlar {
    $vars = [ordered]@{ sol = $null; ust = $null; arkaPlan = 'hafif'
                        sehirUst = 'istanbul'; sehirAlt = 'losangeles' }
    if (Test-Path $AyarDosya) {
        try {
            $j = Get-Content $AyarDosya -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @('sol', 'ust', 'arkaPlan', 'sehirUst', 'sehirAlt')) {
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
    try   { return [TimeZoneInfo]::FindSystemTimeZoneById($Windows) }
    catch { return [TimeZoneInfo]::FindSystemTimeZoneById($Iana) }
}

# Şehir kataloğu. Sıra UTC ofsetine göre (batıdan doğuya) — menüde şehir
# aramak yerine "kabaca nerede" diye bakmak daha hızlı.
# Her satır: Ad, Windows saat dilimi kimliği, IANA yedeği.
# Şehir kataloğu. Sıra UTC ofsetine göre (batıdan doğuya) — menüde şehir
# aramak yerine "kabaca nerede" diye bakmak daha hızlı.
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
        MENU_ARKAPLAN = 'Arka plan';   MENU_YOK   = 'Yok (tam şeffaf)'
        MENU_HAFIF    = 'Hafif';       MENU_KOYU  = 'Koyu'
        MENU_SEHIR    = 'Şehir seç';   MENU_UST   = 'Üst satır';  MENU_ALT = 'Alt satır'
        MENU_PLAN     = 'Planlama modu'
        MENU_SIFIRLA  = 'Konumu sıfırla (sağ üst)'
        MENU_KAPAT    = 'Kapat'
        PLAN_BASLIK   = 'PLANLAMA';    PLAN_SIMDI = 'şimdi'
        PLAN_CAPA     = 'çapa: {0}';   PLAN_FARK  = 'fark {0} sa'
        PLAN_IPUCU    = 'tekerlek 15dk · Shift 1sa · Ctrl 1gün'
    }
    en = @{
        MENU_ARKAPLAN = 'Background';  MENU_YOK   = 'None (transparent)'
        MENU_HAFIF    = 'Light';       MENU_KOYU  = 'Dark'
        MENU_SEHIR    = 'Select city'; MENU_UST   = 'Top row';    MENU_ALT = 'Bottom row'
        MENU_PLAN     = 'Planning mode'
        MENU_SIFIRLA  = 'Reset position (top right)'
        MENU_KAPAT    = 'Close'
        PLAN_BASLIK   = 'PLANNING';    PLAN_SIMDI = 'now'
        PLAN_CAPA     = 'anchor: {0}'; PLAN_FARK  = '{0} h apart'
        PLAN_IPUCU    = 'wheel 15min · Shift 1h · Ctrl 1day'
    }
}

function T { param([string]$Anahtar) return $METINLER[$DIL][$Anahtar] }

# Segoe MDL2 Assets ikon kodları (emoji yerine — kodlama sorunu çıkarmaz)
$IkonGunes = [char]0xE706
$IkonAy    = [char]0xE708

# ─── KATKI NOKTASI ───────────────────────────────────────────────────────────
# Bir şehrin o anki saatine bakıp gündüz/gece durumunu döndürür.
# Şu an en basit hâli: 07:00–18:59 arası gündüz, kalanı gece.
# Burayı kendi çalışma düzenine göre şekillendirebilirsin (README'ye bak).
function Get-GunDurumu {
    param([datetime]$Yerel)

    if ($Yerel.Hour -ge 7 -and $Yerel.Hour -lt 19) {
        return [pscustomobject]@{ Ikon = $IkonGunes; Renk = '#FFC24B' }   # gündüz
    }
    return [pscustomobject]@{ Ikon = $IkonAy; Renk = '#9FB6D9' }          # gece
}
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Arayüz
# ─────────────────────────────────────────────────────────────────────────────
$xamlMetin = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Masaustu Saat"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" Topmost="False" ResizeMode="NoResize"
        SizeToContent="WidthAndHeight" WindowStartupLocation="Manual"
        UseLayoutRounding="True" TextOptions.TextRenderingMode="ClearType">

  <Window.ContextMenu>
    <ContextMenu>
      <MenuItem Header="@@MENU_ARKAPLAN@@">
        <MenuItem x:Name="MnuBgYok"   Header="@@MENU_YOK@@" IsCheckable="True"/>
        <MenuItem x:Name="MnuBgHafif" Header="@@MENU_HAFIF@@"            IsCheckable="True"/>
        <MenuItem x:Name="MnuBgKoyu"  Header="@@MENU_KOYU@@"             IsCheckable="True"/>
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
      <MenuItem x:Name="MnuKapat"   Header="@@MENU_KAPAT@@"/>
    </ContextMenu>
  </Window.ContextMenu>

  <Border x:Name="Kapsul" CornerRadius="16" Padding="18,13,20,13" Background="#59000000">
    <StackPanel>
      <StackPanel.Effect>
        <DropShadowEffect BlurRadius="7" ShadowDepth="0" Opacity="0.9" Color="#FF000000"/>
      </StackPanel.Effect>

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

      <Rectangle Height="1" Fill="#26FFFFFF" Margin="0,9,0,9"/>

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

      <!-- planlama seridi -->
      <Border x:Name="PlanSerit" Visibility="Collapsed" Margin="0,12,0,0" CornerRadius="9"
              Background="#1FE8A33D" Padding="9,7,9,8">
        <StackPanel>
          <Grid Margin="0,0,0,7">
            <TextBlock Text="@@PLAN_BASLIK@@" FontFamily="Segoe UI" FontSize="9" FontWeight="SemiBold"
                       Foreground="#E8A33D"/>
            <TextBlock x:Name="PlanFark" HorizontalAlignment="Right" FontFamily="Segoe UI"
                       FontSize="9" Foreground="#E8EDF5" Opacity="0.5"/>
          </Grid>
          <StackPanel Orientation="Horizontal">
            <Border x:Name="BtnEksi" CornerRadius="6" Background="#26FFFFFF" Padding="11,3,11,4" Margin="0,0,5,0">
              <TextBlock Text="−" FontFamily="Segoe UI" FontSize="12" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnArti" CornerRadius="6" Background="#26FFFFFF" Padding="11,3,11,4" Margin="0,0,5,0">
              <TextBlock Text="+" FontFamily="Segoe UI" FontSize="12" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnSimdi" CornerRadius="6" Background="#26FFFFFF" Padding="8,4,8,5" Margin="0,0,5,0">
              <TextBlock Text="@@PLAN_SIMDI@@" FontFamily="Segoe UI" FontSize="10" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnCapa" CornerRadius="6" Background="#26FFFFFF" Padding="8,4,8,5" Margin="0,0,5,0">
              <TextBlock x:Name="CapaMetin" FontFamily="Segoe UI" FontSize="10" Foreground="#F0F4FA"/>
            </Border>
            <Border x:Name="BtnCikis" CornerRadius="6" Background="#26FFFFFF" Padding="9,4,9,5">
              <TextBlock Text="✕" FontFamily="Segoe UI" FontSize="9.5" Foreground="#F0F4FA"/>
            </Border>
          </StackPanel>
          <TextBlock FontFamily="Segoe UI" FontSize="8.5" Opacity="0.45" Foreground="#E8EDF5"
                     Margin="0,7,0,0" Text="@@PLAN_IPUCU@@"/>
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

$Kapsul   = Get-Ogesi 'Kapsul'
$IkonIst  = Get-Ogesi 'IkonIst';  $AdIst = Get-Ogesi 'AdIst'
$TarihIst = Get-Ogesi 'TarihIst'; $SaatIst = Get-Ogesi 'SaatIst'
$IkonLa   = Get-Ogesi 'IkonLa';   $AdLa  = Get-Ogesi 'AdLa'
$TarihLa  = Get-Ogesi 'TarihLa';  $SaatLa  = Get-Ogesi 'SaatLa'
$PlanSerit = Get-Ogesi 'PlanSerit'; $PlanFark = Get-Ogesi 'PlanFark'
$CapaMetin = Get-Ogesi 'CapaMetin'

$script:Ayar = Get-Ayarlar

# Seçili şehirlerin saat dilimleri. Şehir değiştiğinde yeniden çözülür.
$script:TzUst = Get-SehirDilimi -Anahtar $script:Ayar.sehirUst
$script:TzAlt = Get-SehirDilimi -Anahtar $script:Ayar.sehirAlt

function Update-SehirAdlari {
    $AdIst.Text = (Get-SehirAdi (Get-Sehir -Anahtar $script:Ayar.sehirUst)).ToUpper($Kultur)
    $AdLa.Text  = (Get-SehirAdi (Get-Sehir -Anahtar $script:Ayar.sehirAlt)).ToUpper($Kultur)
}

function Set-ArkaPlan {
    param([string]$Ad)
    if (-not $ArkaPlanlar.ContainsKey($Ad)) { $Ad = 'hafif' }
    $script:Ayar.arkaPlan = $Ad
    $Kapsul.Background = [Windows.Media.BrushConverter]::new().ConvertFromString($ArkaPlanlar[$Ad])
    (Get-Ogesi 'MnuBgYok').IsChecked   = ($Ad -eq 'yok')
    (Get-Ogesi 'MnuBgHafif').IsChecked = ($Ad -eq 'hafif')
    (Get-Ogesi 'MnuBgKoyu').IsChecked  = ($Ad -eq 'koyu')
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
$script:PlanCapa  = 'ust'     # 'ust' | 'alt'  (hangi satir capa)
$script:PlanZaman = $null     # çapa saat diliminde, Kind = Unspecified

# İki zaman dilimi arasında SABİT OFSET İLE çevirmek yanlıştır: ABD yaz saati
# Mart–Kasım arasında değişir, Türkiye kalıcı UTC+3'tedir. Bu yüzden çevrim
# hep "yerel → UTC → hedef" olarak, o TARİHE ait kurallarla yapılıyor.
function Convert-Zaman {
    param([datetime]$Yerel, $Kaynak, $Hedef)

    $u = [DateTime]::SpecifyKind($Yerel, [DateTimeKind]::Unspecified)

    # Yaz saatine geçiş gecesinde var olmayan bir saat seçilmiş olabilir
    # (LA'da 02:00–03:00 arası yoktur). Bir saat ileri alıp geçerli kılıyoruz.
    if ($Kaynak.IsInvalidTime($u)) { $u = $u.AddHours(1) }

    $utc = [TimeZoneInfo]::ConvertTimeToUtc($u, $Kaynak)
    return [TimeZoneInfo]::ConvertTimeFromUtc($utc, $Hedef)
}

function Get-CapaDilimi { if ($script:PlanCapa -eq 'ust') { $script:TzUst } else { $script:TzAlt } }

function Get-YuvarlaOnBes {
    param([datetime]$T)
    $t2 = $T.AddSeconds(-$T.Second).AddMilliseconds(-$T.Millisecond)
    return $t2.AddMinutes((15 - ($t2.Minute % 15)) % 15)
}

function Reset-PlanZamani {
    $simdi = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, (Get-CapaDilimi))
    $script:PlanZaman = Get-YuvarlaOnBes -T $simdi
}

function Set-PlanModu {
    param([bool]$Ac)
    $script:PlanModu = $Ac
    if ($Ac -and $null -eq $script:PlanZaman) { Reset-PlanZamani }
    $PlanSerit.Visibility = $(if ($Ac) { 'Visible' } else { 'Collapsed' })
    (Get-Ogesi 'MnuPlan').IsChecked = $Ac
    Update-Saat
}

function Add-PlanDakika {
    param([int]$Dakika)
    if (-not $script:PlanModu -or $null -eq $script:PlanZaman) { return }
    $script:PlanZaman = $script:PlanZaman.AddMinutes($Dakika)
    Update-Saat
}

# Çapa değişince ANI korunur: 13:00 İstanbul çapasından LA çapasına geçince
# 03:00 LA olur — aynı an, farklı referans.
function Switch-Capa {
    if ($null -eq $script:PlanZaman) { Reset-PlanZamani; return }
    if ($script:PlanCapa -eq 'ust') {
        $script:PlanZaman = Convert-Zaman -Yerel $script:PlanZaman -Kaynak $script:TzUst -Hedef $script:TzAlt
        $script:PlanCapa = 'alt'
    } else {
        $script:PlanZaman = Convert-Zaman -Yerel $script:PlanZaman -Kaynak $script:TzAlt -Hedef $script:TzUst
        $script:PlanCapa = 'ust'
    }
    Update-Saat
}

function Update-Saat {
    if ($script:PlanModu -and $null -ne $script:PlanZaman) {
        if ($script:PlanCapa -eq 'ust') {
            $ist = $script:PlanZaman
            $la  = Convert-Zaman -Yerel $ist -Kaynak $script:TzUst -Hedef $script:TzAlt
        } else {
            $la  = $script:PlanZaman
            $ist = Convert-Zaman -Yerel $la -Kaynak $script:TzAlt -Hedef $script:TzUst
        }
    } else {
        $utc = [DateTime]::UtcNow
        $ist = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $script:TzUst)
        $la  = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $script:TzAlt)
    }

    $SaatIst.Text  = $ist.ToString('HH:mm', $Kultur)
    $TarihIst.Text = $ist.ToString('d MMM ddd', $Kultur)
    $SaatLa.Text   = $la.ToString('HH:mm', $Kultur)
    $TarihLa.Text  = $la.ToString('d MMM ddd', $Kultur)

    $dIst = Get-GunDurumu -Yerel $ist
    $IkonIst.Text = $dIst.Ikon
    $IkonIst.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($dIst.Renk)

    $dLa = Get-GunDurumu -Yerel $la
    $IkonLa.Text = $dLa.Ikon
    $IkonLa.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($dLa.Renk)

    # Planlama modunda çapa olan şehrin saati amber yanar; hangi tarafı
    # elle çevirdiğiniz bir bakışta belli olsun.
    $cevirici = [Windows.Media.BrushConverter]::new()
    $normal = $cevirici.ConvertFromString('#F5F8FC')
    $capaRenk = $cevirici.ConvertFromString('#E8A33D')
    if ($script:PlanModu) {
        $SaatIst.Foreground = $(if ($script:PlanCapa -eq 'ust') { $capaRenk } else { $normal })
        $SaatLa.Foreground  = $(if ($script:PlanCapa -eq 'alt') { $capaRenk } else { $normal })
        $capaAnahtar = $(if ($script:PlanCapa -eq 'ust') { $script:Ayar.sehirUst } else { $script:Ayar.sehirAlt })
        $capaAd = Get-SehirAdi (Get-Sehir -Anahtar $capaAnahtar)
        $CapaMetin.Text = ((T 'PLAN_CAPA') -f $capaAd)
        $PlanFark.Text = ((T 'PLAN_FARK') -f [int][Math]::Round(($ist - $la).TotalHours))
    } else {
        $SaatIst.Foreground = $normal
        $SaatLa.Foreground  = $normal
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

# ─────────────────────────────────────────────────────────────────────────────
# Menü olayları
# ─────────────────────────────────────────────────────────────────────────────
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

    # Planlama modundayken şehir değişirse çapa saati artık başka bir dilime
    # ait olur ve anlamı kayar — güvenlisi planı şimdiye almak.
    if ($script:PlanModu) { Reset-PlanZamani }

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
    $Oge.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true })
    $Oge.Add_MouseLeftButtonUp({ param($s, $e) $e.Handled = $true; & $Eylem }.GetNewClosure())
}

Register-Dugme (Get-Ogesi 'BtnEksi')  { Add-PlanDakika -15 }
Register-Dugme (Get-Ogesi 'BtnArti')  { Add-PlanDakika 15 }
Register-Dugme (Get-Ogesi 'BtnSimdi') { Reset-PlanZamani; Update-Saat }
Register-Dugme (Get-Ogesi 'BtnCapa')  { Switch-Capa }
Register-Dugme (Get-Ogesi 'BtnCikis') { Set-PlanModu $false }

function Test-Tus { param([int]$Kod) return (([Widget.Win32]::GetKeyState($Kod) -band 0x8000) -ne 0) }

# Fare tekerleği: 15 dk, Shift ile 1 saat, Ctrl ile 1 gün.
# (Windows'un "üzerine gelince etkin olmayan pencereleri kaydır" ayarı kapalıysa
#  tekerlek gelmeyebilir — o yüzden − / + butonları da var.)
$win.Add_MouseWheel({
    param($s, $e)
    if (-not $script:PlanModu) { return }
    $adim = 15
    if (Test-Tus 0x10) { $adim = 60 }      # Shift
    if (Test-Tus 0x11) { $adim = 1440 }    # Ctrl
    Add-PlanDakika $(if ($e.Delta -gt 0) { $adim } else { -$adim })
    $e.Handled = $true
})
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
    $menuIzleyici.Start()
})
$win.ContextMenu.Add_Closed({ $menuIzleyici.Stop() })

# ─────────────────────────────────────────────────────────────────────────────
# Zamanlayıcılar: saat (1 sn) + masaüstü bağı denetimi (30 sn)
# ─────────────────────────────────────────────────────────────────────────────
$saatTimer = New-Object System.Windows.Threading.DispatcherTimer
$saatTimer.Interval = [TimeSpan]::FromSeconds(1)
$saatTimer.Add_Tick({ Update-Saat })

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
Set-ArkaPlan $script:Ayar.arkaPlan
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

    Write-Tani ("OZTEST baslangic: capa={0} zaman={1}" -f $script:PlanCapa, $script:PlanZaman)
    Invoke-Tik (Get-Ogesi 'BtnArti')
    Write-Tani ("OZTEST +15 sonrasi : {0}" -f $script:PlanZaman)
    Invoke-Tik (Get-Ogesi 'BtnEksi')
    Invoke-Tik (Get-Ogesi 'BtnEksi')
    Write-Tani ("OZTEST -30 sonrasi : {0}" -f $script:PlanZaman)
    Invoke-Tik (Get-Ogesi 'BtnCapa')
    Write-Tani ("OZTEST capa degisti: capa={0} zaman={1}" -f $script:PlanCapa, $script:PlanZaman)
    Invoke-Tik (Get-Ogesi 'BtnSimdi')
    Write-Tani ("OZTEST simdi       : {0}" -f $script:PlanZaman)
})

$win.Add_SourceInitialized({
    if ($null -ne $script:Ayar.sol -and $null -ne $script:Ayar.ust) {
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
})

[void]$win.ShowDialog()
