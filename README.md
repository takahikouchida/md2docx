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

`input/` にMarkdownファイルを置きます。

### ダブルクリックで実行する

- macOS: `run-md2docx.command` をダブルクリック
- Windows: `run-md2docx.bat` をダブルクリック

Docker Desktopを起動した状態で実行してください。必要なDockerイメージをビルドし、`input/` 配下のすべてのMarkdownを変換します。結果は `output/` に保存され、既存出力は通番バックアップへ退避されます。

macOSで初回実行時に権限エラーが表示された場合は、ターミナルで次を一度実行してください。

```sh
chmod +x run-md2docx.command
```

### すべて変換する

ファイル名を省略すると、`input/` 配下のすべてのMarkdownファイルを表示して一括変換します。

```sh
docker compose run --rm md2docx
```

既存の出力ファイルがある場合は上書きせず、実行単位で通番を付けたディレクトリへ退避します。一括変換時のバックアップは同じディレクトリにまとめられます。

```text
output/
├── report.docx
└── backups/
    ├── backup-001/
    │   └── report.docx
    └── backup-002/
        └── report.docx
```

### 1ファイルだけ変換する

```sh
docker compose run --rm md2docx sample.md
```

変換結果は `output/sample.docx` に保存されます。

出力ファイル名を指定する場合:

```sh
docker compose run --rm md2docx sample.md report.docx
```
