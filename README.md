# kun-template

kun シリーズ（macOS メニューバー常駐アプリ群）の新規開発用テンプレート。
プレースホルダのアプリ名は **Newkun**（bundle ID `com.mtkg.newkun`）で、そのままビルド・起動できる。

**このリポジトリは共通ガイド [`CLAUDE_base.md`](./CLAUDE_base.md) の canonical（唯一の一次ソース）も兼ねる**。
kun シリーズ共通の方針（Swift Package 構成・ローカライズ・アップデート・kunkit 連携・リリース・ブランチ運用）は
`CLAUDE_base.md` にまとまっており、規約を変えるときはここを編集する。各アプリの `CLAUDE.md` は固有事項のみを持ち、
共通方針は本ファイルを参照する（既存アプリは、本リポジトリを兄弟ディレクトリに clone した上で `../kun-template/CLAUDE_base.md` を参照する）。

## 使い方

```sh
# 1. テンプレートから新規リポジトリを作成して clone する
gh repo create m-tkg/<name>kun --template m-tkg/kun-template --public --clone
cd <name>kun

# 2. プレースホルダ名を一括リネームする（Newkun → <Name>kun / newkun → <name>kun）
bash Scripts/rename.sh <Name>kun    # 例: bash Scripts/rename.sh Fookun

# 3. ビルド・テスト・ローカル起動確認
swift test
LOCAL=1 bash Scripts/bundle.sh debug          # 署名証明書が無い環境は LOCAL=1 AD_HOC=1 ...
open "<Name>kun (Local).app"

# 4. リリース用 Secrets（署名＋公証の計6つ）を登録する
~/git/github.com/m-tkg/setup-release-secrets.sh -r m-tkg/<name>kun
```

リネーム後は `CLAUDE.md` 末尾の「固有事項」節を埋め、`Scripts/rename.sh` を削除してよい。
固有機能は `<Name>kunCore` に TDD で実装し、設定タブ・メニュー項目・en/ja 対訳を足していく
（`CLAUDE.md` の「開発の進め方」参照）。

## 含まれる機能

- **メニューバー常駐**（`LSUIElement` / `.accessory` 起動・多重起動防止・Dock アイコンなし）
- **2 ターゲット構成**（`NewkunCore` 純粋ロジック＋テスト / `Newkun` 実行ファイル）
- **日英ローカライズ**（`L.string` / `Resources/{en,ja}.lproj` / `CFBundleLocalizations`）
- **自己アップデート**（kunkit `KunUpdateKit` の ETag 付き取得・1時間ごと＋スリープ復帰時のサイレントチェック・
  メニューバーアイコンの赤バッジ・zip DL → 入替 → 再起動）
- **kuntraykun 連携**（kunkit `KunIntegrationBridge`。アイコン集約 v1〜v4 対応済み）
- **自動起動**（`SMAppService` のログイン項目トグル。設定「一般」タブ）
- **設定ダイアログ**（SwiftUI + NSWindow・タブ構成・JSON 永続化・表示中は Dock アイコン表示）
- **ローカルビルド分離**（`LOCAL=1 bash Scripts/bundle.sh` で bundle ID `.local`・「ローカル」併記）
- **リリース CI**（`v*` タグ起点。署名・公証、Secrets 未設定時は ad-hoc / 公証スキップにフォールバック）
- **`make release-tag`**（安全チェック付きのタグ作成・push）

## アイコン

- `Resources/MenuBarIcon.png` を置くとメニューバーのテンプレート画像として使われる
  （無い間は SF Symbol で代用）。
- `Resources/AppIcon.png` を置くと `bundle.sh` が `.icns` を生成して同梱する。
