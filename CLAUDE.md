# CLAUDE.md — Newkun

このリポジトリで作業する際のガイド。

**メニューバー常駐アプリ（kun シリーズ）共通の方針は、同梱の [`CLAUDE_base.md`](./CLAUDE_base.md) を参照**
（Swift Package 構成・日英ローカライズ・アップデート・kunkit 連携・リリース手順・ブランチ運用など）。
本ファイルには Newkun 固有の事項のみを記す。共通方針を変えるときは `CLAUDE_base.md` を編集する
（このリポジトリが共通ガイドの canonical。各 kun アプリはここから追従する）。

---

# Newkun 固有事項

## 概要
<!-- TODO: Newkun が何をするアプリかを1〜2行で書く。bundle ID は com.mtkg.newkun。 -->

## 機能
<!-- TODO: 機能を箇条書きで列挙する（メニュー項目・設定タブ・ホットキー等）。 -->

## 技術メモ
<!-- TODO: 実装上の判断・OS 連携の罠・権限（TCC）の要否など、後から読む人向けのメモを残す。 -->

## Kuntraykun 連携（実装済み・kunkit 利用）
- `KuntraykunBridge`（kunkit の `KunIntegrationBridge`）を標準配線で使用。
  `StatusBarController.makeKuntraykunBridge()` → `AppDelegate` で `start()`。
- v2: アイコンは `KuntraykunIconExport.export(_:)` で書き出し済み（アイコンを差し替える箇所を
  追加したら、その全てで export し直すこと）。
- v3: 更新有無は `kuntraykunBridge?.reportUpdate(_:)` で通知済み。
- v4: メニュー文言の変化は `onMenuContentChanged` → `exportMenuSnapshot()` で再書き出し済み
  （メニュー項目を動的に変える機能を足したら、同じ配線に乗せる）。
