import AppKit
import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case focus = "专注"
    case sounds = "背景音"
    case garden = "花园"
    case history = "记录"
    case settings = "设置"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .focus: "timer"
        case .sounds: "speaker.wave.2.fill"
        case .garden: "leaf.fill"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        }
    }
}

private struct PressFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var section: AppSection = .focus
    @State private var showingAbandonAlert = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.045, green: 0.10, blue: 0.09), Color(red: 0.075, green: 0.16, blue: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                Group {
                    switch section {
                    case .focus:
                        FocusView(showingAbandonAlert: $showingAbandonAlert)
                    case .sounds:
                        BackgroundSoundView()
                    case .garden:
                        GardenView()
                    case .history:
                        HistoryView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if CommandLine.arguments.contains("--background-completion") {
                DispatchQueue.main.async {
                    for window in NSApplication.shared.windows where window.canBecomeMain {
                        window.orderOut(nil)
                    }
                }
            }
        }
        .alert("要结束这轮专注吗？", isPresented: $showingAbandonAlert) {
            Button("继续专注", role: .cancel) {}
            Button("放弃，本轮不获得露珠", role: .destructive) {
                state.abandonSession()
            }
        } message: {
            Text("已经成长的植物会枯萎，但历史中会保留这次尝试。")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.mint.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.mint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("森时")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("Focus Garden")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            VStack(spacing: 8) {
                ForEach(AppSection.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .frame(width: 20)
                            Text(item.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 13)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(section == item ? Color.white.opacity(0.1) : .clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(PressFeedbackButtonStyle())
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(section == item ? .white : .white.opacity(0.55))
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Label("\(state.dewBalance) 露珠", systemImage: "drop.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.cyan.opacity(0.9))
                Text("每一分钟，都在让花园生长。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 210)
        .background(Color.black.opacity(0.16))
    }
}

private struct BackgroundSoundView: View {
    @EnvironmentObject private var state: AppState

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("背景音")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("让声音遮住干扰，而不是抢走注意力。")
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    if state.isAmbientSoundPlaying {
                        Label("正在播放", systemImage: "waveform")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.mint)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.mint.opacity(0.12), in: Capsule())
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    nowPlayingCard
                    listeningGuide
                }

                HStack {
                    Text("选择一个声音场景")
                        .font(.headline)
                    Spacer()
                    Text("点击卡片切换，播放时立即生效")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AmbientSound.allCases) { sound in
                        AmbientSoundCard(
                            sound: sound,
                            isSelected: sound == state.selectedAmbientSound
                        ) {
                            state.selectAmbientSound(sound)
                        }
                    }
                }

                Label(
                    "森时只控制自身响度，无法判断耳机实际分贝。长时间使用时建议系统音量不超过 60%，每小时让耳朵安静休息一会儿。",
                    systemImage: "ear.badge.checkmark"
                )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.38))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            }
            .padding(32)
        }
    }

    private var nowPlayingCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(ambientAccent.opacity(0.14))
                        .frame(width: 92, height: 92)
                    Circle()
                        .stroke(ambientAccent.opacity(state.isAmbientSoundPlaying ? 0.28 : 0.12), lineWidth: 1)
                        .frame(width: 72, height: 72)
                    if state.isAmbientSoundPlaying {
                        AmbientWaveform(color: ambientAccent)
                            .frame(width: 44, height: 32)
                    } else {
                        Image(systemName: state.selectedAmbientSound.symbol)
                            .font(.system(size: 29, weight: .medium))
                            .foregroundStyle(ambientAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(state.selectedAmbientSound.name)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(state.selectedAmbientSound.bestFor)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ambientAccent)
                    Text(state.selectedAmbientSound.spectrum)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }
                Spacer()
                Button {
                    state.toggleAmbientSound()
                } label: {
                    Image(systemName: state.isAmbientSoundPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 52, height: 52)
                        .background(ambientAccent, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressFeedbackButtonStyle())
                .foregroundStyle(Color(red: 0.035, green: 0.12, blue: 0.10))
            }

            VStack(spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                    Slider(
                        value: Binding(
                            get: { state.ambientSoundVolume },
                            set: { state.setAmbientSoundVolume($0) }
                        ),
                        in: 0...0.60
                    )
                    .tint(ambientAccent)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                    Text("\(Int((state.ambientSoundVolume / 0.60) * 100))%")
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(width: 34, alignment: .trailing)
                }

                Toggle(
                    "随专注自动播放与停止",
                    isOn: Binding(
                        get: { state.ambientSoundAutoPlay },
                        set: { state.setAmbientSoundAutoPlay($0) }
                    )
                )
                .font(.system(size: 13, weight: .medium))
                .toggleStyle(.switch)
                .tint(.mint)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(ambientAccent.opacity(0.15), lineWidth: 1)
        )
    }

    private var listeningGuide: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("怎么选", systemImage: "sparkles")
                .font(.headline)
            ListeningGuideRow(
                symbol: "chevron.left.forwardslash.chevron.right",
                title: "深度工作",
                detail: "先选粉噪声或细雨"
            )
            ListeningGuideRow(
                symbol: "person.wave.2.fill",
                title: "周围有人说话",
                detail: "白噪声遮蔽更强，音量要低"
            )
            ListeningGuideRow(
                symbol: "lightbulb.fill",
                title: "构思与发散",
                detail: "试试海浪或远处咖啡馆"
            )
            Spacer(minLength: 0)
            Text("没有一种声音对所有人都更专注；如果开始留意声音本身，静音通常更好。")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 255)
        .frame(minHeight: 220, alignment: .topLeading)
        .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var ambientAccent: Color {
        soundAccentColor(for: state.selectedAmbientSound)
    }
}

