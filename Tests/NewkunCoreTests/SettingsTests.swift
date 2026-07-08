import XCTest
@testable import NewkunCore

/// `NewkunCore.Settings` の Codable 互換性テスト。
/// 設定の永続化そのもの（ファイル入出力）は kunkit の `KunSettingsStore` が担うため、
/// ここではアプリ固有の設定モデルが「欠損キーを既定値で補完する」前方/後方互換を検証する。
/// 固有の設定項目を足したら、その既定値・ラウンドトリップもここに追加すること。
final class SettingsTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    func testEncodeDecodeRoundTrip() throws {
        let settings = Settings.default
        let data = try encoder.encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testDecodesEmptyObjectAsDefault() throws {
        // 空 JSON（全キー欠損）でも既定値で埋まる。
        let data = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, .default)
    }
}
