#!/bin/sh
set -eu

INPUT="${1:-}"
OUTPUT="${2:-}"
REFERENCE_DOC="${REFERENCE_DOC:-/tools/templates/reference_table_headerbold.docx}"

next_backup_dir() {
  number=1
  while :; do
    candidate="$(printf '/output/backups/backup-%03d' "$number")"
    if [ ! -e "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
    number=$((number + 1))
  done
}

backup_existing_output() {
  if [ ! -f "$OUTPUT_PATH" ]; then
    return
  fi

  backup_path="$BACKUP_DIR/$OUTPUT"
  mkdir -p "$(dirname "$backup_path")"
  mv "$OUTPUT_PATH" "$backup_path"
  echo "Existing output backed up: ${backup_path#/output/}"
}

if [ -z "$INPUT" ]; then
  FILE_COUNT="$(find /input -type f -name '*.md' | wc -l | tr -d ' ')"

  if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No Markdown files found in ./input"
    exit 0
  fi

  echo "Converting all Markdown files:"
  find /input -type f -name '*.md' -print | sed 's#^/input/#  - #'
  echo "Total: $FILE_COUNT file(s)"

  BACKUP_DIR="${BACKUP_DIR:-$(next_backup_dir)}"
  export BACKUP_DIR

  find /input -type f -name '*.md' -exec sh -c '
    for path do
      relative=${path#/input/}
      /usr/local/bin/md2docx.sh "$relative"
    done
  ' sh {} +
  exit 0
fi

if [ -z "$OUTPUT" ]; then
  OUTPUT="${INPUT%.md}.docx"
fi

INPUT_PATH="/input/$INPUT"
OUTPUT_PATH="/output/$OUTPUT"
OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
BACKUP_DIR="${BACKUP_DIR:-$(next_backup_dir)}"

if [ ! -f "$INPUT_PATH" ]; then
  echo "Input file not found: $INPUT_PATH"
  exit 1
fi

if [ ! -f "$REFERENCE_DOC" ]; then
  echo "Reference doc not found: $REFERENCE_DOC"
  exit 1
fi

backup_existing_output
mkdir -p "$OUTPUT_DIR"

TMP_DIR="$(mktemp -d)"
MERMAID_DIR="$TMP_DIR/mermaid"
PROCESSED_MD="$TMP_DIR/input.mermaid-expanded.md"
PUPPETEER_CONFIG="$TMP_DIR/puppeteer-config.json"
mkdir -p "$MERMAID_DIR"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$PUPPETEER_CONFIG" <<'JSON'
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
JSON

python3 - "$INPUT_PATH" "$PROCESSED_MD" "$MERMAID_DIR" "$PUPPETEER_CONFIG" <<'PY'
import os
import re
import subprocess
import sys
from pathlib import Path

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
mermaid_dir = Path(sys.argv[3])
puppeteer_config = Path(sys.argv[4])

text = input_path.read_text(encoding="utf-8")

# Matches fenced Mermaid blocks such as:
# ```mermaid
# graph TD
#   A-->B
# ```
pattern = re.compile(r"(^```mermaid\s*\n)(.*?)(^```\s*$)", re.DOTALL | re.MULTILINE)

counter = 0

def render_mermaid(match: re.Match) -> str:
    global counter
    counter += 1

    source = match.group(2).strip() + "\n"
    mmd_path = mermaid_dir / f"mermaid_{counter:03d}.mmd"
    png_path = mermaid_dir / f"mermaid_{counter:03d}.png"

    mmd_path.write_text(source, encoding="utf-8")

    try:
        subprocess.run(
            [
                "mmdc",
                "-i", str(mmd_path),
                "-o", str(png_path),
                "-b", "transparent",
                "-p", str(puppeteer_config),
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        sys.stderr.write("Mermaid render failed.\n")
        sys.stderr.write(f"Block: {counter}\n")
        sys.stderr.write(e.stderr or e.stdout or "")
        raise

    # Use an absolute path so pandoc can resolve the image from the temp Markdown.
    return f"![]({png_path})\n"

converted = pattern.sub(render_mermaid, text)
output_path.write_text(converted, encoding="utf-8")

print(f"Mermaid blocks rendered: {counter}")
PY

pandoc "$PROCESSED_MD" \
  -o "$OUTPUT_PATH" \
  --reference-doc="$REFERENCE_DOC" \
  --from=markdown+pipe_tables \
  --standalone

python3 /usr/local/bin/format_docx_tables.py "$OUTPUT_PATH"
#  --toc \
#  --toc-depth=2 \
#  --metadata toc-title="目次"