private struct AmbientSoundCard: View {
    let sound: AmbientSound
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: sound.symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(soundAccentColor(for: sound))
                    .frame(width: 42, height: 42)
                    .background(soundAccentColor(for: sound).opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(sound.name)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.mint)
                        }
                    }
                    Text(sound.bestFor)
                        .font(.caption2)
                        .foregroundStyle(soundAccentColor(for: sound).opacity(0.9))
                    Text(sound.detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.37))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(sound.spectrum)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.top, 2)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(
                isSelected ? soundAccentColor(for: sound).opacity(0.09) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(isSelected ? soundAccentColor(for: sound).opacity(0.32) : Color.white.opacity(0.055), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .foregroundStyle(.white)
    }
}

private struct ListeningGuideRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.mint)
                .frame(width: 28, height: 28)
                .background(Color.mint.opacity(0.09), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

private struct AmbientWaveform: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    let height = 10 + abs(sin(time * 2.4 + Double(index) * 0.82)) * 22
                    Capsule()
                        .fill(color)
                        .frame(width: 4, height: height)
                }
            }
        }
    }
}

private func soundAccentColor(for sound: AmbientSound) -> Color {
    switch sound {
    case .pinkNoise: Color(red: 0.96, green: 0.55, blue: 0.69)
    case .rainOnLeaves: Color(red: 0.42, green: 0.80, blue: 0.62)
    case .brownNoise: Color(red: 0.76, green: 0.57, blue: 0.38)
    case .campfire: Color(red: 0.96, green: 0.54, blue: 0.28)
    case .ocean: Color(red: 0.42, green: 0.59, blue: 0.94)
    case .forestStream: Color(red: 0.34, green: 0.86, blue: 0.83)
    case .whiteNoise: Color(red: 0.82, green: 0.87, blue: 0.90)
    case .cafe: Color(red: 0.91, green: 0.67, blue: 0.42)
    }
}

