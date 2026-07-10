# md2docx

Markdownファイルを、Mermaid図を含むWord文書へ変換します。

## ディレクトリ構成

```text
md2docx/
├── input/       # 変換元のMarkdownファイル
├── output/      # 変換後のWordファイル
├── md2docx.sh
├── Dockerfile
└── compose.yaml
```

## 使い方

`input/` にMarkdownファイルを置き、次を実行します。

```sh
docker compose run --rm md2docx sample.md
```

変換結果は `output/sample.docx` に保存されます。

出力ファイル名を指定する場合:

```sh
docker compose run --rm md2docx sample.md report.docx
```
