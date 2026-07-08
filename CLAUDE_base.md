# CLAUDE_base.md — メニューバー常駐アプリ（kun シリーズ）作成の共通ガイド

kun シリーズ（clipkun / gitkun / keykun / pointerkun / snapperkun / whisperkun / kuntraykun）の
知見をまとめた、macOS タスクトレイ（メニューバー常駐）アプリの共通方針。

> **このファイルが共通ガイドの canonical（唯一の一次ソース）**。[kun-template](https://github.com/m-tkg/kun-template)
> リポジトリで版管理される。共通方針を変えるときはここを編集する。各 kun アプリの `CLAUDE.md` は
> 固有事項のみを記し、共通方針は本ファイルを参照する（新規アプリはテンプレートに同梱の本ファイルを引き継ぐ。
> 既存アプリは兄弟ディレクトリの `../CLAUDE_base.md`＝本ファイルへの symlink を参照する）。

## 基本構成

- **Swift Package Manager** の 2 ターゲット構成。**純粋ロジックとプラットフォーム依存を分離**する。
  - `<Name>Core`（ライブラリ / テスト対象）: AppKit/Carbon/AX/CGEventTap に依存しないロジックとモデル。
    判定ロジックは時刻などを注入する純粋関数/状態機械にして **TDD（テスト先行）** で実装する。
  - `<Name>`（実行ファイル）: AppKit/SwiftUI/各種 OS 連携と UI。
- **共有ライブラリ [kunkit](https://github.com/m-tkg/kunkit) に標準で依存する**（SPM、`from: "1.1.0"`）。
  kuntraykun 連携（`KunIntegrationBridge`）と GitHub Releases の更新チェック（`KunUpdateKit`）は
  自前実装せず kunkit を使う（チェックリスト 4 と「Kuntraykun 連携」章を参照）。
- **メニューバー常駐**（Dock アイコンなし）。`Info.plist` に `LSUIElement = true`、
  `main.swift` で `NSApplication` を `.accessory` 起動（`MainActor.assumeIsolated`）。
- **多重起動防止**: 起動時に同じ bundle ID の他インスタンスがあれば、それを前面化して自分は `exit(0)`。
- `.app` 化は `Scripts/bundle.sh`（`swift build` → バンドル組み立て → 署名）。Xcode プロジェクトは持たない。
- リリースはタグ起点の GitHub Actions（詳細はチェックリスト 10）。

## 新規アプリの始め方（テンプレートから作る）

**テンプレートリポジトリ [kun-template](https://github.com/m-tkg/kun-template)** から作る（ゼロから書かない）。
ビルド可能な最小骨格（メニューバー常駐・多重起動防止・日英ローカライズ・設定ダイアログ（一般タブ）・
自動起動・アップデート（KunUpdateKit）・kunkit 連携・更新バッジ・bundle.sh・release.yml・Makefile・
CLAUDE.md 雛形）が入っている。

```sh
gh repo create m-tkg/<name>kun --template m-tkg/kun-template --public --clone
cd <name>kun
bash Scripts/rename.sh <Name>kun   # プレースホルダ Newkun をアプリ名へ一括置換（kun 末尾必須）
swift test && LOCAL=1 bash Scripts/bundle.sh debug   # 起動確認
```

- 命名は必ず `<name>kun`（kuntraykun の集約対象になる条件。bundle ID は `com.mtkg.<name>kun` に自動設定）。
- Secrets 登録（チェックリスト 1）を済ませてから初回リリースする。
- `Package.resolved` はコミットして追跡する（リリースの再現性のため。テンプレートも追跡済み）。
- あとは CLAUDE.md 末尾の「固有事項」を埋め、固有機能を Core の TDD から実装する（「開発の進め方」参照）。
- テンプレートに無い実装例が必要なとき（動的メニュー・ホットキー・イベントタップ等）は
  既存アプリを参照する: 動的メニュー = gitkun、ホットキー/ポップアップ = clipkun、イベントタップ = keykun。

---

## 必須チェックリスト

### 1. Secrets は `setup-release-secrets.sh` で登録する
配布用の署名＋公証の Secrets（計6つ）は、上位ディレクトリの **`setup-release-secrets.sh`** で一括登録する。
```sh
~/git/github.com/m-tkg/setup-release-secrets.sh -r m-tkg/<repo>
```
- 署名: `SIGNING_IDENTITY` / `SIGNING_CERTIFICATE_PASSWORD` / `SIGNING_CERTIFICATE_P12_BASE64`
- 公証: `NOTARY_APPLE_ID` / `NOTARY_PASSWORD` / `NOTARY_TEAM_ID`
- 署名は Developer ID Application（Team ID `G72M73C546`）。**安定署名でアクセシビリティ権限(TCC)が
  アップデート越しに保持される**（ad-hoc は毎回変わり無効化される）。
- ワークフローは Secrets が無ければ ad-hoc 署名／公証スキップにフォールバックする。
- `setup-release-secrets.sh` は秘密鍵(.p12)を含むので**リポジトリにコミットしない**（上位ディレクトリは git 管理外）。

### 2. すべての UI を日英対応にする
GUI 文字列は **日本語・英語の 2 言語**に対応し、OS の優先言語に追従する（既定 `en`）。
- 文字列リテラルを `Text`/`Button`/`NSMenuItem`/`NSAlert`/ウィンドウタイトル/HUD 等に直接渡さない。
  `Resources/{en,ja}.lproj/Localizable.strings` の**両方**にキーと対訳を足し、
  コードは `L.string("キー")` / `L.format("キー", 値…)` で参照する（`Localization.swift` の `L`）。
- `Package.swift` に `defaultLocalization: "en"` と `resources: [.process("Resources")]`。
- **`Info.plist` に `CFBundleLocalizations`（en, ja）が必須**。無いと macOS がアプリ言語を
  開発リージョン(en)に固定し、ネスト文字列バンドルも en にフォールバックして日本語が一切出ない。
  ```xml
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
  ```
- `L` は SwiftPM 生成のリソースバンドル（`<Name>_<Name>.bundle`）を自前探索で解決し、
  見つからなければ `.main` にフォールバック（`Bundle.module` はクラッシュしうるので使わない）。
  `bundle.sh` がこのバンドルを `Contents/Resources/` にコピーする。

### 3. bundle ID は `com.mtkg.****` にする
本番の bundle ID は **`com.mtkg.<appname>`**（例: `com.mtkg.keykun` / `com.mtkg.snapperkun`）。
`Info.plist` の `CFBundleIdentifier`、各 `Logger(subsystem:)`、`UpdateService` 等で一貫させる。

### 4. アップデート機能を入れる
GitHub Releases から最新版を取得して自己更新する。
- **最新リリースの取得は kunkit の `KunUpdateKit` を使う**（自前の URLSession 取得は書かない）:
  ```swift
  import KunUpdateKit
  // UpdateService.fetchLatestRelease() の HTTP 部分
  let data = try await GitHubReleaseFetcher(
      repoFullName: "m-tkg/<repo>", userAgent: "<App>").fetchLatestReleaseData()
  return try JSONDecoder().decode(ReleaseInfo.self, from: data)
  ```
  `GitHubReleaseFetcher` は **ETag 条件付きリクエスト**で、変更が無ければ 304（GitHub 未認証レート制限
  **60回/時** を消費しない）。kun シリーズ全アプリが同一 IP から毎時チェックしても 403 にならない。
  レート制限時は `RateLimitedError`（リセット時刻付き文言）が投げられ、そのままダイアログに出せる。
- `Core`: `ReleaseInfo`（`/releases/latest` の Decodable）と `VersionComparator`（タグの数値比較・純粋・テスト）。
- `App`: `UpdateService`（取得＝上記 KunUpdateKit、zip DL は URLSession 直）、
  `SelfUpdater`（zip を `ditto` 展開 → bundle ID 検証 → 旧プロセス終了待ち→入替の切り離しスクリプト→再起動）。
- メニューに「アップデートを確認…」を置き、起動時にサイレントチェック。新版があればメニュー文言を
  「アップデート v… をインストール…」に変える。
- 自己更新の bundle ID 検証は**基底ID（`.local` を除去）で比較**し、ローカルビルドからも本番へ更新できるようにする。
- **定期監視＋スリープ復帰チェック**: 起動時1回だけでなく、`Timer.scheduledTimer(withTimeInterval:repeats:)` で
  1時間ごとにサイレントチェックする（ETag 化により消費はほぼゼロ。`timer.tolerance` を間隔の 10% ほど付けて
  省電力のためコアレッシングを許可）。`Timer` はスリープ中に発火しないため、
  `NSWorkspace.didWakeNotification` を購読し**復帰時にも即チェック**する（ノート PC で「閉じている間に新版」に対応）。
  タイマーのコールバックはメインスレッドで `MainActor.assumeIsolated` を使って `@MainActor` のチェック処理を呼ぶ。
- **新版が見つかったらメニューバーアイコンの右下に赤バッジ（小さな赤丸）を出す**（最新なら消す）。実装の要点:
  - ベースアイコンは `isTemplate = true`（メニューバーの明暗で自動着色）の**まま維持**する。バッジは色付きなので、
    画像に焼き込む（非 template 化）と自動着色が壊れ、外観変化を監視して描き分ける手間が増える。
  - 代わりに**赤丸を別 view（`NSView` ＋ `wantsLayer` の `CALayer`）として `statusItem.button` にオーバーレイ**し、
    Auto Layout 制約で位置を固定する（手動 frame だと bounds 確定タイミングに依存して不安定）。メニューバー背景に
    溶けないよう細い白の縁取り（`borderWidth`/`borderColor`）を付ける。
  - 位置は **trailing 基準ではなくアイコン画像の幅基準**で固定する
    （`leading = button.leading + (iconWidth - badgeSize)`、`bottom = button.bottom`）。
    こうすると「ローカル」テキスト併記時（`imagePosition = .imageLeading`）でも常にアイコングリフの右下に乗る。
  - バッジの表示/非表示は、更新有無を集約する `setUpdateAvailable`/`clearUpdateAvailable`（メニュー文言変更と同じ箇所）に
    `badgeView?.isHidden` のトグルとして置き、起動時・定期・手動の**全チェック経路で自動同期**させる。
  - 注意: kuntraykun にアイコンを集約させて隠している間（`setManagedHidden(true)`）は自分のアイコンが非表示のため
    バッジも見えない（集約先へのバッジ伝搬は別途プロトコル拡張が必要）。

### 5. 自動起動（ログイン項目）機能を入れる
- `LoginItemController` で `SMAppService.mainApp`（macOS 13+）を register/unregister。
- **状態はシステム側が source of truth**。`Settings`/JSON には保存しない。表示時に `refresh()` で同期する。
- `.requiresApproval`（システム設定でログイン項目が無効）時は案内文を出す。
- トグルは設定の Apply/Cancel とは独立に**即時反映**する。

### 6. 設定は「設定」メニュー/ダイアログに集約する
- メニューバーのメニューは入口だけ（設定… / 権限確認 / アップデート確認 / 終了 など）。
  設定項目そのものはメニューに展開せず、**設定ダイアログ**に集約する。
- 設定ダイアログは SwiftUI を `NSWindow` にホストし、**タブ**で機能ごとに分割（機能追加はタブを足す）。
  「一般」タブ（自動起動・バージョン等）は**左端**に置く。
- **設定ダイアログ表示中は Dock アイコンを出す**。`SettingsWindowController` が表示時に
  `NSApp.setActivationPolicy(.regular)`、クローズ時に `.accessory` へ戻す。
- 設定の永続化は `Core` の `Settings`（機能ごとにサブ構造体）＋ `SettingsStore`（JSON、読込失敗で既定にフォールバック）。
  Codable は `decodeIfPresent ?? 既定値` で欠損キーを補完し前方/後方互換にする。
- SwiftUI を import するファイルでは `Settings`/`Binding` が SwiftUI と名前衝突するため
  `<Name>Core.Settings` / `@SwiftUI.Binding` と明示する。

### 7. ローカルビルドは「ローカル」表示で本番と区別する
- `bundle.sh` に `LOCAL=1` モードを設ける: bundle ID を `com.mtkg.<app>.local`、表示名を `<App> (Local)` にする。
- アプリは bundle ID が `.local` で終わるかで `isLocalBuild` を判定し、**メニューバーアイコンに「ローカル」を併記**、
  メニューのバージョン項目にも「(ローカル)」を付ける。
- 本番と bundle ID が違うので **TCC 権限が別エントリになり衝突しない**（独立して許可できる）。

### 8. ローカルの公証に気をつける
- 公証(notarization)は **CI のリリースビルドのみ**。ローカルビルド（`LOCAL=1` / `bundle.sh` 手元実行）は
  **署名はされるが公証されない**。配布物と取り違えない。
- ローカルビルドは bundle ID が `.local` で**別アプリ扱い**のため、**アクセシビリティ権限を別途付与**する必要がある。
- ローカルは未公証なので Gatekeeper の quarantine が付くと起動を阻まれることがある。必要なら
  `xattr -dr com.apple.quarantine <App>.app`（自己更新の入替スクリプトでも実施している）。
- ローカルでも Developer ID 署名（`SIGN_IDENTITY` 既定）にしておくと、再ビルドで TCC 権限が保持され検証が楽。

### 9. メニューにバージョン情報を入れる
- メニューバーのメニュー**先頭に操作不可のバージョン項目**（例: `Keykun 1.1.1`）を置き、区切り線を続ける。
- 文言は `Bundle.main` の `CFBundleShortVersionString`（`UpdateService.currentVersion`）から生成し、ローカルは「(ローカル)」を付す。
- 設定ダイアログ「一般」タブにもバージョンを表示する。

### 10. リリースは `make release-tag` で行う（タグ起点・安全チェック付き）
`release.yml` は **`v*` タグの push** をトリガーにする（`main` への push では発火させない）。
タグの作成・push はヒューマンエラーを防ぐため手動 `git tag`/`git push` ではなく、以下の Makefile
ターゲットを使う（whisperkun / kuntraykun / clipkun で実績あり。新規アプリはそのまま `Makefile` に追加する）。

```makefile
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist 2>/dev/null)
TAG := v$(VERSION)

.PHONY: release-tag
release-tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "error: CFBundleShortVersionString not found in Resources/Info.plist" >&2; \
		exit 1; \
	fi
	@branch="$$(git rev-parse --abbrev-ref HEAD)"; \
	if [ "$$branch" != "main" ]; then \
		echo "error: must be on main to cut a release (current: $$branch)" >&2; \
		exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "error: working tree is not clean" >&2; \
		exit 1; \
	fi
	@git fetch origin main --quiet
	@if [ "$$(git rev-parse HEAD)" != "$$(git rev-parse origin/main)" ]; then \
		echo "error: local main is not up to date with origin/main" >&2; \
		exit 1; \
	fi
	@if git rev-parse "$(TAG)" >/dev/null 2>&1; then \
		echo "error: tag $(TAG) already exists" >&2; \
		exit 1; \
	fi
	git tag -a "$(TAG)" -m "Release $(TAG)"
	git push origin "$(TAG)"
	@echo "Pushed tag $(TAG); the release workflow will build and publish it."
```

- 実行前に**ブランチが `main`**・**作業ツリーがクリーン**・**`origin/main` と同期済み**・**タグ未作成**を
  すべて確認してからタグを作成・push する。1つでも満たさなければ `exit 1` して中断する。
- リリース手順: (1) `Info.plist` の `CFBundleShortVersionString` を上げる PR を作成しマージする
  (2) `main` を最新化してから `make release-tag` を実行する。
- **ベータ（pre-release）**: `make beta-tag` で `v<version>-beta.<N>`（N は既存ベータ +1 で自動採番）を切る。
  `Info.plist` のバージョンは数値のまま（ベータはタグだけで切る）。ワークフローは押されたタグ名を採用し、
  **`-` を含むタグを `gh release create --prerelease` で GitHub pre-release として公開**する。
  GitHub の `/releases/latest` は pre-release を除外するため、**通常の更新チェック（kunkit の
  `GitHubReleaseFetcher`）はベータを自動的に無視する**（アプリ／kunkit のコード変更は不要）。
  ベータ検証者は Releases ページから手動で zip を入れる。
  - `release.yml` の `Resolve version` はタグ push 時 `github.ref_name` を採用し、`-` の有無で
    `prerelease` 出力を決める。非タグ実行（`workflow_dispatch`）は従来どおり Info.plist から stable タグを導出する。
- プロジェクトが `Info.plist` を直接持たず Xcode の `project.pbxproj`（`MARKETING_VERSION`）で
  バージョン管理している場合は、`VERSION`/`TAG` の取得部分だけ `grep`/`sed` で `MARKETING_VERSION` を
  読む形に差し替える（他の安全チェック部分は共通）。

---

## イベントタップ系（keykun のような CGEventTap を使う場合）

- **イベントタップは1つを共有**し、機能ごとにハンドラを登録する（別タップを作らない）。
- **コールバック内で重い処理や再入しうる post を同期実行しない**。重い処理は `tapDisabledByTimeout` を招き
  イベントを取りこぼして状態が固着する。副作用は `DispatchQueue.main.async` でコールバック復帰後に逃がす。
- **タップ無効化時はハンドラ状態をリセット**して取りこぼし後の固着を防ぐ。
- **合成キーイベントは `.cghidEventTap`（HID 相当）に post**する（`.cgSessionEventTap` だと IME 等に届かない）。
- 入力モード切替は **英数/かなキー送出**が確実（`TISSelectInputSource` は「選択中の再選択が no-op」で
  複数モード IME では切り替わらない）。

## Kuntraykun 連携（メニューバーアイコンの集約）

`kuntraykun`（`com.mtkg.kuntraykun`）は、複数の kun アプリのメニューバーアイコンを**1つに集約**するハブ。
各 kun アプリはこの「連携の口」を実装すると、kuntraykun に**まとめられる**ようになる
（自分のアイコンを隠し、kuntraykun のアイコンから自分のメニューを開かせる）。新規 kun アプリは初めから対応しておく。

- **正式仕様**: kuntraykun リポジトリの `docs/kun-integration-protocol.md`（連携プロトコル v1〜v4）。
- **実装は共有ライブラリ [kunkit](https://github.com/m-tkg/kunkit) を使う**（自前実装やファイルコピーはしない）。
  ```swift
  // Package.swift
  .package(url: "https://github.com/m-tkg/kunkit.git", from: "1.1.0"),
  // executableTarget の dependencies に
  .product(name: "KunIntegrationBridge", package: "kunkit"),
  ```
  ```swift
  import KunIntegrationBridge
  // AppDelegate の起動処理（statusItem / menu は自分のステータスバー実装のもの）
  let bridge = KuntraykunBridge(statusItem: statusItem, menu: menu) // 標準配線
  bridge.start()  // 観測開始・appLaunched 送信・初回メニュー書き出しまで行う
  kuntraykunBridge = bridge
  // アップデート有無が変わったら kuntraykunBridge?.reportUpdate(hasUpdate)          // v3
  // メニュー文言・チェック状態が変わったら kuntraykunBridge?.exportMenuSnapshot()    // v4（表示中は自動保留）
  // アイコンを設定する箇所すべてで KuntraykunIconExport.export(statusItem.button?.image) // v2
  ```
  特殊な配線が必要なアプリはクロージャ版 `init(setHidden:popUpMenu:exportMenu:performMenuItem:trackingMenu:)` を使う。
  **参照実装**: `clipkun`（`StatusBarController.makeKuntraykunBridge()` と `onMenuContentChanged` の配線）。
- **kunkit の更新運用**: 連携プロトコルの変更・修正は kunkit 側（TDD）で行って semver タグを発行し、
  各アプリは `swift package update kunkit` で追従する（`from:` のマイナー指定のため 1.x は自動追従、
  破壊的変更はメジャーを上げて全アプリで明示更新）。`Package.resolved` を追跡しているリポジトリ
  （clipkun / gitkun / pointerkun / kuntraykun。新規アプリは追跡が標準）では resolved の変更もコミットする。
- **連携のデバッグ**: まず `~/Library/Application Support/Kuntraykun/Menus/<基底ID>.json` の中身
  （空なら書き出し側の問題）と、Console の subsystem `<bundleID>` / category `kuntraykun` のログを確認する。
### プロトコルの概要（中身は kunkit が実装済み。詳細は正式仕様を読む）
`DistributedNotificationCenter` の分散通知＋共有ファイル（`~/Library/Application Support/Kuntraykun/`）で協調する。
定数・モデルは kunkit の `KunIntegrationProtocol` にあり、ハブとアプリが同じ定義を参照する。

- **v1 アイコン集約**: `sync`（管理対象集合）を受けて `隠す = 管理対象 かつ kuntraykun 起動中` を適用
  （未起動なら隠さないフォールバック）。`showMenu` で自分のメニューを kuntraykun アイコン直下に popUp。
- **v2 実アイコン書き出し**: `statusItem.button?.image` を**設定する箇所すべて**（起動時＋状態変化時）で
  `KuntraykunIconExport.export(_:)` を呼ぶ。状態で色が変わるアプリ（例 gitkun）では必須。
- **v3 更新あり集約**: 自分の更新有無が変わる箇所（更新バッジの出し入れと同じ場所）で
  `bridge.reportUpdate(_:)` を呼ぶ。kuntraykun 側に集約バッジ・行の赤丸が出る。
- **v4 サブメニュー表示**: メニュー構造を JSON で共有し、kuntraykun がサブメニューとして再構築、
  項目クリックを `invokeMenuItem` で実行依頼し返す。アプリ側は**メニュー内容が変わる箇所**で
  `bridge.exportMenuSnapshot()` を呼ぶだけ（表示中の書き出し保留・世代管理・項目実行は kunkit が内蔵。
  `KuntraykunMenuExport.export` を直接呼ばないこと）。未対応/スナップショット空のアプリは
  従来のクリック → popUp にフォールバックする。

kuntraykun が集約対象とみなすのは bundleID が `com.mtkg.` で始まり**末尾が `kun`** のアプリのみ
（命名規則は「新規アプリの始め方」参照）。管理対象フラグは kunkit が `UserDefaults`
（キー `KuntraykunManaged`）に永続化する。

アイコン表示判定（`NSWorkspace.runningApplications` の KVO・復活デバウンス等）や v4 の
シリアライズ規則・世代トークンなど、過去に実機で踏んだ罠と対処は**すべて kunkit に実装済み**。
経緯や仕様の詳細が必要なときは kuntraykun リポジトリの `docs/kun-integration-protocol.md`（v1〜v4）と
kunkit のソースコメントを読む（本ファイルには重複記載しない）。

## ブランチ運用（必須）

- **`main` ブランチへ直接コミット/push しない**。変更は必ず **Pull Request 経由**で行う。
- 作業ブランチは**必ずその時点の最新の `main` から切る**。ブランチ作成前に
  `git fetch origin && git switch main && git pull --ff-only`（または `git fetch && git switch -c <branch> origin/main`）
  で main を最新化してから分岐する。
- PR は `gh pr create` で作成し、マージはレビュー後に行う。
- **PR 作成後に追加の修正を行うときは、まずその PR が既にマージされていないか確認する**
  （`gh pr view <番号> --json state,mergedAt`）。マージ済みの場合、その PR の作業ブランチへ
  push しても main には反映されない（孤立コミットになる）。マージ済みなら**最新 `main` から
  新しいブランチを切り直し**、必要な修正と（リリースが要るなら）バージョン更新を入れて別 PR を出す。
- リリース用 Actions は `push: tags: ["v*"]` で発火し、`main` への push 単体では発火しない
  （タグは `make release-tag` を実行しない限り作られない）。ただし PR マージ経由を徹底するのは
  レビュー・履歴管理のためであり、事故防止のための最終防波堤ではない点に注意（`make release-tag` 側の
  安全チェックが実質的な防波堤）。

## 開発の進め方

- 純粋ロジック（`Core`）は **TDD**（テスト先行）。UI/OS 連携は手動確認（実機で権限付与が必要）。
  kun シリーズ共通のロジック（連携・更新チェック等）に手を入れるときは、各アプリではなく
  **kunkit 側に TDD で実装して semver タグ**を発行し、各アプリは依存更新で追従する。
- 新機能の追加手順: ①判定ロジックを `Core` に純粋実装＋テスト → ②`Settings` にサブ構造体を足す →
  ③設定 UI にタブを足す → ④GUI 文字列を en/ja 両方に対訳追加。
- リリース手順はチェックリスト 10（バージョン更新 PR → マージ → `make release-tag`。署名＋公証は CI が実施）。
