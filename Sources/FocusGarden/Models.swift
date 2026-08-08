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
        guard !normalized.isEmpty else { return nil }

        self.host = normalized
        self.id = normalized
    }

    func allows(host candidate: String) -> Bool {
        let normalized = candidate.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return normalized == host || normalized.hasSuffix(".\(host)")
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
}

enum RewardEngine {
    static func reward(for minutes: Int) -> Int {
        let rarityBonus = switch minutes {
        case ..<20: 0
        case 20..<40: 5
        case 40..<60: 12
        case 60..<90: 25
        case 90..<120: 45
        default: 70
        }
        return max(5, minutes * 2 + rarityBonus)
    }

    static func plant(for minutes: Int) -> PlantKind {
        switch minutes {
        case ..<20: .birch
        case 20..<40: .maple
        case 40..<60: .cedar
        case 60..<90: .jacaranda
        case 90..<120: .ginkgo
        default: .ancientBanyan
        }
    }
}
