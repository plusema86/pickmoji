#!/usr/bin/env bash
# Downloads the pinned Italian and English emojibase-data datasets and
# merges them into Pickmoji/Resources/emoji.json. Run from anywhere.
set -euo pipefail

EMOJIBASE_VERSION="${EMOJIBASE_VERSION:-17.0.0}"
BASE_URL="https://cdn.jsdelivr.net/npm/emojibase-data@${EMOJIBASE_VERSION}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/Pickmoji/Resources/emoji.json"
SYNONYMS="$REPO_ROOT/scripts/emoji-synonyms-it.json"

command -v jq >/dev/null || { echo "jq is required (brew install jq)" >&2; exit 1; }

temp_dir="$(mktemp -d "$REPO_ROOT/Pickmoji/Resources/.emoji-data.XXXXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

echo "Downloading Italian and English emojibase-data@${EMOJIBASE_VERSION} ..."
curl -fsSL "$BASE_URL/it/data.json" -o "$temp_dir/it.json"
curl -fsSL "$BASE_URL/en/data.json" -o "$temp_dir/en.json"

# Drop: entries without a group (regional indicators) and group 2 (components:
# skin-tone modifiers and hair pieces, which are not pickable on their own).
# Mixed-tone skins (tone is an array) are dropped; the tone picker offers the
# five uniform tones only.
jq -c --slurpfile italian "$temp_dir/it.json" --slurpfile synonyms "$SYNONYMS" '
  INDEX($italian[0][]; .hexcode) as $italianByHexcode
  | $synonyms[0] as $aliases
  | map(select(.group != null and .group != 2)) as $catalog
  | (($aliases | keys) - ($catalog | map(.hexcode))) as $unknownAliases
  | if ($unknownAliases | length) > 0 then
      error("Unknown emoji hexcodes in Italian synonyms: \($unknownAliases | join(", "))")
    else $catalog end
  | map(
    $italianByHexcode[.hexcode] as $translation
    | if ($translation.label // "") == "" then
        error("Missing Italian label for \(.hexcode)")
      else {
        emoji,
        label: $translation.label,
        tags: ((($translation.tags // []) + ($aliases[.hexcode] // [])) | unique),
        englishLabel: .label,
        englishTags: (.tags // []),
        group,
        order,
        skins: ([ .skins[]? | select(.tone | type == "number") | { emoji, tone } ])
      } end
  )
  | sort_by(.order)
' "$temp_dir/en.json" > "$temp_dir/emoji.json"
mv "$temp_dir/emoji.json" "$OUT"

count="$(jq 'length' "$OUT")"
skins="$(jq '[.[].skins | length] | add' "$OUT")"
size="$(du -h "$OUT" | cut -f1)"
echo "Wrote $OUT"
echo "  $count emoji, $skins skin variants, $size"
echo "Update the version in Pickmoji/Resources/DATA_SOURCE.md if you changed EMOJIBASE_VERSION."
