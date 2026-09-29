#!/usr/bin/env bash
# Spidey SDDM teması — kaynak videodan klipleri hazırlar.
# Kullanım: scripts/prepare_clips.sh [--force-download] [--loop pingpong|xfade]
#                                    [--upscale esrgan|lanczos] [--reuse-frames]
set -euo pipefail

# ---- Ayarlar ---------------------------------------------------------------
URL="https://www.youtube.com/watch?v=qvwKAyMapy8"

# Çıkış çözünürlüğü (YouTube kaynağı en fazla 1080p; üstü yükseltme ile)
OUT_W=2560
OUT_H=1440
UPSCALE="esrgan"       # esrgan (Real-ESRGAN animevideov3, GPU/Vulkan) | lanczos
ESRGAN_DIR="$HOME/.local/share/realesrgan"
ESRGAN_URL="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip"

# Kesim noktaları (saniye, kaynak zaman çizelgesi). Contact sheet ile doğrulandı:
#   5.35 civarında zıplama başlıyor, 10.5'te eller başın arkasından
#   iniyor (telefon), 13.17'den sonra motion blur + takla başlıyor.
IDLE_SS=0.0;   IDLE_T=5.2
JUMP_SS=5.2;   JUMP_T=5.3
PHONE_SS=10.5; PHONE_T=2.6    # phone.mp4: giriş (sonu yavaşlayarak durur)
PHONE_EASE=0.9                # girişin son kaç saniyesi ease-out ile yavaşlasın
LOOP_A=11.5                   # phone_loop.mp4: A..B arası yumuşak ping-pong
LOOP_HALF=3.0                 # döngünün yarım tur süresi (sn) → tam tur 2×
MASTER_T=13.4                 # yükseltilecek kaynak aralığı: 0..MASTER_T

LOOP_MODE="pingpong"   # idle döngüsü: pingpong | xfade
XFADE_D=1.0
FPS=30
CRF=18
INTERP_FPS=240         # zaman yeniden eşleme için ara kare hızı
# ---------------------------------------------------------------------------

FORCE_DL=0
REUSE_FRAMES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-download) FORCE_DL=1 ;;
    --loop) LOOP_MODE="$2"; shift ;;
    --upscale) UPSCALE="$2"; shift ;;
    --reuse-frames) REUSE_FRAMES=1 ;;
    *) echo "Bilinmeyen argüman: $1" >&2; exit 1 ;;
  esac
  shift
done

cd "$(dirname "$0")/.."
mkdir -p source assets

# Dağıtım paketindeki eski yt-dlp YouTube'da 403 veriyor; varsa güncelini kullan.
YTDLP="$(command -v "$HOME/.local/bin/yt-dlp" || command -v yt-dlp)"
JS_RT=()
command -v deno >/dev/null || { command -v node >/dev/null && JS_RT=(--js-runtimes node); }

if [[ ! -f source/source.mp4 || $FORCE_DL -eq 1 ]]; then
  rm -f source/source.*
  "$YTDLP" "${JS_RT[@]}" --no-playlist \
    -f "bv*[height<=1080]+ba/b[height<=1080]" \
    --merge-output-format mp4 -o "source/source.mp4" "$URL"
fi

ENC=(-c:v libx264 -crf "$CRF" -preset slow -pix_fmt yuv420p -g "$FPS" -movflags +faststart -an)
FIT="scale=${OUT_W}:${OUT_H}:force_original_aspect_ratio=increase:flags=lanczos,crop=${OUT_W}:${OUT_H}"

# ---- 1) Master: kaynağın ilgili kısmı, OUT_W×OUT_H, kare kare 30 fps -------
# Kareler 30 fps olarak yeniden zamanlanır (29.97 → 30, %0.1 hızlanma; kare
# tekrarı/atlaması olmaz). Kesim zamanları kaynakla aynı kalır.
FR=source/frames
if [[ $REUSE_FRAMES -eq 0 || ! -f source/master.mp4 ]]; then
  echo ">> Kareler çıkarılıyor (0–${MASTER_T} sn)"
  rm -rf "$FR"; mkdir -p "$FR/in" "$FR/up"
  ffmpeg -v error -y -i source/source.mp4 -t "$MASTER_T" -an -fps_mode passthrough "$FR/in/%05d.png"

  if [[ "$UPSCALE" == "esrgan" ]]; then
    if [[ ! -x "$ESRGAN_DIR/realesrgan-ncnn-vulkan" ]]; then
      echo ">> Real-ESRGAN indiriliyor"
      mkdir -p "$ESRGAN_DIR"
      curl -sSfL -o "$ESRGAN_DIR/r.zip" "$ESRGAN_URL" && (cd "$ESRGAN_DIR" && unzip -oq r.zip && rm r.zip)
      chmod +x "$ESRGAN_DIR/realesrgan-ncnn-vulkan"
    fi
    echo ">> Real-ESRGAN ×2 ($(ls "$FR/in" | wc -l) kare)"
    if ! "$ESRGAN_DIR/realesrgan-ncnn-vulkan" -i "$FR/in" -o "$FR/up" \
         -n realesr-animevideov3 -s 2 -f png -m "$ESRGAN_DIR/models" >/dev/null 2>"$FR/esrgan.log"; then
      echo "!! Real-ESRGAN başarısız (bkz. $FR/esrgan.log), lanczos kullanılıyor" >&2
      UPSCALE=lanczos
    fi
  fi
  SRC_DIR="$FR/in"; [[ "$UPSCALE" == "esrgan" ]] && SRC_DIR="$FR/up"

  echo ">> Master (${OUT_W}x${OUT_H}, $UPSCALE)"
  ffmpeg -v error -y -framerate "$FPS" -i "$SRC_DIR/%05d.png" -vf "$FIT" \
    -c:v libx264 -crf 10 -preset medium -pix_fmt yuv420p -g "$FPS" source/master.mp4
  rm -rf "$FR"
