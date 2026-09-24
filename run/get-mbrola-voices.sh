#!/usr/bin/env bash
# Fetch the English MBROLA voices (us1 female, us2 and us3 male, en1 British male) into
# images/mbrola-voices/<voice>/ (git-ignored), with their README and licence files and the
# collection's LICENSE.md, from a pinned commit of github.com/numediart/MBROLA-voices, checked
# against SHA256 sums. Their terms allow copying and distribution free of charge with the
# notice (LICENSE.md), so the stick carries it next to them.
set -euo pipefail
cd "$(dirname "$0")/.."
REV=fe05a0ccef6a941207fd6aaad0b31294a1f93a51
BASE=https://raw.githubusercontent.com/numediart/MBROLA-voices/$REV
OUT=images/mbrola-voices
mkdir -p "$OUT"
VOICES="
us1 9f1cd90de6334f43cb4f7348cacd0806fb414b0fbc762492bde7000b9e192a9a
us2 75f7f6b605945f4b65713c3ad1fba5be38fb720cde01bdc3d2facf988634c0d5
us3 7cc5c49e098f80091e34ed0bd50f0af3908ac2427fbbe7d2b16c57defb7611ec
en1 edb8eaae6f0e38493d88ed627518632e6ff8a3843bcf08474a1a70aa786fd99f
"
echo "$VOICES" | while read -r v sum; do
    [ -n "$v" ] || continue
    mkdir -p "$OUT/$v"
    f="$OUT/$v/$v"
    if ! { [ -f "$f" ] && echo "$sum  $f" | sha256sum -c --status; }; then
        curl -sfL -o "$f.part" "$BASE/data/$v/$v" && echo "$sum  $f.part" | sha256sum -c --status || { echo "bad download: $v"; rm -f "$f.part"; exit 1; }
        mv "$f.part" "$f"
    fi
    [ -f "$OUT/$v/README.txt" ] || curl -sfL -o "$OUT/$v/README.txt" "$BASE/data/$v/README.txt" || echo "warning: no README.txt for $v"
    # (not every voice has a separate licence file upstream)
    [ -f "$OUT/$v/license.txt" ] || curl -sfL -o "$OUT/$v/license.txt" "$BASE/data/$v/license.txt" || true
done
[ -f "$OUT/LICENSE.md" ] || curl -sfL -o "$OUT/LICENSE.md" "$BASE/LICENSE.md"
echo "MBROLA voices in $OUT: $(ls -d "$OUT"/*/ | wc -l), $(du -sh "$OUT" | cut -f1)"
