*[English documentation: README.md](README.md)*

# Masaüstü Saat — Los Angeles + İstanbul

Masaüstünde sürekli duran, şeffaf, dijital çift-saat widget'ı.
Kurulum gerektirmez: Windows PowerShell 5.1 + WPF (Windows'ta zaten var).

```
☀  İSTANBUL       07:06
   12 Ağu Çar
🌙 LOS ANGELES    21:06
   11 Ağu Sal
```

## Dosyalar

| Dosya | Görevi |
|---|---|
| `saat.ps1` | Widget'ın kendisi (WPF penceresi + zaman motoru) |
| `kur-baslangic.ps1` | Kısayolları kurar (Başlangıç + Başlat menüsü, `-Masaustune` ile masaüstü) |
| `kaldir-baslangic.ps1` | Kısayolları kaldırır |

## Kullanım

**Elle başlatmak:** Başlat'a **"Masaustu Saat"** yazın. (Saati sağ tık →
*Kapat* ile kapattıysanız da yolu bu.)

`kur-baslangic.ps1` **iki** kısayol kurar — biri Başlangıç klasöründe açılışta
çalışsın diye, biri Başlat menüsünde elle açmak için; `-Masaustune` ile
üçüncüsü masaüstüne. İkisi de `powershell.exe`'yi doğrudan çağırmak yerine
`conhost.exe` üzerinden gider: varsayılan konsol barındırıcısı Windows Terminal
olduğunda `-WindowStyle Hidden` işe yaramıyor ve arkada boş bir terminal açık
kalıyor.

Saat aynı anda **tek kopya** çalışır; ikinci kez açarsanız sessizce çıkar.
Yoksa iki kopya `ayarlar.json`'a birlikte yazıp konum ve şehir seçimlerini
birbirine karıştırıyordu.

**Açılışta otomatik başlatmak:**

```bash
powershell -ExecutionPolicy Bypass -File kur-baslangic.ps1
```

**Kaldırmak:**

```bash
powershell -ExecutionPolicy Bypass -File kaldir-baslangic.ps1
```

Bu yalnızca `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` altına bir
kısayol koyar — kayıt defterine veya sistem ayarlarına dokunmaz. Kısayol
doğrudan `powershell.exe -WindowStyle Hidden` çağırır; açılışta çok kısa bir
konsol parlaması görülebilir.

> **Neden `.vbs` başlatıcı yok?** Bazı kurumsal uç-nokta koruma yazılımları
> `.vbs` dosyası oluşturmayı engeller (`Permission denied`) — `powershell`'i
> gizli çağıran bir VBS klasik kötü amaçlı yazılım deseni olduğu için makul
> bir kural.
> Konsol parlaması rahatsız ederse alternatif, aynı komutu oturum açma
> tetikleyicili bir Görev Zamanlayıcı görevine taşımaktır.

## Şehir seçimi

Sağ tık → **Şehir seç** → *Üst satır* / *Alt satır* → 25 şehir arasından seçin.
Varsayılan İstanbul + Los Angeles.

Liste UTC ofsetine göre sıralı (batıdan doğuya): Los Angeles, Denver, Chicago,
New York, Toronto, São Paulo, UTC, Londra, Paris, Madrid, Milano, Berlin,
Kahire, İstanbul, Moskova, Doha, Riyad, Dubai, Bakü, Taşkent, Delhi, Singapur,
Şanghay, Tokyo, Sidney. Menüde şehir aramak yerine "kabaca nerede" diye
bakmak daha hızlı olsun diye alfabetik değil coğrafi sırada.

Seçim `%APPDATA%\MasaustuSaat\ayarlar.json` içinde `sehirUst` / `sehirAlt`
olarak saklanır. Her şehirde Windows saat dilimi kimliği + IANA yedeği var;
yaz saati geçişleri her şehir için kendi kurallarıyla işler.

> Planlama modundayken şehir değiştirirseniz plan zamanı "şimdi"ye sıfırlanır —
> çapa saati artık başka bir dilime ait olacağı için anlamı kayardı.

## Planlama modu

Toplantı ayarlarken kullanılır: bir şehirde saati belirlersiniz, diğerinin
karşılığı anında görünür.

**Açmak:** sağ tık → *Planlama modu*

```
🌙 İSTANBUL       13:00   ← çapa (amber)
   20 Ağu Per
☀ LOS ANGELES     03:00
   20 Ağu Per
┌ PLANLAMA                    fark 10 sa
│ [−] [+] [şimdi] [çapa: İST] [✕]
└ tekerlek 15dk · Shift 1sa · Ctrl 1gün
```

| Kontrol | Ne yapar |
|---|---|
| `−` / `+` | 15 dakika geri / ileri |
| Fare tekerleği | 15 dk — **Shift** ile 1 saat, **Ctrl** ile 1 gün |
| `şimdi` | Şu anı alır, sonraki 15 dakikaya yuvarlar |
| `çapa: İST` | Tarafı değiştirir; **an korunur** (İST 13:00 → LA çapasında 03:00) |
| `✕` | Canlı saate döner |

