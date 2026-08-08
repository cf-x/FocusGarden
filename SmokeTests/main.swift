import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError(message)
    }
}

let normalized = AllowedWebsite(input: "https://www.example.com/docs?q=1")
require(normalized?.host == "example.com", "网站主域名规范化失败")
require(normalized?.allows(host: "docs.example.com") == true, "子域名匹配失败")
require(normalized?.allows(host: "badexample.com") == false, "域名边界匹配失败")
require(AllowedWebsite(input: "   ") == nil, "空域名校验失败")
require(AllowedWebsite(input: "exa_mple.com") == nil, "非法域名字符校验失败")
require(AllowedWebsite(input: "example..com") == nil, "空域名标签校验失败")
require(AllowedWebsite(input: "-example.com") == nil, "非法域名标签边界校验失败")

let selectedApp = AllowedApp(
    name: "Notes",
    bundleIdentifier: "com.example.Notes",
    path: "/Applications/Notes.app"
)
let appMatcher = AllowedApplicationMatcher(applications: [selectedApp])
require(
    appMatcher.allows(bundleIdentifier: "com.example.Notes", path: "/Applications/Notes.app"),
    "应用标识和路径完全匹配时应放行"
)
require(
    !appMatcher.allows(bundleIdentifier: "com.example.Notes", path: "/Applications/Fake.app"),
    "相同应用标识不应绕过路径校验"
)
require(
    !appMatcher.allows(bundleIdentifier: "com.example.Fake", path: "/Applications/Notes.app"),
    "相同路径不应绕过应用标识校验"
)

let legacyPlant = try JSONDecoder().decode(PlantKind.self, from: Data("\"sprout\"".utf8))
require(legacyPlant == .birch, "旧版树种迁移失败")
require(RewardEngine.plant(for: 25) == .maple, "25 分钟树种映射失败")
require(RewardEngine.plant(for: 90) == .ginkgo, "90 分钟树种映射失败")
require(RewardEngine.plant(for: 120) == .ancientBanyan, "120 分钟树种映射失败")
require(RewardEngine.reward(for: 25) == 55, "青云枫奖励计算失败")
require(RewardEngine.reward(for: 120) == 310, "星夜古榕奖励计算失败")
require(RewardEngine.reward(for: Int.max) == 310, "损坏时长不应导致奖励计算溢出")
require(FocusDurationPolicy.normalized(-1) == 5, "损坏的过小时长没有被修正")
require(FocusDurationPolicy.normalized(9_999) == 120, "损坏的过大时长没有被修正")

let sessionStart = Date(timeIntervalSince1970: 1_700_000_000)
let validActiveSession = PersistedActiveSession(
    startedAt: sessionStart,
    endsAt: sessionStart.addingTimeInterval(25 * 60),
    durationMinutes: 25,
    allowedApps: [],
    allowedWebsites: []
)
let forgedActiveSession = PersistedActiveSession(
    startedAt: sessionStart,
    endsAt: sessionStart.addingTimeInterval(1),
    durationMinutes: 120,
    allowedApps: [],
    allowedWebsites: []
)
require(validActiveSession.hasValidTiming, "合法的活动会话校验失败")
require(!forgedActiveSession.hasValidTiming, "伪造的活动会话不应获得完成奖励")

let profile = FocusProfile(name: "编程", allowedWebsites: [normalized!])
let profileRoundTrip = try JSONDecoder().decode(
    FocusProfile.self,
    from: JSONEncoder().encode(profile)
)
require(profileRoundTrip.name == "编程", "专注模式序列化失败")
require(profileRoundTrip.allowedWebsites.first?.host == "example.com", "专注模式白名单保存失败")

require(AmbientSound.allCases.count == 8, "背景音场景数量错误")
require(Set(AmbientSound.allCases.map { $0.audioResource.name }).count == 8, "背景音资源名必须唯一")
require(AmbientSound.allCases.allSatisfy { $0.playbackGain > 0 }, "背景音响度平衡参数无效")
require(AmbientSound(rawValue: "rain") == .rainOnLeaves, "旧版细雨场景迁移失败")
require(AmbientSound(rawValue: "stream") == .campfire, "旧版溪流场景迁移失败")
require(AmbientSound(rawValue: "forest") == .forestStream, "旧版林间微风场景迁移失败")
require(AmbientSound.rainOnLeaves.audioResource.name == "rain-on-leaves", "叶上细雨资源配置错误")
require(AmbientSound.campfire.audioResource.name == "campfire", "林间篝火资源配置错误")
require(AmbientSound.forestStream.audioResource.name == "stream", "林间溪流资源配置错误")
for sound in AmbientSound.allCases {
    let resource = sound.audioResource
    require(
        FileManager.default.fileExists(
            atPath: "Resources/AmbientSounds/\(resource.name).\(resource.extension)"
        ),
        "缺少背景音资源：\(resource.name).\(resource.extension)"
    )
}

print("PASS: 域名、应用身份、会话完整性、专注模式、树种、奖励与背景音配置")
