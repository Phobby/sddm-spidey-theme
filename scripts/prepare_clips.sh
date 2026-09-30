#!/usr/bin/env bash
# Spidey SDDM theme — builds the clips from the source video.
# Usage: scripts/prepare_clips.sh [--force-download] [--loop pingpong|xfade]
#                                 [--upscale esrgan|lanczos] [--reuse-frames]
set -euo pipefail

# ---- Settings --------------------------------------------------------------
URL="https://www.youtube.com/watch?v=qvwKAyMapy8"

# Output resolution (the YouTube source tops out at 1080p; anything above is upscaled)
OUT_W=2560
OUT_H=1440
UPSCALE="esrgan"       # esrgan (Real-ESRGAN animevideov3, GPU/Vulkan) | lanczos
ESRGAN_DIR="$HOME/.local/share/realesrgan"
ESRGAN_URL="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip"

# Cut points (seconds, source timeline). Checked against a contact sheet:
#   the jump starts around 5.35, at 10.5 his hands come down from behind
#   his head (phone), after 13.17 there's motion blur + a flip.
IDLE_SS=0.0;   IDLE_T=5.2
JUMP_SS=5.2;   JUMP_T=5.3
PHONE_SS=10.5; PHONE_T=2.6    # phone.mp4: intro (eases to a stop at the end)
PHONE_EASE=0.9                # how many seconds at the end of the intro get the ease-out
LOOP_A=11.5                   # phone_loop.mp4: smooth ping-pong between A..B
LOOP_HALF=3.0                 # half-cycle length of the loop (s) → full cycle is 2×
MASTER_T=13.4                 # source range to upscale: 0..MASTER_T

LOOP_MODE="pingpong"   # idle loop: pingpong | xfade
XFADE_D=1.0
FPS=30
CRF=18
INTERP_FPS=240         # intermediate frame rate used for time remapping
# ---------------------------------------------------------------------------

FORCE_DL=0
REUSE_FRAMES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-download) FORCE_DL=1 ;;
    --loop) LOOP_MODE="$2"; shift ;;
    --upscale) UPSCALE="$2"; shift ;;
    --reuse-frames) REUSE_FRAMES=1 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

cd "$(dirname "$0")/.."
mkdir -p source assets

# The older distro yt-dlp gets 403s from YouTube; prefer a newer one if present.
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

# ---- 1) Master: the relevant part of the source, OUT_W×OUT_H, frame-exact 30 fps
# Frames are retimed to 30 fps (29.97 → 30, 0.1% faster; no duplicated or
# dropped frames). Cut times stay the same as in the source.
FR=source/frames
if [[ $REUSE_FRAMES -eq 0 || ! -f source/master.mp4 ]]; then
  echo ">> Extracting frames (0–${MASTER_T} s)"
  rm -rf "$FR"; mkdir -p "$FR/in" "$FR/up"
  ffmpeg -v error -y -i source/source.mp4 -t "$MASTER_T" -an -fps_mode passthrough "$FR/in/%05d.png"

  if [[ "$UPSCALE" == "esrgan" ]]; then
    if [[ ! -x "$ESRGAN_DIR/realesrgan-ncnn-vulkan" ]]; then
      echo ">> Downloading Real-ESRGAN"
      mkdir -p "$ESRGAN_DIR"
      curl -sSfL -o "$ESRGAN_DIR/r.zip" "$ESRGAN_URL" && (cd "$ESRGAN_DIR" && unzip -oq r.zip && rm r.zip)
      chmod +x "$ESRGAN_DIR/realesrgan-ncnn-vulkan"
    fi
    echo ">> Real-ESRGAN ×2 ($(ls "$FR/in" | wc -l) frames)"
    if ! "$ESRGAN_DIR/realesrgan-ncnn-vulkan" -i "$FR/in" -o "$FR/up" \
         -n realesr-animevideov3 -s 2 -f png -m "$ESRGAN_DIR/models" >/dev/null 2>"$FR/esrgan.log"; then
      echo "!! Real-ESRGAN failed (see $FR/esrgan.log), falling back to lanczos" >&2
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

echo ">> Cutting clips"
cut "$IDLE_SS" "$IDLE_T" assets/idle_raw.mp4
cut "$JUMP_SS" "$JUMP_T" assets/jump.mp4

