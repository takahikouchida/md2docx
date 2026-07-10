# md2docx

Markdownファイルを、Mermaid図を含むWord文書へ変換します。

表はページの本文幅に収め、各列の内容量に応じて列幅を自動調整します。

## ディレクトリ構成

```text
md2docx/
├── input/       # 変換元のMarkdownファイル
├── output/      # 変換後のWordファイル
├── scripts/     # 変換・表調整スクリプト
├── templates/   # Wordのスタイルテンプレート
├── Dockerfile
├── compose.yaml
└── .gitignore
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
