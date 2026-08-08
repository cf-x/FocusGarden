import Foundation

struct AllowedApp: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let path: String

    init(name: String, bundleIdentifier: String?, path: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.id = bundleIdentifier ?? path
    }
}

struct AllowedApplicationMatcher {
    private struct Identity {
        let bundleIdentifier: String?
        let canonicalPath: String
    }

    private let identities: [Identity]

    init(applications: [AllowedApp]) {
        identities = applications.map {
            Identity(
                bundleIdentifier: $0.bundleIdentifier,
                canonicalPath: Self.canonicalPath($0.path)
            )
        }
    }

    func allows(bundleIdentifier: String?, path: String?) -> Bool {
        guard let path else { return false }
        let candidatePath = Self.canonicalPath(path)

        return identities.contains { identity in
            guard identity.canonicalPath == candidatePath else { return false }
            guard let expectedIdentifier = identity.bundleIdentifier else { return true }
            return expectedIdentifier == bundleIdentifier
        }
    }

    static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }
}

struct AllowedWebsite: Codable, Hashable, Identifiable {
    let id: String
    let host: String

    init?(input: String) {
        var candidate = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !candidate.isEmpty else { return nil }

        if candidate.hasPrefix("*.") {
            candidate.removeFirst(2)
        }
        if !candidate.contains("://") {
            candidate = "https://\(candidate)"
        }

        guard let parsedHost = URLComponents(string: candidate)?.host else { return nil }
        var normalized = parsedHost.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if normalized.hasPrefix("www.") {
            normalized.removeFirst(4)
        }
        guard Self.isValidHost(normalized) else { return nil }

        self.host = normalized
        self.id = normalized
    }

    func allows(host candidate: String) -> Bool {
        let normalized = candidate.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return normalized == host || normalized.hasSuffix(".\(host)")
    }

    private static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253 else { return false }

        if host.contains(":") {
            let ipv6Characters = CharacterSet(charactersIn: "0123456789abcdef:.")
            return host.unicodeScalars.allSatisfy(ipv6Characters.contains)
        }

        return host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            guard !label.isEmpty,
                  label.count <= 63,
                  label.first != "-",
                  label.last != "-" else { return false }
            return label.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "-"
            }
        }
    }
}

enum FocusDurationPolicy {
    static let defaultMinutes = 25
    static let validRange = 5...120

    static func normalized(_ minutes: Int) -> Int {
        min(validRange.upperBound, max(validRange.lowerBound, minutes))
    }
}

struct FocusProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var allowedApps: [AllowedApp]
    var allowedWebsites: [AllowedWebsite]

    init(
        id: UUID = UUID(),
        name: String,
        allowedApps: [AllowedApp] = [],
        allowedWebsites: [AllowedWebsite] = []
    ) {
        self.id = id
        self.name = name
        self.allowedApps = allowedApps
        self.allowedWebsites = allowedWebsites
    }
}

enum AmbientSound: String, Codable, CaseIterable, Identifiable {
    case pinkNoise
    case rainOnLeaves = "rain"
    case brownNoise
    case campfire = "stream"
    case ocean
    case forestStream = "forest"
    case whiteNoise
    case cafe

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pinkNoise: "粉噪声"
        case .rainOnLeaves: "叶上细雨"
        case .brownNoise: "棕噪声"
        case .campfire: "林间篝火"
        case .ocean: "深夜海浪"
        case .forestStream: "林间溪流"
        case .whiteNoise: "白噪声"
        case .cafe: "远处咖啡馆"
        }
    }

    var symbol: String {
        switch self {
        case .pinkNoise: "waveform"
        case .rainOnLeaves: "cloud.rain.fill"
        case .brownNoise: "speaker.wave.2.fill"
        case .campfire: "flame.fill"
        case .ocean: "moon.stars.fill"
        case .forestStream: "water.waves"
        case .whiteNoise: "dot.radiowaves.left.and.right"
        case .cafe: "cup.and.saucer.fill"
        }
    }

    var bestFor: String {
        switch self {
        case .pinkNoise: "阅读 · 编程"
        case .rainOnLeaves: "日常工作"
        case .brownNoise: "安静思考"
        case .campfire: "写作 · 阅读"
        case .ocean: "构思 · 放松"
        case .forestStream: "疲劳恢复"
        case .whiteNoise: "强力隔音"
        case .cafe: "头脑风暴"
        }
    }

    var spectrum: String {
        switch self {
        case .pinkNoise: "全频 · 每倍频程 −3 dB"
        case .rainOnLeaves: "宽频 · 柔和叶面细雨"
        case .brownNoise: "低频偏重 · 每倍频程 −6 dB"
        case .campfire: "中低频 · 稀疏火焰爆裂声"
        case .ocean: "低中频 · 约 50 Hz–2 kHz"
        case .forestStream: "中高频 · 约 300 Hz–8 kHz"
        case .whiteNoise: "全频 · 每 Hz 等功率"
        case .cafe: "中频 · 约 200 Hz–4 kHz"
        }
    }

    var detail: String {
        switch self {
        case .pinkNoise:
            "比白噪声柔和，兼顾声音遮蔽与长时间耐听，是深度工作的默认选择。"
        case .rainOnLeaves:
            "细雨落在树叶上的连续沙沙声，变化柔和，能盖住键盘和走动声。"
        case .brownNoise:
            "能量集中在低频，声音厚而不尖；适合对高频嘶声敏感的人。"
        case .campfire:
            "温暖的燃烧底声夹着稀疏爆裂，适合阅读与写作；精密任务时建议调低音量。"
        case .ocean:
            "缓慢起伏接近呼吸节奏，适合梳理想法；精密任务时可能略显催眠。"
        case .forestStream:
            "连续水声带少量细节，适合专注疲劳时恢复，但不宜开得太响。"
        case .whiteNoise:
            "高频更明显，最擅长掩蔽谈话和突发声，但长时间聆听更易疲劳。"
        case .cafe:
            "没有可辨认人声的轻微环境起伏，适合创意发散，不推荐背诵和写作。"
        }
    }

    var audioResource: (name: String, extension: String) {
        switch self {
        case .pinkNoise: ("pink-noise", "wav")
        case .rainOnLeaves: ("rain-on-leaves", "mp3")
        case .brownNoise: ("brown-noise", "wav")
        case .campfire: ("campfire", "mp3")
        case .ocean: ("ocean", "mp3")
        case .forestStream: ("stream", "mp3")
        case .whiteNoise: ("white-noise", "wav")
        case .cafe: ("cafe", "mp3")
        }
    }

    // The source recordings have different mastering levels. These gains make
    // switching scenes feel even without modifying the original open audio.
    var playbackGain: Double {
        switch self {
        case .pinkNoise: 0.46
        case .rainOnLeaves: 1.8
        case .brownNoise: 0.26
        case .campfire: 2.8
        case .ocean: 2.0
        case .forestStream: 2.0
        case .whiteNoise: 1.05
        case .cafe: 1.08
        }
    }
}