INTERP="minterpolate=fps=${INTERP_FPS}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:scd=none"
JOBS=$(nproc)

# The source has duplicated frames (e.g. at 12.27 s). ESRGAN amplifies tiny
# differences, so the mpdecimate threshold is high. mpdecimate drops the dupes and
# minterpolate fills the gap with proper motion based on timestamps.
# scd=none: don't mistake fast motion for a scene cut.
# minterpolate is single-threaded and very slow at 1440p, so split the range at
# frame boundaries, process the chunks in parallel, then join them.
# interp <ss> <dur> <out>  → video with interpolated frames at INTERP_FPS
interp() {
  local ss=$1 dur=$2 out=$3 tmp="source/interp.$$"
  local n k i a b cs cd tr
  n=$(awk -v d="$dur" -v f="$FPS" 'BEGIN{printf "%d", d*f + 0.5}')   # number of frame intervals
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
  # No B-frames → no edit list/delay, so frames don't shift at the joins.
  ffmpeg -v error -y -f concat -safe 0 -i "$tmp/list.txt" -c copy "$out"
  local got want
  got=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$out")
  want=$(( n * INTERP_FPS / FPS + 1 ))
  (( got >= want - 1 && got <= want )) || echo "!! warning: $out has $got frames (expected $want)" >&2
  rm -rf "$tmp"
}

# ---- 2) Phone intro: the last PHONE_EASE seconds ease out to a stop --------
# Output time for input time T: linear for T ≤ P−D; after that
# T = (P−D) + D·(1−(1−u)²), t = (P−D) + 2D·u  →  zero speed at the end.
echo ">> Phone intro (ease-out, $JOBS parallel)"
P=$PHONE_T; D=$PHONE_EASE
interp "$PHONE_SS" "$P" source/phone_interp.mp4
ffmpeg -v error -y -i source/phone_interp.mp4 -vf \
  "setpts='if(lte(T,$P-$D),T,($P-$D)+2*$D*(1-sqrt(max(0,1-(T-($P-$D))/$D))))/TB',fps=${FPS}" \
  "${ENC[@]}" assets/phone.mp4
rm -f source/phone_interp.mp4

# ---- 3) Phone loop: cosine-eased ping-pong between A..B --------------------
# E: A→B, t = H·acos(1−2T/S)/π (zero speed at both ends). Loop = reverse(E) + E.
# The loop's first frame B = phone.mp4's last frame → seamless handoff.
echo ">> Phone loop (smooth ping-pong, $JOBS parallel)"
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

# ---- 4) Idle loop ---------------------------------------------------------
echo ">> Idle loop ($LOOP_MODE)"
if [[ "$LOOP_MODE" == "pingpong" ]]; then
  # Forward + reverse; the repeated frames at the turning points are dropped.
  N=$(ffprobe -v error -select_streams v:0 -count_frames \
      -show_entries stream=nb_read_frames -of csv=p=0 assets/idle_raw.mp4)
  ffmpeg -v error -y -i assets/idle_raw.mp4 -filter_complex \
    "[0:v]split[a][b];[b]reverse,trim=start_frame=1:end_frame=$((N-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1:a=0[v]" \
    -map "[v]" "${ENC[@]}" assets/idle.mp4
else
  # Crossfade the end into the start: output = [D..L], last D seconds blend with [0..D].
  L=$(ffprobe -v error -show_entries format=duration -of csv=p=0 assets/idle_raw.mp4)
  OFF=$(awk -v l="$L" -v d="$XFADE_D" 'BEGIN{printf "%.3f", l-2*d}')
  ffmpeg -v error -y -i assets/idle_raw.mp4 -filter_complex \
    "[0:v]split[a][b];[a]trim=start=${XFADE_D},setpts=PTS-STARTPTS[main];\
[b]trim=end=${XFADE_D},setpts=PTS-STARTPTS[head];\
[main][head]xfade=transition=fade:duration=${XFADE_D}:offset=${OFF}[v]" \
    -map "[v]" "${ENC[@]}" assets/idle.mp4
fi

echo ">> Poster frames (so there is no black before a video is ready)"
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
