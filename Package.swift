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
        // kuntraykun 連携（Bridge）・更新チェック（KunUpdateKit）・共通ユーティリティ
        // （KunSupport: 設定永続化/ProcessRunner 等、KunAppKit: 自己更新/ログイン項目/多重起動ガード）
        // をまとめた共有ライブラリ。
        .package(url: "https://github.com/m-tkg/kunkit.git", from: "1.3.0")
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
                .product(name: "KunSupport", package: "kunkit"),
                .product(name: "KunAppKit", package: "kunkit"),
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