Çapa şehrin saati amber yanar. Her iki şehrin tarihi ayrı gösterildiği için
gün kayması (LA'da bir önceki gün) doğrudan okunur.

> **Mod kalıcı değildir** — her başlangıçta canlı saatten başlar. Açılışta
> donmuş bir saat görüp "widget bozulmuş" sanmayasınız diye böyle.

> Fare tekerleği, Windows'un "üzerine gelince etkin olmayan pencereleri kaydır"
> ayarı kapalıysa çalışmayabilir; `−` / `+` butonları her hâlükârda çalışır.

**Neden klavyeyle saat yazılamıyor?** Widget masaüstü seviyesinde durabilmek
için `WS_EX_NOACTIVATE` ile çalışıyor — yani hiçbir zaman klavye odağı almıyor.
Odak alsaydı tıkladığınızda öne fırlar ve çalışmanızın önünü keserdi. Bu yüzden
tüm kontroller fare tabanlı.

## Etkileşim

- **Sürükle:** sol tuşla tut ve taşı; bırakınca konum kaydedilir.
- **Sağ tık:** arka plan yoğunluğu (yok / hafif / koyu), konumu sıfırla,
  masaüstü seviyesine yeniden yerleştir, kapat.

Ayarlar: `%APPDATA%\MasaustuSaat\ayarlar.json`

## Tasarım kararları

**Zaman dilimi.** Sabit ofset (UTC−8 / UTC+3) **kullanılmıyor**; `TimeZoneInfo`
ile Windows'un tz veritabanı okunuyor. ABD yaz saati uygulaması Mart–Kasım
arasında değişirken Türkiye 2016'dan beri kalıcı UTC+3'te. Sabit ofset yazılsaydı
yılda ~3 hafta boyunca saat yanlış gösterirdi. DST geçişlerinde iki şehir arası
fark 10 ↔ 11 saat arasında kendiliğinden değişir.

**Masaüstü seviyesi.** Klasik yöntem pencereyi `SetParent` ile Progman'ın
(masaüstü penceresi) çocuğu yapmaktır. WPF'te bu iki sorun çıkardı: koordinatlar
ebeveyne göreli hâle gelip çok monitörlü kurulumda pencere ekran dışına kaçtı
(Progman tüm sanal masaüstünü kapsar ve başlangıcı negatif olabilir), ve
`explorer.exe` ile aynı girdi kuyruğuna bağlanmak kilitlenme riski taşıyor.
Bunun yerine pencere normal üst düzey pencere olarak kalıyor ama:

- `WS_EX_NOACTIVATE` → tıklanınca öne gelmez, odağı çalmaz
- `WS_EX_TOOLWINDOW` → Alt+Tab ve görev çubuğunda görünmez
- `HWND_BOTTOM` → 2 saniyede bir z-sırasının dibine gönderilir

Sonuç kullanıcı açısından aynı: masaüstünde durur, hiçbir pencerenin önünü
kesmez. Win+D ile küçültülürse aynı döngü geri getirir.

**Tuzaklar** (aynı hataya düşmemek için):

- `FindWindow('Progman', $null)` çalışmaz — PowerShell `$null`'ı boş string
  olarak marshal eder, arama "başlığı boş Progman"a döner. `GetShellWindow()`
  kullanın.
- `HWND_BOTTOM` = **1**, 8 değil.
- `.ps1` dosyaları UTF-8 **BOM ile** kaydedilmeli; Windows PowerShell 5.1
  BOM'suz UTF-8'i ANSI sanıp Türkçe karakterleri bozar.

## Tanı

Sorun çıkarsa tanı günlüğü açılabilir:

```bash
set SAAT_TANI=1 && powershell -NoProfile -ExecutionPolicy Bypass -STA -File saat.ps1
```

Ek bayraklar: `SAAT_PLAN=1` planlama modu açık başlatır,
`SAAT_OTOTEST=1` buton olay bağlantılarını sınayıp sonucu günlüğe yazar
(dışarıdan fareyle test etmeyin — widget z-sırasının dibinde olduğu için
tıklama üstteki pencereye gider).

Günlük: `%TEMP%\masaustu-saat-tani.log`

## Şekillendirilebilir nokta: `Get-GunDurumu`

`saat.ps1` içindeki bu fonksiyon bir şehrin gündüz mü gece mi olduğuna karar
verip ikonu ve rengini döndürür. Şu an en basit hâli — 07:00–18:59 arası gündüz:

```powershell
function Get-GunDurumu {
    param([datetime]$Yerel)
    if ($Yerel.Hour -ge 7 -and $Yerel.Hour -lt 19) {
        return [pscustomobject]@{ Ikon = $IkonGunes; Renk = '#FFC24B' }
    }
    return [pscustomobject]@{ Ikon = $IkonAy; Renk = '#9FB6D9' }
}
```

Değiştirmeye değer, çünkü asıl soru "güneş doğmuş mu" değil, muhtemelen
**"şu an arasam uygun olur mu"**. Birkaç yön:

- **Üç durum:** mesai içi (yeşil/amber) / uyanık ama mesai dışı (soluk) / gece
  (mavi). Karşı tarafın müsaitliğini tek bakışta verir.
- **Hafta sonu ayrımı:** `$Yerel.DayOfWeek` ile Cumartesi/Pazar'ı mesai dışı say.
- **Sabit saat yerine mevsimsel:** yaz/kış gün uzunluğu farkını yansıtmak
  isterseniz aya göre eşik kaydırın (Ağustos'ta 06:00 aydınlık, Ocak'ta değil).

`$IkonGunes` / `$IkonAy` yerine başka Segoe MDL2 Assets glifleri de
kullanabilirsiniz (ör. `0xE9CA` iş, `0xE7E8` kahve).

## Arayüz dili

Arayüz **Windows görüntü diline göre** otomatik seçilir: Türkçe sistemde Türkçe,
diğerlerinde İngilizce. Ayar yok. Yalnızca `tr` ve `en` var; yeni bir dil
eklemek metin tablosuna bir satır eklemek demek.
