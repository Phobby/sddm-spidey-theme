# Spidey — SDDM teması (Plasma 6 / Qt6)

Miles Morales'in şehri izleyip aşağı atladığı ve havada telefonunu çıkardığı
animasyonlu bir giriş ekranı.

- **Idle:** Döngüde oynayan şehir sahnesi. Sağda cam efektli panelde kullanıcı,
  oturum ve güç butonları yer alır.
- **Jump:** Ekrana tıklayınca ya da Enter/boşluk tuşuna basınca Spider-Man atlar.
  Harfe basınca atlama beklenmeden doğrudan şifre ekranına geçilir.
- **Phone:** Telefonunu çıkarır, yumuşak ve kesintisiz bir döngüde telefona bakar.
  Şifre kutusu bu sırada açılır. Esc ile başa dönülür.

Klipler 2560×1440 çözünürlükte, Real-ESRGAN ile büyütüldü, H.264, sessiz.

## Kurulum

```bash
git clone <repo-url> ~/sddm-themes/spidey
sudo rsync -a --delete --exclude source/ --exclude .git/ ~/sddm-themes/spidey/ /usr/share/sddm/themes/spidey/
sudo chown -R root:root /usr/share/sddm/themes/spidey
```

`/etc/sddm.conf.d/` içindeki tema dosyasında:

```ini
[Theme]
Current=spidey
```

Kurmadan önce test etmek için:

```bash
sddm-greeter-qt6 --test-mode --theme ~/sddm-themes/spidey
```

> Not: Ev dizinine sembolik link verirsen `sddm` kullanıcısı genellikle ev dizinine
> erişemediği için tema gerçek giriş ekranında açılmaz. Bu yüzden dosyaları kopyala.

Gereksinimler: SDDM 0.21+ (Qt6), `qml6-module-qtmultimedia` (FFmpeg backend),
`qml6-module-qtquick-effects`.

## Ayarlar (`theme.conf`)

| Anahtar | Açıklama |
|---|---|
| `font` | Font ailesi (boş = gömülü Rajdhani) |
| `accentColor` | Vurgu rengi |
| `panelWidth` | Panel genişliği (1080p referansında px) |
| `panelSide` | `right` / `left` |
| `blur` | Cam bulanıklığı, 0.0–1.0 |
| `powerButtons` | `panel` / `bottom-right` / `bottom-left` / `top-right` / `hidden` |
| `showClock`, `clockFormat`, `dateFormat`, `locale` | Sol üstteki saat ve tarih |

## Klipleri yeniden üretmek

```bash
scripts/prepare_clips.sh              # indir, büyüt, kes, döngüleri üret
scripts/prepare_clips.sh --reuse-frames   # büyütülmüş master'ı yeniden kullan
scripts/prepare_clips.sh --upscale lanczos  # GPU yoksa
```

Kesim noktaları ve döngü parametreleri script'in başındadır. Gerekenler:
`yt-dlp`, `ffmpeg`, ve isteğe bağlı olarak Vulkan destekli bir GPU (Real-ESRGAN).

## Lisans / telif

Kod ve script serbestçe kullanılabilir. Video karelerinin telifi
Marvel's Spider-Man: Miles Morales (Sony Interactive Entertainment / Insomniac Games)
sahiplerine aittir, kişisel kullanım içindir. Font: Rajdhani (SIL OFL,
`assets/fonts/OFL.txt`).
