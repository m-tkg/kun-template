import Foundation

/// アプリ全体の設定。機能ごとにサブ構造体を持ち、機能追加時はここにプロパティを足して拡張する。
///
/// 前方/後方互換のため Codable は欠損キーを既定値で補完する（古い/新しい設定ファイルでも壊れない）。
public struct Settings: Codable, Equatable {
    /// 「一般」まわりの設定。
    /// 自動起動（ログイン項目）はシステム側が source of truth のため、ここには保存しない。
    public var general: GeneralSettings

    public init(general: GeneralSettings = GeneralSettings()) {
        self.general = general
    }

    /// 既定設定。
    public static let `default` = Settings()

    private enum CodingKeys: String, CodingKey {
        case general
        // TODO: 機能を追加したらキーを足す（例: case history）。
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.general = try container.decodeIfPresent(GeneralSettings.self, forKey: .general)
            ?? GeneralSettings()
    }
}

/// 「一般」タブに対応する設定。
/// 現状は永続化する項目が無い（機能を追加したらここにプロパティを足し、
/// `decodeIfPresent ?? 既定値` のパターンで欠損キーを補完する）。
public struct GeneralSettings: Codable, Equatable {
    public init() {}
}
