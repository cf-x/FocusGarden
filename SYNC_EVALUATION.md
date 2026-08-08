# Mac 与 iPhone 同步控制评估

## 结论

**值得做，但不应该抢在 Mac 单机版稳定之前。**

如果用户工作时会把 iPhone 放在身边，仅限制 Mac 会留下最大的分心入口；此时“Mac 开始专注，iPhone 同步进入允许名单”有明显价值。反过来，如果手机通常放在别处，仅同步花园、记录和白名单属于体验增强，并非核心闭环。

建议分三阶段实施：

1. 先同步白名单、树木、露珠和历史记录。
2. 再开发 iPhone 本地专注与屏幕限制。
3. 最后才做跨设备同时开始、暂停和结束。

## 难度拆分

| 能力 | 难度 | 粗略工作量 | 主要问题 |
|---|---:|---:|---|
| 花园、历史、白名单同步 | 2.5 / 5 | 3–7 天 | 迁移到 SwiftData/Core Data，处理 CloudKit 延迟和冲突 |
| iPhone 伴侣应用与本地计时 | 3 / 5 | 1–2 周 | 新建 iOS UI、共享模型、通知和本地状态恢复 |
| iPhone 应用/网站白名单 | 4 / 5 | 2–4 周以上 | Family Controls、Managed Settings、Device Activity 扩展和授权流程 |
| Mac 与 iPhone 实时联动 | 4.5 / 5 | 3–6 周以上 | 推送不保证实时或必达、离线冲突、重复结算、设备确认 |

这些是单人开发的工程估算，不包含 App Store 审核等待时间。

## 推荐架构

### 数据同步

使用 SwiftData + CloudKit 私有数据库保存：

- 专注模式与白名单
- 树木和露珠
- 历史记录
- 当前会话的开始时间、结束时间和创建设备

Apple 的 SwiftData CloudKit 同步需要 iCloud 与 Remote notifications 能力，也需要有效的 Apple Developer 账户。CloudKit 适合用户本人多设备数据，但变化按系统节奏传播，不能当成严格实时信道。[Apple：Syncing model data across a person’s devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)

### 会话联动

不要让设备依赖一条“25 分钟后结束”的远程消息。正确方式是：

1. 发出包含绝对 `startedAt` 和 `endsAt` 的会话记录。
2. 每台设备收到后立即创建自己的本地计时和本地结束通知。
3. CloudKit/APNs 只负责同步开始或取消事件。
4. 每台设备写回确认状态；奖励由会话 ID 去重结算。

Apple 明确说明后台推送可能延迟、被节流或不投递，因此不能把它作为严格同步控制的唯一依据。[Apple：Pushing background updates to your app](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)

### iPhone 屏幕限制

iPhone 端应使用 Family Controls + Managed Settings + Device Activity，而不是尝试强制结束其他应用。Family Controls 需要用户明确授权；分发时还要向 Apple 申请对应 entitlement，涉及 Device Activity Monitor、Shield Action 等扩展时，每个扩展也要申请。[Apple：Configuring Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls)、[Apple：Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)

## 必要程度

- **同步花园和白名单：高性价比。** 它让产品从单机工具变成长期习惯系统，建议做。
- **iPhone 本地白名单：如果手机是主要分心来源，必要程度高。** 否则可后置。
- **严格实时双向遥控：必要程度中低。** 技术成本最高，且系统后台限制使“百分之百同时”不现实。
- **推荐的 MVP：** Mac 创建会话后，iPhone 在数秒到约一分钟内收到并进入自己的本地专注；离线时两端各自可靠结束，恢复网络后合并记录。
