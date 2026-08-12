import Foundation

// MARK: - RAG检索服务协议

/// 本地RAG（检索增强生成）服务协议
///
/// 在本地设备上执行语义搜索，从易经知识库中检索与用户问题最相关的内容。
/// 使用本地向量库进行嵌入匹配（不使用云端API）。
///
/// 设计意图：
/// - 全本地：所有向量计算和检索在设备端完成
/// - 轻量级：针对3B模型优化，不存储大规模向量
/// - 双层检索：关键词匹配（快速）+ 向量相似度（精准）
protocol RAGServiceProtocol {
    /// 根据用户查询检索相关卦象
    func retrieveRelevantHexagrams(
        query: String,
        topK: Int
    ) async throws -> [RAGResult]

    /// 根据用户查询检索相关易经文本
    func retrieveRelevantTexts(
        query: String,
        topK: Int
    ) async throws -> [RAGTextResult]

    /// 索引新的卦象数据到向量库
    func indexHexagram(_ hexagram: Hexagram) async throws

    /// 索引概念映射
    func indexConceptMapping(_ mapping: [String: [Int]]) async throws
}

/// RAG检索结果（卦象级别）
struct RAGResult: Identifiable, Sendable {
    let id = UUID()
    let hexagramID: Int
    let hexagramName: String
    let relevanceScore: Float      // 0.0~1.0
    let matchedKeywords: [String]
    let contextText: String        // 匹配到的上下文文本
}

/// RAG检索结果（文本段落级别）
struct RAGTextResult: Identifiable, Sendable {
    let id = UUID()
    let hexagramID: Int?
    let content: String
    let relevanceScore: Float
    let source: String
}

// MARK: - Mock RAG服务实现

/// Mock RAG服务 — 使用关键词匹配模拟向量检索
///
/// 在不需要真实向量库的情况下运行App。
/// 实际检索逻辑：
/// 1. 关键词提取（从ConceptMappingStore）
/// 2. 卦象匹配（从HexagramDataStore）
/// 3. 相关性打分（关键词命中率 + 语义权重）
///
/// 生产环境可替换为：
/// - Apple Accelerate 框架实现余弦相似度
/// - SimilaritySearchKit 本地向量检索
/// - 自定义 FAISS-lite 实现
actor MockRAGService: RAGServiceProtocol {
    private var indexedHexagrams: [Int: Hexagram] = [:]
    private var conceptMapping: [String: [Int]] = [:]
    private var isInitialized = false

    init() {
        // 延迟初始化在 setup() 中完成
    }

    /// 初始化向量库 — 索引所有64卦
    func setup() async {
        guard !isInitialized else { return }

        // 索引所有卦象
        for hex in HexagramDataStore.shared.allHexagrams {
            indexedHexagrams[hex.id] = hex
        }

        // 加载概念映射
        conceptMapping = [
            "creativity": [1], "receptivity": [2], "patience": [5],
            "conflict": [6], "peace": [11], "harmony": [11],
            "change": [49], "growth": [46], "stillness": [52],
            // ... 更多映射由 ConceptMappingStore 提供
        ]

        isInitialized = true
        print("[MockRAG] Initialized with \(indexedHexagrams.count) hexagrams")
    }

    func retrieveRelevantHexagrams(
        query: String,
        topK: Int = 5
    ) async throws -> [RAGResult] {
        if !isInitialized { await setup() }

        let queryLower = query.lowercased()

        // Step 1: 关键词提取
        let detectedIDs = ConceptMappingStore.shared.detectHexagrams(from: query)

        // Step 2: 扩展检索 — 加入季节/月相推荐
        let seasonalIDs = ConceptMappingStore.shared.seasonalHexagramIDs()

        // Step 3: 合并并计算相关性
        var scoredResults: [(id: Int, score: Float, keywords: [String])] = []

        // 已检测到的卦象
        for id in detectedIDs {
            if let hex = indexedHexagrams[id] {
                let keywords = hex.keywords.filter { queryLower.contains($0) }
                let score = min(1.0, Float(keywords.count) * 0.3 + 0.5)
                scoredResults.append((id, score, keywords))
            }
        }

        // 季节卦象作为补充
        for id in seasonalIDs {
            if !scoredResults.contains(where: { $0.id == id }),
               let hex = indexedHexagrams[id] {
                scoredResults.append((id, 0.3, ["seasonal"]))
            }
        }

        // 排序并取TopK
        scoredResults.sort { $0.score > $1.score }
        let topResults = Array(scoredResults.prefix(topK))

        return topResults.map { result in
            let hex = indexedHexagrams[result.id]!
            return RAGResult(
                hexagramID: result.id,
                hexagramName: hex.nameEN,
                relevanceScore: result.score,
                matchedKeywords: result.keywords,
                contextText: "\(hex.nameCN) (\(hex.nameEN)): \(hex.coreMeaning)"
            )
        }
    }

    func retrieveRelevantTexts(
        query: String,
        topK: Int = 3
    ) async throws -> [RAGTextResult] {
        if !isInitialized { await setup() }

        var results: [RAGTextResult] = []
        let queryLower = query.lowercased()

        for (id, hex) in indexedHexagrams {
            // 检查卦辞和核心含义中是否包含关键词
            let searchText = "\(hex.nameEN.lowercased()) \(hex.coreMeaning.lowercased()) " +
                             "\(hex.judgementEN.lowercased()) \(hex.imageEN.lowercased())"

            // 简单的关键词命中率评分
            let keywords = hex.keywords
            let hitCount = keywords.filter { queryLower.contains($0) }.count
            let score = Float(hitCount) / Float(max(1, keywords.count))

            if score > 0 {
                results.append(RAGTextResult(
                    hexagramID: id,
                    content: "Hexagram \(id) \(hex.nameEN): \(hex.judgementEN)",
                    relevanceScore: score,
                    source: "I Ching - Hexagram Data"
                ))
            }
        }

        // 排序并取TopK
        results.sort { $0.relevanceScore > $1.relevanceScore }
        return Array(results.prefix(topK))
    }

    func indexHexagram(_ hexagram: Hexagram) async throws {
        indexedHexagrams[hexagram.id] = hexagram
    }

    func indexConceptMapping(_ mapping: [String: [Int]]) async throws {
        conceptMapping.merge(mapping) { _, new in new }
    }
}

// MARK: - RAG服务工厂

enum RAGServiceFactory {
    static func create(useMock: Bool = true) -> RAGServiceProtocol {
        if useMock {
            return MockRAGService()
        }
        // 生产环境：使用本地向量库
        // return LocalVectorRAGService()
        fatalError("Production RAG service not yet configured")
    }
}
