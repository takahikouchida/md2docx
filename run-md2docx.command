#!/bin/sh

cd "$(dirname "$0")" || exit 1
mkdir -p input output

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker was not found. Start or install Docker Desktop first."
  status=1
else
  echo "Converting Markdown files in input/ ..."
  docker compose run --build --rm md2docx
  status=$?
fi

echo
if [ "$status" -eq 0 ]; then
  echo "Finished. Converted files are in output/."
else
  echo "Conversion failed (exit code: $status)."
fi

printf "Press Enter to close..."
read -r _
exit "$status"
