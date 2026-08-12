// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Yi Oracle — 易经AI占卜App的Swift Package依赖声明
///
/// 核心依赖：
/// - mlc-llm: 本地LLM推理引擎（支持Llama-3.2-3B / Qwen2.5-3B）
/// - SQLite.swift: 本地SQLite数据库封装
/// - SimilaritySearchKit: 本地向量检索库（RAG用）
///
/// 注：实际集成MLC-LLM需要额外配置模型文件，当前项目使用Protocol/Mock替代，
/// 确保框架代码可独立编译运行。本Package.swift声明了预期的生产依赖。
let package = Package(
    name: "YiOracle",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "YiOracle",
            targets: ["YiOracle"]
        ),
    ],
    dependencies: [
        // MLC-LLM iOS SDK — 本地LLM推理引擎（MLCSwift）
        // 官方集成方式（https://llm.mlc.ai/docs/deploy/ios.html）：
        //   1) 将 mlc-llm 作为 git submodule 克隆到 ../mlc-llm
        //   2) 在 Xcode 中 Add Local Package，指向 ../mlc-llm/ios/MLCSwift
        //   3) 在 Frameworks, Libraries 中嵌入 MLCSwift
        // 由于是本地包，SPM 无法直接用远程 URL 引用，下面给出本地路径写法（需先准备 submodule）：
        // .package(path: "../mlc-llm/ios/MLCSwift"),
        // 对应 target 依赖：.product(name: "MLCSwift", package: "MLCSwift")
        // 未链接时，MLCLLMEngine.swift 通过 `#if canImport(MLCSwift)` 自动退化为占位实现，
        // 保证仅运行 Mock 的 CI / 开发构建仍可编译。

        // SQLite.swift — 本地数据库
        .package(
            url: "https://github.com/stephencelis/SQLite.swift.git",
            from: "0.15.3"
        ),

        // 本地向量检索（RAG服务核心）
        // 生产环境使用 SimilaritySearchKit 或 Accelerate 框架
        // 当前使用Protocol模拟
        // .package(url: "https://github.com/ZachNagengast/similarity-search-kit.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "YiOracle",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: ".",
            sources: [
                "Theme.swift",
                "Models/",
                "Views/",
                "Services/",
                "Data/",
                "Storage/",
            ]
        ),
    ]
)
