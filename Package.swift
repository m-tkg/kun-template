// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Newkun",
    // ローカライズ済みリソース（en/ja）を持つため既定言語を指定する。
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // kuntraykun 連携（プロトコル定数・Bridge・アイコン/メニュー書き出し）と
        // GitHub Releases の更新チェック（KunUpdateKit）の共有ライブラリ。
        .package(url: "https://github.com/m-tkg/kunkit.git", from: "1.2.0")
    ],
    targets: [
        // 純粋ロジック（テスト対象）: AppKit/Carbon 等に依存しない設定モデル。
        // 固有機能のロジックはここに TDD で足す。
        // （ReleaseInfo / VersionComparator は kunkit の KunUpdateKit を参照する）
        .target(
            name: "NewkunCore"
        ),
        // 実行ファイル本体: メニューバー常駐・設定UI・アップデート・kuntraykun 連携。
        .executableTarget(
            name: "Newkun",
            dependencies: [
                "NewkunCore",
                .product(name: "KunIntegrationBridge", package: "kunkit"),
                .product(name: "KunUpdateKit", package: "kunkit"),
            ],
            // en.lproj / ja.lproj の Localizable.strings をリソースバンドルに含める。
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NewkunCoreTests",
            dependencies: ["NewkunCore"]
        ),
    ]
)
