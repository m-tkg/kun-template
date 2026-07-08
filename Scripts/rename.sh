#!/usr/bin/env bash
# テンプレートのプレースホルダ名を新しいアプリ名へ一括リネームする。
# 使い方: bash Scripts/rename.sh <Name>kun   （例: bash Scripts/rename.sh Fookun）
#
# やること:
#   1. 全テキストファイル中の `Newkun` → `<Name>kun`、`newkun` → 小文字形 を置換
#      （bundle ID com.mtkg.newkun / リポジトリ名 m-tkg/newkun / 表示名などが一括で変わる）
#   2. `Sources/Newkun*` `Tests/Newkun*` のディレクトリ名をリネーム
#
# このスクリプト自身は置換対象から除外している（何度でも同じ引数仕様で使えるようにするため）。
# リネーム後は不要なので削除してよい。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OLD_NAME="Newkun"
OLD_LOWER="newkun"

NEW_NAME="${1:-}"
if [[ -z "$NEW_NAME" ]]; then
  echo "使い方: bash Scripts/rename.sh <Name>kun   （例: bash Scripts/rename.sh Fookun）" >&2
  exit 1
fi
# kuntraykun の集約対象になる条件（bundle ID の末尾が kun）を満たすよう、名前の形式を確認する。
if [[ ! "$NEW_NAME" =~ ^[A-Z][A-Za-z0-9]*kun$ ]]; then
  echo "error: アプリ名は英大文字で始まり 'kun' で終わる必要があります（例: Fookun）: $NEW_NAME" >&2
  exit 1
fi

NEW_LOWER="$(printf '%s' "$NEW_NAME" | tr '[:upper:]' '[:lower:]')"

if [[ "$NEW_NAME" == "$OLD_NAME" ]]; then
  echo "アプリ名が $OLD_NAME のままです。何もしません。"
  exit 0
fi

echo "==> Renaming $OLD_NAME -> $NEW_NAME (bundle ID: com.mtkg.$NEW_LOWER)"

# 1. ファイル内容の置換。プレースホルダを含むテキストファイルだけを対象にする
#    （.git/.build と、このスクリプト自身・バイナリは除外）。
FILES="$(grep -rIl \
  --exclude-dir=.git --exclude-dir=.build --exclude-dir=.swiftpm \
  --exclude=rename.sh \
  -e "$OLD_NAME" -e "$OLD_LOWER" "$ROOT" || true)"
if [[ -n "$FILES" ]]; then
  while IFS= read -r file; do
    LC_ALL=C sed -i '' -e "s/$OLD_NAME/$NEW_NAME/g" -e "s/$OLD_LOWER/$NEW_LOWER/g" "$file"
    echo "    replaced: ${file#"$ROOT"/}"
  done <<< "$FILES"
fi

# 2. ディレクトリのリネーム（Sources/Newkun, Sources/NewkunCore, Tests/NewkunCoreTests）。
for path in "Sources/${OLD_NAME}Core" "Sources/${OLD_NAME}" "Tests/${OLD_NAME}CoreTests"; do
  src="$ROOT/$path"
  dst="$ROOT/${path//$OLD_NAME/$NEW_NAME}"
  if [[ -d "$src" ]]; then
    mv "$src" "$dst"
    echo "    renamed:  $path -> ${path//$OLD_NAME/$NEW_NAME}"
  fi
done

echo "==> Done."
echo ""
echo "次のステップ:"
echo "  1. swift test                              # テストがグリーンになることを確認"
echo "  2. LOCAL=1 bash Scripts/bundle.sh debug    # ローカルビルドで起動確認"
echo "     （署名証明書が無い環境は LOCAL=1 AD_HOC=1 bash Scripts/bundle.sh debug）"
echo "  3. ~/git/github.com/m-tkg/setup-release-secrets.sh -r m-tkg/$NEW_LOWER  # リリース用 Secrets 登録"
echo "  4. CLAUDE.md 末尾の「$NEW_NAME 固有事項」を埋め、Scripts/rename.sh を削除してコミット"