fi

cut() { # cut <ss> <t> <out>
  ffmpeg -v error -y -i source/master.mp4 -ss "$1" -t "$2" "${ENC[@]}" "$3"
}

echo ">> Kesitler"
cut "$IDLE_SS" "$IDLE_T" assets/idle_raw.mp4
cut "$JUMP_SS" "$JUMP_T" assets/jump.mp4

# ---- 2) Phone girişi: son PHONE_EASE saniye ease-out ile durur -------------
# Girdi zamanı T için çıktı zamanı: T ≤ P−D doğrusal; sonrasında
# T = (P−D) + D·(1−(1−u)²), t = (P−D) + 2D·u  →  bitişte hız 0.
INTERP="minterpolate=fps=${INTERP_FPS}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:scd=none"
JOBS=$(nproc)

# Kaynakta tekrarlanan kareler var (ör. 12.27 sn). ESRGAN küçük farkları büyüttüğü
# için mpdecimate eşiği yüksek. scd=none: hızlı hareketi sahne kesmesi sanmasın.
# mpdecimate tekrarları atar,
# minterpolate zaman damgalarına göre boşluğu düzgün hareketle doldurur.
# minterpolate tek çekirdekte çalışır ve 1440p'de çok yavaştır: aralığı kare
# sınırlarından parçalara bölüp paralel işle, sonra birleştir.
# interp <ss> <dur> <out>  → INTERP_FPS hızında ara kareli video
interp() {
  local ss=$1 dur=$2 out=$3 tmp="source/interp.$$"
  local n k i a b cs cd tr
  n=$(awk -v d="$dur" -v f="$FPS" 'BEGIN{printf "%d", d*f + 0.5}')   # kare aralığı sayısı
  k=$(( (n + JOBS - 1) / JOBS ))
  rm -rf "$tmp"; mkdir -p "$tmp"
  for (( i = 0; i * k < n; i++ )); do
    a=$(( i * k )); b=$(( a + k < n ? a + k : n ))
    cs=$(awk -v s="$ss" -v a="$a" -v f="$FPS" 'BEGIN{printf "%.6f", s + a/f}')
    cd=$(awk -v a="$a" -v b="$b" -v f="$FPS" 'BEGIN{printf "%.6f", (b-a+0.5)/f}')
    tr=$(awk -v a="$a" -v b="$b" -v f="$FPS" 'BEGIN{printf "%.6f", (b-a)/f}')
    ffmpeg -v error -y -ss "$cs" -i source/master.mp4 -t "$cd" -an -vf \
      "mpdecimate=hi=64*48:lo=64*24:frac=0.5,${INTERP},trim=end=${tr},setpts=PTS-STARTPTS" \
      -c:v libx264 -crf 8 -preset veryfast -bf 0 -pix_fmt yuv420p "$tmp/$(printf %03d "$i").mp4" &
  done
  wait
  for f in "$tmp"/*.mp4; do echo "file '$(realpath "$f")'"; done > "$tmp/list.txt"
  # B-kare yok → edit list/gecikme yok; birleşimde kare kayması olmaz.
  ffmpeg -v error -y -f concat -safe 0 -i "$tmp/list.txt" -c copy "$out"
  local got want
  got=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$out")
  want=$(( n * INTERP_FPS / FPS + 1 ))
  (( got >= want - 1 && got <= want )) || echo "!! uyarı: $out kare sayısı $got (beklenen $want)" >&2
  rm -rf "$tmp"
}

# ---- 2) Phone girişi: son PHONE_EASE saniye ease-out ile durur -------------
# Girdi zamanı T için çıktı zamanı: T ≤ P−D doğrusal; sonrasında
# T = (P−D) + D·(1−(1−u)²), t = (P−D) + 2D·u  →  bitişte hız 0.
echo ">> Phone girişi (ease-out, $JOBS paralel)"
P=$PHONE_T; D=$PHONE_EASE
interp "$PHONE_SS" "$P" source/phone_interp.mp4
ffmpeg -v error -y -i source/phone_interp.mp4 -vf \
  "setpts='if(lte(T,$P-$D),T,($P-$D)+2*$D*(1-sqrt(max(0,1-(T-($P-$D))/$D))))/TB',fps=${FPS}" \
  "${ENC[@]}" assets/phone.mp4
rm -f source/phone_interp.mp4

# ---- 3) Phone döngüsü: A..B kosinüs yumuşatmalı ping-pong ------------------
# E: A→B, t = H·acos(1−2T/S)/π (iki uçta hız 0). Döngü = ters(E) + E.
# Döngünün ilk karesi B = phone.mp4'ün son karesi → geçiş kesintisiz.
echo ">> Phone döngüsü (yumuşak ping-pong, $JOBS paralel)"
B=$(awk -v a="$PHONE_SS" -v t="$PHONE_T" 'BEGIN{printf "%.3f", a+t}')
S=$(awk -v a="$LOOP_A" -v b="$B" 'BEGIN{printf "%.3f", b-a}')
interp "$LOOP_A" "$S" source/loop_interp.mp4
ffmpeg -v error -y -i source/loop_interp.mp4 -vf \
  "setpts='${LOOP_HALF}*acos(max(-1,min(1,1-2*T/$S)))/PI/TB',fps=${FPS}" \
  -c:v libx264 -crf 10 -preset medium -pix_fmt yuv420p -an source/phone_ease.mp4
NE=$(ffprobe -v error -select_streams v:0 -count_frames \
     -show_entries stream=nb_read_frames -of csv=p=0 source/phone_ease.mp4)
ffmpeg -v error -y -i source/phone_ease.mp4 -filter_complex \
  "[0:v]split[a][b];[a]reverse,setpts=PTS-STARTPTS[r];\
[b]trim=start_frame=1:end_frame=$((NE-1)),setpts=PTS-STARTPTS[f];\
[r][f]concat=n=2:v=1:a=0[v]" \
  -map "[v]" "${ENC[@]}" assets/phone_loop.mp4
rm -f source/phone_ease.mp4 source/loop_interp.mp4

# ---- 4) Idle döngüsü -------------------------------------------------------
echo ">> Idle döngüsü ($LOOP_MODE)"
if [[ "$LOOP_MODE" == "pingpong" ]]; then
  # İleri + ters; dönüş noktalarında tekrar eden kareler atılır.
  N=$(ffprobe -v error -select_streams v:0 -count_frames \
      -show_entries stream=nb_read_frames -of csv=p=0 assets/idle_raw.mp4)
  ffmpeg -v error -y -i assets/idle_raw.mp4 -filter_complex \
    "[0:v]split[a][b];[b]reverse,trim=start_frame=1:end_frame=$((N-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1:a=0[v]" \
    -map "[v]" "${ENC[@]}" assets/idle.mp4
else
  # Sonu başa crossfade: çıktı = [D..L] ve son D saniye [0..D] ile karışır.
  L=$(ffprobe -v error -show_entries format=duration -of csv=p=0 assets/idle_raw.mp4)
  OFF=$(awk -v l="$L" -v d="$XFADE_D" 'BEGIN{printf "%.3f", l-2*d}')
  ffmpeg -v error -y -i assets/idle_raw.mp4 -filter_complex \
    "[0:v]split[a][b];[a]trim=start=${XFADE_D},setpts=PTS-STARTPTS[main];\
[b]trim=end=${XFADE_D},setpts=PTS-STARTPTS[head];\
[main][head]xfade=transition=fade:duration=${XFADE_D}:offset=${OFF}[v]" \
    -map "[v]" "${ENC[@]}" assets/idle.mp4
fi

echo ">> Poster kareler (video hazır olana kadar siyah görünmesin)"
first() { ffmpeg -v error -y -i "$1" -frames:v 1 -q:v 2 "$2"; }
last()  { ffmpeg -v error -y -sseof -0.1 -i "$1" -update 1 -q:v 2 "$2"; }
first assets/idle.mp4       assets/idle_first.jpg
first assets/jump.mp4       assets/jump_first.jpg
last  assets/jump.mp4       assets/jump_last.jpg
first assets/phone.mp4      assets/phone_first.jpg
first assets/phone_loop.mp4 assets/phone_loop_first.jpg
rm -f assets/phone_last.jpg

chmod 644 assets/*.mp4 assets/*.jpg
for f in assets/idle.mp4 assets/jump.mp4 assets/phone.mp4 assets/phone_loop.mp4; do
  printf "%-22s %s\n" "$f" "$(ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=width,height,nb_read_frames:format=duration,size \
    -of compact=p=0:nk=1 "$f" | tr '\n' ' ')"
done
