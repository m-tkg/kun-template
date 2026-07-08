import XCTest
@testable import NewkunCore

final class SettingsStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("newkun-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    func testLoadReturnsDefaultWhenMissing() {
        let store = SettingsStore(url: tempURL())
        XCTAssertEqual(store.load(), .default)
    }

    // 設定項目を足したら、既定値以外の値でラウンドトリップするテストに拡張すること。
    func testSaveThenLoadRoundTrip() throws {
        let url = tempURL()
        let store = SettingsStore(url: url)
        let settings = Settings.default
        try store.save(settings)
        XCTAssertEqual(store.load(), settings)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testLoadReturnsDefaultWhenCorrupted() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not json".data(using: .utf8)!.write(to: url)
        let store = SettingsStore(url: url)
        XCTAssertEqual(store.load(), .default)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // 欠損キーは既定値で補完される（前方/後方互換）。
    func testLoadFillsMissingKeysWithDefaults() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".data(using: .utf8)!.write(to: url)
        let store = SettingsStore(url: url)
        XCTAssertEqual(store.load(), .default)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
