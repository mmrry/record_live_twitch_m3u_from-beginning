#!/bin/bash

# Usage: ./twitch_download.sh <m3u_URL> <OUTPUT_FILENAME>
# Example twitch_download.sh "https://d3vd9lfkzbru3h.cloudfront.net/.../chunked/index-dvr.m3u8"  "stream_<date>"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <m3u_URL> <OUTPUT_FILENAME>"
    echo "  m3u_URL     — full .m3u8 or end with /chunked"
    echo "  OUTPUT_FILENAME  — file name with date"
    exit 1
fi

RAW_URL="$1"

OUTPUT_FILENAME="${2%.*}"

# Choose format
echo ""
echo "Choose output format file:"
echo "  1) mp4"
echo "  2) ts"
echo ""
read -rp "Chooose [1/2]: " FORMAT_CHOICE

case "$FORMAT_CHOICE" in
    1) EXT="mp4" ;;
    2) EXT="ts"  ;;
    *)
        echo "ERROR: wring choice '$FORMAT_CHOICE'. 1 or 2."
        exit 1
        ;;
esac

OUTPUT="${OUTPUT_FILENAME}.${EXT}"
echo "format: $EXT  →  file will saved as: $OUTPUT"

# Cut /index-dvr.m3u8
m3u_URL="${RAW_URL%/index-dvr.m3u8}"
m3u_URL="${m3u_URL%.m3u8}"
m3u_URL="${m3u_URL%/}"

# Check if URL https://
if [[ "$m3u_URL" != https://* ]]; then
    echo "ERROR: m3u_URL must begin with https://"
    echo "  Got: $m3u_URL"
    exit 1
fi

# URL must end with /chunked
if [[ "$m3u_URL" != */chunked ]]; then
    echo "ERROR: m3u_URL must end with /chunked"
    echo "  Got: $m3u_URL"
    echo ""
    echo "  Formnat URL:"
    echo "    https://<host>/.../chunked/index-dvr.m3u8"
    echo "    https://<host>/.../chunked"
    exit 1
fi

echo "m3u_URL (normalized): $m3u_URL"

# Unique work dir. Name = PID + timestamp
RUN_ID="$$_$(date +%s)"
WORK_DIR="twitch_dl_${RUN_ID}"
TMP_LIST="${WORK_DIR}/ts_list.txt"

mkdir -p "$WORK_DIR"
echo "Working directory : $WORK_DIR"
echo "Output file       : $OUTPUT"
echo ""

# Download segments to tmp work dir
SEG=0
> "$TMP_LIST"

while true; do
    URL="${m3u_URL}/${SEG}.ts"
    DEST="${WORK_DIR}/${SEG}.ts"
    echo "Downloading segment $SEG ..."

    curl -s -f "$URL" -o "$DEST"

    if [ $? -ne 0 ]; then
        echo "Segment $SEG not found — stream ended or no more chunks."
        break
    fi

    echo "file '${SEG}.ts'" >> "$TMP_LIST"
    SEG=$((SEG + 1))
done

TOTAL=$((SEG))
echo ""
echo "Downloaded $TOTAL segments. Merging into '$OUTPUT' ..."

# FFMPEG convert
(cd "$WORK_DIR" && ffmpeg -f concat -safe 0 -i "ts_list.txt" -c copy "../$OUTPUT")

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: ffmpeg failed. Raw segments saved in: $WORK_DIR"
    echo "You can retry manually:"
    echo "  cd $WORK_DIR && ffmpeg -f concat -safe 0 -i ts_list.txt -c copy '../$OUTPUT'"
    exit 1
fi

# Clean work dir
echo "Merge successful. Cleaning up $WORK_DIR ..."
rm -rf "$WORK_DIR"
echo "Done → $OUTPUT"