enum PlantKind: String, Codable, CaseIterable, Identifiable {
    case birch
    case maple
    case cedar
    case jacaranda
    case ginkgo
    case ancientBanyan

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "sprout": self = .birch
        case "fern": self = .maple
        case "pine": self = .cedar
        case "moonTree": self = .ancientBanyan
        default:
            guard let kind = PlantKind(rawValue: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "未知树种：\(value)"
                )
            }
            self = kind
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var name: String {
        switch self {
        case .birch: "晨光白桦"
        case .maple: "青云枫"
        case .cedar: "静雪杉"
        case .jacaranda: "蓝花楹"
        case .ginkgo: "金羽银杏"
        case .ancientBanyan: "星夜古榕"
        }
    }

    var symbol: String {
        switch self {
        case .birch: "tree"
        case .maple: "tree.fill"
        case .cedar: "triangle.fill"
        case .jacaranda: "camera.macro"
        case .ginkgo: "fan.fill"
        case .ancientBanyan: "sparkles"
        }
    }

    var durationLabel: String {
        switch self {
        case .birch: "5–15 分钟"
        case .maple: "20–35 分钟"
        case .cedar: "40–55 分钟"
        case .jacaranda: "60–85 分钟"
        case .ginkgo: "90–115 分钟"
        case .ancientBanyan: "120 分钟"
        }
    }

    var designNote: String {
        switch self {
        case .birch: "双生白干与轻浅嫩叶，适合一次快速清空思绪。"
        case .maple: "舒展的分枝托住层叠青冠，是标准番茄钟的平衡树形。"
        case .cedar: "笔直深色树干与四层针叶，轮廓稳定、安静而坚定。"
        case .jacaranda: "向外生长的枝桠托起紫蓝花云，象征一次完整深度工作。"
        case .ginkgo: "金色扇叶形成向上的冠幅，稀疏但明亮，属于长时专注。"
        case .ancientBanyan: "宽阔树冠、拱形老干、气根与星点，只为两小时专注出现。"
        }
    }
}

struct FocusSessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let durationMinutes: Int
    let completed: Bool
    let earnedDew: Int
    let plant: PlantKind

    init(
        id: UUID = UUID(),
        startedAt: Date,
        durationMinutes: Int,
        completed: Bool,
        earnedDew: Int,
        plant: PlantKind
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.completed = completed
        self.earnedDew = earnedDew
        self.plant = plant
    }
}

struct PersistedActiveSession: Codable {
    let startedAt: Date
    let endsAt: Date
    let durationMinutes: Int
    let allowedApps: [AllowedApp]
    let allowedWebsites: [AllowedWebsite]?

    var hasValidTiming: Bool {
        guard FocusDurationPolicy.validRange.contains(durationMinutes) else { return false }
        let expectedDuration = TimeInterval(durationMinutes * 60)
        let persistedDuration = endsAt.timeIntervalSince(startedAt)
        return persistedDuration > 0 && abs(persistedDuration - expectedDuration) < 1
    }
}

enum RewardEngine {
    static func reward(for minutes: Int) -> Int {
        let normalizedMinutes = FocusDurationPolicy.normalized(minutes)
        let rarityBonus = switch normalizedMinutes {
        case ..<20: 0
        case 20..<40: 5
        case 40..<60: 12
        case 60..<90: 25
        case 90..<120: 45
        default: 70
        }
        return normalizedMinutes * 2 + rarityBonus
    }

    static func plant(for minutes: Int) -> PlantKind {
        switch FocusDurationPolicy.normalized(minutes) {
        case ..<20: .birch
        case 20..<40: .maple
        case 40..<60: .cedar
        case 60..<90: .jacaranda
        case 90..<120: .ginkgo
        default: .ancientBanyan
        }
    }
}
