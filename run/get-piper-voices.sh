#!/usr/bin/env bash
# Fetch the Piper voices the stick carries into images/piper-voices (git-ignored): model,
# config and model card of each, from a pinned revision of huggingface.co/rhasspy/piper-voices,
# checked against SHA256 sums. Only voices whose licence allows passing them on (the images
# are published): joe (CC0), kristin and cori (public domain, LibriVox recordings).
set -euo pipefail
cd "$(dirname "$0")/.."
REV=c10ece1aade47bb51c153c893d14e5bf8e5b7117
BASE=https://huggingface.co/rhasspy/piper-voices/resolve/$REV
OUT=images/piper-voices
mkdir -p "$OUT"
# path in the repository, voice, sha256 of the .onnx, sha256 of the .onnx.json
VOICES="
en/en_US/joe/medium      en_US-joe-medium      58afce0321b8d9c46d7cdf9c16500cc55a793b4220212dba6b70fb788b3baf06 3d6d5410b3795cb1950595247ef8f06190719e6fdbfa3a2356d8ec368e1aad33
en/en_US/kristin/medium  en_US-kristin-medium  5849957f929cbf720c258f8458692d6103fff2f0e3d3b19c8259474bb06a18d4 5681426d4aead22195de70531eeeeddb46493cfaffc5764b2ea3db73428b651c
en/en_GB/cori/medium     en_GB-cori-medium     1899f98e5fb8310154f3c2973f4b8a929ba7245e722b3d3a85680b833d95f10d e262c16d7f192f69d4edd6b4ef8a5915379e67495fcc402f1ab15eeb33da3d36
"
fetch() {   # url file sha256
    if [ -f "$2" ] && echo "$3  $2" | sha256sum -c --status; then return; fi
    curl -sfL -o "$2.part" "$1" && echo "$3  $2.part" | sha256sum -c --status || { echo "bad download: $1"; rm -f "$2.part"; exit 1; }
    mv "$2.part" "$2"
}
echo "$VOICES" | while read -r path name sum_model sum_json; do
    [ -n "$path" ] || continue
    fetch "$BASE/$path/$name.onnx" "$OUT/$name.onnx" "$sum_model"
    fetch "$BASE/$path/$name.onnx.json" "$OUT/$name.onnx.json" "$sum_json"
    [ -f "$OUT/$name.MODEL_CARD.txt" ] || curl -sfL -o "$OUT/$name.MODEL_CARD.txt" "$BASE/$path/MODEL_CARD"
done
echo "Piper voices in $OUT: $(ls "$OUT"/*.onnx | wc -l), $(du -sh "$OUT" | cut -f1)"
