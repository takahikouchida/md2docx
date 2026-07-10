#!/bin/sh
set -eu

INPUT="${1:-}"
OUTPUT="${2:-}"
REFERENCE_DOC="${REFERENCE_DOC:-/tools/reference_table_headerbold.docx}"

if [ -z "$INPUT" ]; then
  echo "Usage: docker compose run --rm md2docx input.md [output.docx]"
  echo "  Source: ./input/input.md"
  echo "  Output: ./output/output.docx"
  exit 1
fi

if [ -z "$OUTPUT" ]; then
  OUTPUT="${INPUT%.md}.docx"
fi

INPUT_PATH="/input/$INPUT"
OUTPUT_PATH="/output/$OUTPUT"
OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"

if [ ! -f "$INPUT_PATH" ]; then
  echo "Input file not found: $INPUT_PATH"
  exit 1
fi

if [ ! -f "$REFERENCE_DOC" ]; then
  echo "Reference doc not found: $REFERENCE_DOC"
  exit 1
fi

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
#  --toc \
#  --toc-depth=2 \
#  --metadata toc-title="目次"
