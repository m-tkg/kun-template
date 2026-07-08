import SwiftUI
import AppKit
import NewkunCore

/// 設定ダイアログの編集状態。変更は即時反映する（Apply/OK は持たない）。
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: NewkunCore.Settings {
        didSet {
            guard settings != oldValue else { return }
            onChange(settings)
        }
    }
    private let onChange: (NewkunCore.Settings) -> Void

    init(settings: NewkunCore.Settings, onChange: @escaping (NewkunCore.Settings) -> Void) {
        self.settings = settings
        self.onChange = onChange
    }
}

/// 設定ダイアログ本体。タブで機能ごとの設定を切り替える。各変更は即座に反映・保存される。
/// 「一般」タブ（自動起動・バージョン）は左端に置き、機能追加時はタブを右へ足す。
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var loginItem: LoginItemController

    @State private var loginItemError: String?

    var body: some View {
        TabView {
            GeneralSettingsTab(loginItem: loginItem, errorMessage: $loginItemError)
                .tabItem { Text(L.string("tab.general")) }

            // TODO: 固有機能の設定タブはここに足す（`$viewModel.settings` の Binding を渡す）。
        }
        .padding()
        .frame(width: 460, height: 320)
        .alert(L.string("alert.error.title"), isPresented: Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }
}

/// 「一般」タブ。ログイン時の自動起動とバージョン表示。
struct GeneralSettingsTab: View {
    @ObservedObject var loginItem: LoginItemController
    @SwiftUI.Binding var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(L.string("settings.launch_at_login"), isOn: Binding(
                get: { loginItem.isEnabled },
                set: { newValue in
                    if let message = loginItem.setEnabled(newValue) {
                        errorMessage = message
                    }
                }
            ))

            Text(L.format("settings.version", UpdateService.currentVersion))
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