private struct FocusView: View {
    @EnvironmentObject private var state: AppState
    @Binding var showingAbandonAlert: Bool
    @State private var websiteInput = ""
    @State private var showingNewProfileAlert = false
    @State private var newProfileName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.isSessionActive ? "保持在这片安静里" : "种下一段专注")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text(state.isSessionActive ? "白名单之外的应用与网页会被立即拦截" : "选择时长、应用和网站，然后开始")
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    if state.isSessionActive {
                        Label("守护中", systemImage: "shield.lefthalf.filled")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.mint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.mint.opacity(0.12), in: Capsule())
                    }
                }

                HStack(alignment: .top, spacing: 22) {
                    timerCard
                    settingsCard
                }
                .frame(minHeight: 450)
            }
            .padding(32)
        }
        .alert("新建专注模式", isPresented: $showingNewProfileAlert) {
            TextField("例如：写作", text: $newProfileName)
            Button("新建空白模式") {
                if state.createProfile(named: newProfileName) {
                    newProfileName = ""
                }
            }
            Button("复制当前模式") {
                if state.createProfile(named: newProfileName, copyingCurrent: true) {
                    newProfileName = ""
                }
            }
            Button("取消", role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text("每个模式保存独立的应用和网页白名单。")
        }
    }

    private var timerCard: some View {
        VStack(spacing: 19) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: state.timerRingProgress)
                    .stroke(
                        AngularGradient(colors: [.mint, .teal, .cyan, .mint], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: state.timerRingProgress)

                VStack(spacing: 10) {
                    TreeArtwork(
                        kind: state.projectedPlant,
                        growth: state.isSessionActive ? state.progress : 1
                    )
                    .frame(width: 118, height: 100)
                    Text(state.formattedRemaining)
                        .font(.system(size: 43, weight: .medium, design: .rounded).monospacedDigit())
                    Text(state.projectedPlant.name)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(width: 270, height: 270)

            if let blockedHost = state.blocker.lastBlockedWebsiteHost, state.isSessionActive {
                Label("已拦截 \(blockedHost)", systemImage: "network.slash")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
                    .transition(.opacity)
            } else if let blocked = state.blocker.lastBlockedAppName, state.isSessionActive {
                Label("已请 \(blocked) 暂时离开", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
                    .transition(.opacity)
            } else {
                Label("完成可获得 \(state.projectedReward) 露珠", systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan.opacity(0.75))
            }

            if state.isSessionActive {
                Button {
                    showingAbandonAlert = true
                } label: {
                    Text("结束本轮")
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressFeedbackButtonStyle())
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 3)
            } else {
                Button {
                    state.startSession()
                } label: {
                    Label("开始专注", systemImage: "play.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(colors: [.mint, Color(red: 0.35, green: 0.88, blue: 0.70)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 15)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(PressFeedbackButtonStyle())
                .foregroundStyle(Color(red: 0.03, green: 0.13, blue: 0.10))
                .padding(.horizontal, 28)
            }
            Spacer(minLength: 6)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Label("专注模式", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(state.profiles) { profile in
                        Button {
                            state.selectProfile(profile.id)
                        } label: {
                            if profile.id == state.selectedProfileID {
                                Label(profile.name, systemImage: "checkmark")
                            } else {
                                Text(profile.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(state.selectedProfileName)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(state.isSessionActive)

                Button {
                    showingNewProfileAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.mint.opacity(0.14), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressFeedbackButtonStyle())
                .foregroundStyle(.mint)
                .disabled(state.isSessionActive)
            }

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 14) {
                Label("专注时长", systemImage: "hourglass")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach([25, 50, 90], id: \.self) { minutes in
                        Button {
                            state.setDuration(minutes)
                        } label: {
                            Text("\(minutes) 分钟")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 11)
                                .frame(minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(state.selectedDuration == minutes ? Color.mint.opacity(0.22) : Color.white.opacity(0.06))
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(PressFeedbackButtonStyle())
                        .foregroundStyle(state.selectedDuration == minutes ? .mint : .white.opacity(0.58))
                        .disabled(state.isSessionActive)
                    }
                }

                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(state.selectedDuration) },
                            set: { state.setDuration(Int($0.rounded())) }
                        ),
                        in: 5...120,
                        step: 5
                    )
                    .tint(.mint)
                    .disabled(state.isSessionActive)
                    Text("\(state.isSessionActive ? state.currentDurationMinutes : state.selectedDuration) min")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 58, alignment: .trailing)
                }

                HStack(spacing: 10) {
                    TreeArtwork(kind: state.projectedPlant)
                        .frame(width: 54, height: 58)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.projectedPlant.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.projectedPlant.designNote)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.38))
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("应用白名单", systemImage: "checkmark.shield")
                            .font(.headline)
                        Text("计时期间仅保留这些应用")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    Spacer()
                    Button {
                        state.chooseApplications()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressFeedbackButtonStyle())
                    .disabled(state.isSessionActive)
                }

                if state.allowedApps.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 25))
                            .foregroundStyle(.white.opacity(0.28))
                        Text("还没有添加应用")
                            .font(.subheadline)
                        Text("开始后只保留森时、Finder 和必要系统界面")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(state.allowedApps) { app in
                                AllowedAppRow(app: app)
                            }
                        }
                    }
                    .frame(maxHeight: 112)
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("网页白名单", systemImage: "globe.badge.chevron.backward")
                        .font(.headline)
                    Text("先将浏览器加入应用白名单；域名自动包含所有子域名")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                }

                HStack(spacing: 8) {
                    TextField("例如 notion.so", text: $websiteInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        .disabled(state.isSessionActive)
                        .onSubmit(addWebsite)
                    Button(action: addWebsite) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressFeedbackButtonStyle())
                    .foregroundStyle(.mint)
                    .disabled(state.isSessionActive)
                }

                if let error = state.websiteInputError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if state.allowedWebsites.isEmpty {
                    Text("未添加网站时，浏览器只能停留在空白页和内部页面。")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(state.allowedWebsites) { website in
                                AllowedWebsiteRow(website: website)
                            }
                        }
                    }
                    .frame(maxHeight: 108)
                }

                if let issue = state.blocker.websiteControlIssue, state.isSessionActive {
                    Label(issue, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.9))
                }
            }

            Label("网页守护支持 Safari、Chrome、Edge、Arc、Brave 与 Opera；首次使用需允许浏览器自动化。", systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.32))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 365)
        .background(cardBackground)
    }

    private func addWebsite() {
        if state.addWebsite(websiteInput) {
            websiteInput = ""
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}

private struct AllowedAppRow: View {
    @EnvironmentObject private var state: AppState
    let app: AllowedApp

    var body: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(app.bundleIdentifier ?? "本地应用")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                state.removeAllowedApp(app)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressFeedbackButtonStyle())
            .disabled(state.isSessionActive)
        }
        .padding(.horizontal, 11)
        .frame(height: 48)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct AllowedWebsiteRow: View {
    @EnvironmentObject private var state: AppState
    let website: AllowedWebsite

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "globe")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.cyan.opacity(0.75))
                .frame(width: 26, height: 26)
                .background(Color.cyan.opacity(0.08), in: Circle())
            Text(website.host)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer()
            Button {
                state.removeAllowedWebsite(website)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressFeedbackButtonStyle())
            .disabled(state.isSessionActive)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct GardenView: View {
    @EnvironmentObject private var state: AppState

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("我的花园")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("每棵植物，都是一段没有被打断的时间。")
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        Metric(value: "\(state.completedSessions.count)", label: "植物")
                        Metric(value: "\(state.totalFocusedMinutes)", label: "分钟")
                        Metric(value: "\(state.dewBalance)", label: "露珠")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForestSceneView(sessions: state.completedSessions)
                    Label(
                        "每周一开启一片新森林；往期树木仍保留在下方“已经种下”和历史记录中。",
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.38))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("专注树谱")
                            .font(.headline)
                        Spacer()
                        Text("时长越长，树形越稀有")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.36))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PlantKind.allCases) { kind in
                                TreeCatalogCard(kind: kind)
                            }
                        }
                    }
                }

                Text("已经种下")
                    .font(.headline)

                if state.completedSessions.isEmpty {
                    VStack(spacing: 15) {
                        TreeArtwork(kind: .birch, growth: 0.35)
                            .frame(width: 90, height: 100)
                        Text("花园还在等待第一棵植物")
                            .font(.headline)
                        Text("完成一轮专注，它就会在这里扎根。")
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24))
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(state.completedSessions) { session in
                            PlantTile(session: session)
                        }
                    }
                }
            }
            .padding(32)
        }
    }
}

