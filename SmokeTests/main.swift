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

let legacyPlant = try JSONDecoder().decode(PlantKind.self, from: Data("\"sprout\"".utf8))
require(legacyPlant == .birch, "旧版树种迁移失败")
require(RewardEngine.plant(for: 25) == .maple, "25 分钟树种映射失败")
require(RewardEngine.plant(for: 90) == .ginkgo, "90 分钟树种映射失败")
require(RewardEngine.plant(for: 120) == .ancientBanyan, "120 分钟树种映射失败")
require(RewardEngine.reward(for: 25) == 55, "青云枫奖励计算失败")
require(RewardEngine.reward(for: 120) == 310, "星夜古榕奖励计算失败")

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

print("PASS: 域名、专注模式、树种迁移、时长映射、奖励规则与背景音配置")
