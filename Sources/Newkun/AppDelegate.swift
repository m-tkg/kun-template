import AppKit
import OSLog
import NewkunCore
import KunAppKit
import KunIntegrationBridge
import KunSupport
import KunUpdateKit

private let log = Logger(subsystem: "com.mtkg.newkun", category: "app")

/// アプリ本体。設定の読込・反映、ステータスバー UI・設定ウィンドウ・
/// アップデート・kuntraykun 連携の配線を担う。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = KunSettingsStore<Settings>(
        url: KunSettingsStore<Settings>.defaultURL(appFolderName: "Newkun"), defaultValue: .default)

    private var settings = Settings.default

    private var statusBar: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var updateCheckTimer: Timer?
    private var kuntraykunBridge: KuntraykunBridge?

    // アップデート関連。
    private let updateService = UpdateService()
    private let selfUpdater = SelfUpdater(appName: "Newkun")
    private var availableRelease: ReleaseInfo?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = store.load()

        // TODO: ここにアプリ固有機能の配線を足す（監視の開始・ホットキー登録・
        //       コールバックの接続など）。ロジック本体は NewkunCore に TDD で実装する。

        applySettings(settings)

        statusBar = StatusBarController(
            openSettings: { [weak self] in self?.openSettings() },
            checkForUpdate: { [weak self] in self?.startUpdateCheck(interactive: true) },
            quit: { NSApp.terminate(nil) }
        )

        // kuntraykun 連携（kunkit）: 管理対象なら自分のアイコンを隠し、showMenu でメニューを出す。
        // v4: メニュー構造を共有してサブメニュー表示・項目実行にも応じる（初回書き出しは start() 内）。
        let bridge = statusBar!.makeKuntraykunBridge()
        bridge.start()
        kuntraykunBridge = bridge
        // メニュー文言の変化（アップデート有無）でスナップショットを書き出し直す。
        statusBar?.onMenuContentChanged = { [weak self] in
            self?.kuntraykunBridge?.exportMenuSnapshot()
        }

        startUpdateCheck(interactive: false)
        startUpdateTimer()
    }

    /// 設定を各所へ反映する。
    private func applySettings(_ settings: Settings) {
        // TODO: 固有機能を追加したら、設定の変更をここで各コンポーネントへ反映する。
        _ = settings
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                initialSettings: settings,
                onChange: { [weak self] newSettings in
                    guard let self else { return }
                    self.settings = newSettings
                    self.applySettings(newSettings)
                    try? self.store.save(newSettings)
                }
            )
        }
        settingsWindowController?.show()
    }

    // MARK: - アップデート

    /// 定期サイレントチェック＋スリープ復帰チェックを開始する。
    /// 間隔と tolerance は kun シリーズ共通の `KunUpdateSchedule`（kunkit）を参照する
    /// （取得は kunkit の ETag 条件付きリクエストのため、変更が無ければレート制限も消費しない）。
    /// `Timer` はスリープ中に発火しないため、`didWakeNotification` で復帰時にも即チェックする。
    private func startUpdateTimer() {
        let timer = Timer.scheduledTimer(
            withTimeInterval: KunUpdateSchedule.checkInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startUpdateCheck(interactive: false)
            }
        }
        timer.tolerance = KunUpdateSchedule.checkIntervalTolerance
        updateCheckTimer = timer

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        startUpdateCheck(interactive: false)
    }

    private func startUpdateCheck(interactive: Bool) {
        Task { @MainActor in
            do {
                let release = try await updateService.fetchLatestRelease()
                let isNewer = VersionComparator.isNewer(
                    tag: release.tagName, than: UpdateService.currentVersion)
                if isNewer {
                    availableRelease = release
                    statusBar?.setUpdateAvailable(tag: release.tagName)
                } else {
                    availableRelease = nil
                    statusBar?.clearUpdateAvailable()
                }
                // kuntraykun にもアップデート有無を伝える（集約バッジ/赤丸用）。
                kuntraykunBridge?.reportUpdate(isNewer)
                if interactive {
                    if isNewer {
                        promptInstall(release)
                    } else {
                        showInfo(L.format("update.latest", UpdateService.currentVersion))
                    }
                }
            } catch {
                log.error("update check failed: \(error.localizedDescription, privacy: .public)")
                if interactive {
                    showError(L.format("update.check_failed", error.localizedDescription))
                }
            }
        }
    }

    private func promptInstall(_ release: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L.format("update.available.title", release.tagName)
        alert.informativeText = L.format("update.available.body", UpdateService.currentVersion)
        alert.addButton(withTitle: L.string("update.button.update"))
        alert.addButton(withTitle: L.string("update.button.open_release"))
        alert.addButton(withTitle: L.string("button.cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            performUpdate(release)
        case .alertSecondButtonReturn:
            if let url = URL(string: release.htmlUrl) { NSWorkspace.shared.open(url) }
        default:
            break
        }
    }

    private func performUpdate(_ release: ReleaseInfo) {
        Task { @MainActor in
            do {
                try await selfUpdater.performUpdate(to: release)
            } catch {
                log.error("self-update failed: \(error.localizedDescription, privacy: .public)")
                showError(L.format("update.failed", error.localizedDescription))
            }
        }
    }

    private func showInfo(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Newkun"
        alert.informativeText = text
        alert.runModal()
    }

    private func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.string("alert.error.title")
        alert.informativeText = text
        alert.runModal()
    }
}