private struct ForestSceneView: View {
    let sessions: [FocusSessionRecord]

    private let positions: [(CGFloat, CGFloat)] = [
        (0.14, 0.62), (0.30, 0.68), (0.46, 0.61), (0.63, 0.69), (0.82, 0.61),
        (0.22, 0.82), (0.40, 0.84), (0.58, 0.80), (0.76, 0.84), (0.91, 0.78),
        (0.07, 0.82), (0.51, 0.75)
    ]

    private var weekInterval: DateInterval {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Calendar.current.startOfDay(for: Date()), duration: 7 * 24 * 60 * 60)
    }

    private var weeklySessions: [FocusSessionRecord] {
        sessions.filter { weekInterval.contains($0.startedAt) }
    }

    private var weeklyMinutes: Int {
        weeklySessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日"
        let inclusiveEnd = weekInterval.end.addingTimeInterval(-1)
        return "\(formatter.string(from: weekInterval.start))–\(formatter.string(from: inclusiveEnd))"
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.035, green: 0.17, blue: 0.16),
                                Color(red: 0.08, green: 0.31, blue: 0.23)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color(red: 0.74, green: 0.96, blue: 0.75).opacity(0.7))
                    .frame(width: 62, height: 62)
                    .blur(radius: 1)
                    .position(x: size.width * 0.84, y: size.height * 0.20)

                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.35 + Double(index % 2) * 0.2))
                        .frame(width: index.isMultiple(of: 3) ? 4 : 2, height: index.isMultiple(of: 3) ? 4 : 2)
                        .position(
                            x: size.width * [0.12, 0.23, 0.39, 0.55, 0.68, 0.77, 0.93][index],
                            y: size.height * [0.20, 0.31, 0.16, 0.28, 0.13, 0.34, 0.24][index]
                        )
                }

                ForestHill(curveHeight: 0.42)
                    .fill(Color(red: 0.07, green: 0.26, blue: 0.19).opacity(0.88))
                    .padding(.top, size.height * 0.27)
                ForestHill(curveHeight: 0.30)
                    .fill(Color(red: 0.08, green: 0.35, blue: 0.22))
                    .padding(.top, size.height * 0.40)

                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.70, y: size.height * 0.57))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.59, y: size.height),
                        control1: CGPoint(x: size.width * 0.61, y: size.height * 0.69),
                        control2: CGPoint(x: size.width * 0.72, y: size.height * 0.83)
                    )
                }
                .stroke(Color.cyan.opacity(0.18), style: StrokeStyle(lineWidth: 26, lineCap: .round))

                ForEach(Array(weeklySessions.enumerated()), id: \.element.id) { index, session in
                    let position = treePosition(at: index, count: weeklySessions.count)
                    let isFront = position.1 > 0.72
                    let densityScale = treeScale(for: weeklySessions.count)
                    TreeArtwork(kind: session.plant)
                        .frame(
                            width: (isFront ? 92 : 72) * densityScale,
                            height: (isFront ? 105 : 82) * densityScale
                        )
                        .shadow(color: Color.black.opacity(0.16), radius: 6, y: 4)
                        .position(x: size.width * position.0, y: size.height * position.1)
                }

                if weeklySessions.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.mint.opacity(0.7))
                        Text("完成本周第一轮专注，种下第一棵树")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                VStack {
                    HStack {
                        Label("本周森林", systemImage: "tree.fill")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("\(weekRangeText) · \(weeklySessions.count) 棵 · \(weeklyMinutes) 分钟")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .frame(height: 310)
    }

    private func treePosition(at index: Int, count: Int) -> (CGFloat, CGFloat) {
        guard count > positions.count else { return positions[index] }

        let columns = min(10, max(5, Int(ceil(sqrt(Double(count) * 1.7)))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let column = index % columns
        let row = index / columns
        let xStep = columns == 1 ? 0 : 0.84 / CGFloat(columns - 1)
        let yStep = rows == 1 ? 0 : 0.29 / CGFloat(rows - 1)
        let stagger = row.isMultiple(of: 2) ? 0 : min(0.025, xStep / 3)
        let x = min(0.94, 0.07 + CGFloat(column) * xStep + stagger)
        let y = rows == 1 ? 0.68 : 0.57 + CGFloat(row) * yStep
        return (x, y)
    }

    private func treeScale(for count: Int) -> CGFloat {
        guard count > positions.count else { return 1 }
        return max(0.42, min(0.82, sqrt(12 / CGFloat(count))))
    }
}

private struct ForestHill: Shape {
    let curveHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * curveHeight))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * (curveHeight + 0.04)),
            control1: CGPoint(x: rect.width * 0.23, y: rect.maxY * (curveHeight - 0.18)),
            control2: CGPoint(x: rect.width * 0.72, y: rect.maxY * (curveHeight + 0.17))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TreeCatalogCard: View {
    let kind: PlantKind

    var body: some View {
        VStack(spacing: 8) {
            TreeArtwork(kind: kind)
                .frame(width: 92, height: 98)
            Text(kind.name)
                .font(.system(size: 13, weight: .semibold))
            Text(kind.durationLabel)
                .font(.caption2)
                .foregroundStyle(.mint.opacity(0.8))
            Text(kind.designNote)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 24)
        }
        .padding(13)
        .frame(width: 154, height: 190)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 17))
        .overlay(
            RoundedRectangle(cornerRadius: 17)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

private struct PlantTile: View {
    let session: FocusSessionRecord

    var body: some View {
        VStack(spacing: 12) {
            TreeArtwork(kind: session.plant)
                .frame(width: 88, height: 92)
            Text(session.plant.name)
                .font(.system(size: 14, weight: .semibold))
            Text("\(session.durationMinutes) 分钟 · +\(session.earnedDew) ◉")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
            Text(session.startedAt, format: .dateTime.month().day())
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 196)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("专注记录")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("完成和中断都值得被诚实地看见。")
                        .foregroundStyle(.white.opacity(0.48))
                }

                if state.history.isEmpty {
                    Text("还没有记录")
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, minHeight: 350)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(state.history) { session in
                            HStack(spacing: 14) {
                                Group {
                                    if session.completed {
                                        TreeArtwork(kind: session.plant)
                                    } else {
                                        Image(systemName: "leaf.arrow.triangle.circlepath")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.orange.opacity(0.65))
                                    }
                                }
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.05), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.completed ? "完成 · \(session.plant.name)" : "提前结束")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(session.startedAt, format: .dateTime.year().month().day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.34))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(session.durationMinutes) 分钟")
                                    Text(session.completed ? "+\(session.earnedDew) 露珠" : "无奖励")
                                        .foregroundStyle(session.completed ? .cyan.opacity(0.75) : .white.opacity(0.3))
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 70)
                            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                        }
                    }
                }
            }
            .padding(32)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingCreateProfile = false
    @State private var editingProfileID: UUID?
    @State private var profileName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("让森时安静地待在后台，只在你需要时出现。")
                        .foregroundStyle(.white.opacity(0.48))
                }

                SystemSettingsSection(integration: state.systemIntegration)

                settingsCard(title: "菜单栏、提醒与快捷键", symbol: "menubar.rectangle") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: "在菜单栏显示剩余时间",
                            detail: "专注时在叶子旁实时显示倒计时，例如 24:59。",
                            isOn: Binding(
                                get: { state.showRemainingTimeInMenuBar },
                                set: { state.setShowRemainingTimeInMenuBar($0) }
                            )
                        )
                        Divider().overlay(Color.white.opacity(0.07))
                        SettingsToggleRow(
                            title: "完成时显示系统通知",
                            detail: "只显示右上角横幅，不播放声音。",
                            isOn: Binding(
                                get: { state.notificationEnabled },
                                set: { state.setNotificationEnabled($0) }
                            )
                        )
                        Divider().overlay(Color.white.opacity(0.07))
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("快速唤醒森时")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("在其他应用中也可以使用；守护助手启用时可重新打开主应用。")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                KeyCap("⌘")
                                KeyCap("⇧")
                                KeyCap("F")
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }

                settingsCard(title: "专注模式", symbol: "slider.horizontal.3") {
                    VStack(spacing: 10) {
                        ForEach(state.profiles) { profile in
                            HStack(spacing: 12) {
                                Image(systemName: profile.id == state.selectedProfileID ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(profile.id == state.selectedProfileID ? .mint : .white.opacity(0.28))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("\(profile.allowedApps.count) 个应用 · \(profile.allowedWebsites.count) 个网站")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.36))
                                }
                                Spacer()
                                Button {
                                    state.selectProfile(profile.id)
                                } label: {
                                    Text("使用")
                                        .font(.caption)
                                        .padding(.horizontal, 9)
                                        .frame(minHeight: 32)
                                        .background(Color.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                        .contentShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(PressFeedbackButtonStyle())
                                .foregroundStyle(.mint)
                                .opacity(profile.id == state.selectedProfileID ? 0 : 1)
                                .disabled(profile.id == state.selectedProfileID || state.isSessionActive)
                                Button {
                                    profileName = profile.name
                                    editingProfileID = profile.id
                                } label: {
                                    Image(systemName: "pencil")
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PressFeedbackButtonStyle())
                                .foregroundStyle(.white.opacity(0.45))
                                .disabled(state.isSessionActive)
                                Button {
                                    state.deleteProfile(profile.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PressFeedbackButtonStyle())
                                .foregroundStyle(.white.opacity(0.32))
                                .disabled(state.profiles.count == 1 || state.isSessionActive)
                            }
                            .padding(.horizontal, 13)
                            .frame(height: 62)
                            .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            profileName = ""
                            showingCreateProfile = true
                        } label: {
                            Label("新建专注模式", systemImage: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                                .contentShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(PressFeedbackButtonStyle())
                        .foregroundStyle(.mint)
                        .disabled(state.isSessionActive)
                    }
                }
            }
            .padding(32)
        }
        .alert("新建专注模式", isPresented: $showingCreateProfile) {
            TextField("例如：编程", text: $profileName)
            Button("新建空白模式") {
                _ = state.createProfile(named: profileName)
                profileName = ""
            }
            Button("复制当前模式") {
                _ = state.createProfile(named: profileName, copyingCurrent: true)
                profileName = ""
            }
            Button("取消", role: .cancel) {}
        }
        .alert("重命名专注模式", isPresented: Binding(
            get: { editingProfileID != nil },
            set: { if !$0 { editingProfileID = nil } }
        )) {
            TextField("模式名称", text: $profileName)
            Button("保存") {
                if let editingProfileID {
                    state.renameProfile(editingProfileID, to: profileName)
                }
                editingProfileID = nil
                profileName = ""
            }
            Button("取消", role: .cancel) {
                editingProfileID = nil
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content()
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SystemSettingsSection: View {
    @ObservedObject var integration: SystemIntegrationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("系统集成", systemImage: "macwindow.badge.plus")
                .font(.headline)

            SettingsToggleRow(
                title: "登录时启动",
                detail: "登录 Mac 后自动启动森时，并保持菜单栏入口。",
                isOn: Binding(
                    get: { integration.launchAtLoginEnabled },
                    set: { integration.setLaunchAtLogin($0) }
                )
            )
            Divider().overlay(Color.white.opacity(0.07))
            SettingsToggleRow(
                title: "后台守护助手",
                detail: "主应用退出后，继续执行正在进行的白名单并接管 ⌘⇧F。",
                isOn: Binding(
                    get: { integration.guardianEnabled },
                    set: { integration.setGuardianEnabled($0) }
                )
            )

            if let message = integration.statusMessage {
                HStack {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button {
                        integration.openLoginItemSettings()
                    } label: {
                        Text("打开系统设置")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .background(Color.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressFeedbackButtonStyle())
                    .foregroundStyle(.mint)
                }
            }

            Text("建议先把森时.app 移到“应用程序”文件夹，再启用登录项与守护助手。")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            integration.refresh()
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .tint(.mint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct KeyCap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minWidth: 26, minHeight: 25)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: state.isSessionActive ? "leaf.fill" : "leaf")
                .font(.system(size: 28))
                .foregroundStyle(.mint)
            Text(state.isSessionActive ? state.formattedRemaining : "准备种下一段专注")
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
            Text(state.isSessionActive ? "应用与网页白名单守护中" : "打开主窗口来配置白名单")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("显示森时") {
                    AppActivation.showMainWindow()
                }
                Spacer()
                if state.isSessionActive {
                    Text("已拦截 \(state.blocker.blockedCount + state.blocker.blockedWebsiteCount) 次")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 270)
    }
}
