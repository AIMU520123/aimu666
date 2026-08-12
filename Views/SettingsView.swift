import SwiftUI

/// 设置页
///
/// 管理App全局设置，包括：
/// - 用户画像编辑（名称、简介、偏好风格）
/// - 外观设置（主题、语言）
/// - 数据管理（清除记忆、查看数据大小）
/// - 隐私声明链接
/// - 关于信息
///
/// 设计意图：
/// - 简洁分类设置，避免过于复杂的选项层级
/// - 隐私/数据相关设置放在显眼位置
/// - 付费信息清晰标注（$39.99买断）
/// - 数据清除操作有二次确认
struct SettingsView: View {
    @Binding var userProfile: UserProfile

    @State private var showingResetConfirmation = false
    @State private var showingPrivacyStatement = false
    @State private var isResettingData = false
    @State private var showPaywall = false

    @Bindable var defaults = UserDefaultsManager.shared
    private let db = DatabaseManager.shared
    private let privacyService = PrivacyService.shared
    private let store = StoreManager.shared

    var body: some View {
        NavigationStack {
            List {
                profileSection
                interfaceStyleSection
                appearanceSection
                dailyReflectionSection
                dataPrivacySection
                purchaseSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPrivacyStatement) {
                PrivacyStatementView()
            }
            .confirmationDialog(
                "Clear All Memory?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) {
                    Task { await resetAllData() }
                }
                Button("Clear Conversations Only") {
                    Task { await clearConversationsOnly() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("""
                    Clearing memory will delete your conversations and reset Yi's memory of you. \
                    Your hexagram collection can be preserved.

                    This action cannot be undone.
                    """)
            }
            .onChange(of: userProfile.displayName) { _, _ in
                saveProfile()
            }
            .onChange(of: userProfile.bio) { _, _ in
                saveProfile()
            }
            .onChange(of: userProfile.castingStyle) { _, _ in
                saveProfile()
            }
            .onChange(of: defaults.dailyReflectionReminder) { _, _ in
                Task { await ReminderManager.shared.refreshReminderFromPreferences() }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(Color("YiInk"))

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your Name", text: $userProfile.displayName)
                        .font(.headline)
                    Text("Collection: \(userProfile.unlockedHexagramIDs.count)/64 hexagrams")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            TextField("A short bio...", text: $userProfile.bio, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)

            Picker("Casting Style", selection: $userProfile.castingStyle) {
                ForEach(CastingStyle.allCases, id: \.self) { style in
                    Text(style.description).tag(style)
                }
            }
        } header: {
            Text("Profile")
        }
    }

    private var interfaceStyleSection: some View {
        Section {
            VStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    themeCard(theme)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Interface Style")
        } footer: {
            Text("Choose the visual world that feels most like home. Switch any time — your reflections stay the same.")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Color Theme", selection: $defaults.colorTheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }

            Picker("Language", selection: $userProfile.preferredLanguage) {
                ForEach(Language.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .footer {
                Text("Full readings are generated in English in this build. Other languages adjust the interface text only.")
            }

            Toggle("Haptic Feedback", isOn: $defaults.enableHaptics)

            Toggle("Sound Effects", isOn: $defaults.enableSound)

            Toggle("Simplify divination language", isOn: $defaults.softenDivinationLanguage)
                .footer {
                    Text("Replaces casting-style wording with neutral reflection wording across the app, for App Store review resilience.")
                }
        } header: {
            Text("Appearance")
        }
    }

    private var dailyReflectionSection: some View {
        Section {
            Toggle("Daily Reflection Reminder", isOn: $defaults.dailyReflectionReminder)

            if defaults.dailyReflectionReminder {
                HStack {
                    Text("Reminder Time")
                    Spacer()
                    Text(defaults.reflectionReminderTime)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Daily Reflection")
        } footer: {
            Text("Yi will send you a gentle reminder to pause and reflect each day.")
        }
    }

    private var dataPrivacySection: some View {
        Section {
            HStack {
                Label("Local Data", systemImage: "internaldrive")
                Spacer()
                Text(privacyService.estimateDataSize())
                    .foregroundColor(.secondary)
            }

            Button {
                showingPrivacyStatement = true
            } label: {
                Label("Privacy Statement", systemImage: "hand.raised")
                    .foregroundColor(Color("YiInk"))
            }

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                HStack {
                    Label("Clear All Memory", systemImage: "trash")
                    if isResettingData {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isResettingData)
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("Your conversations, reflections, and personal data live only on this device. No data is ever uploaded to any server.")
        }
    }

    private var purchaseSection: some View {
        Section {
            if store.isPremium {
                HStack {
                    Label("Lifetime Access", systemImage: "infinity")
                    Spacer()
                    Text("Purchased")
                        .foregroundColor(.secondary)
                }
                if let date = defaults.purchaseDate {
                    HStack {
                        Label("Purchased On", systemImage: "calendar")
                        Spacer()
                        Text(date, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label("Unlock Lifetime Access", systemImage: "infinity")
                        .foregroundColor(Color("YiInk"))
                }
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .foregroundColor(Color("YiInk"))
                }
            }
        } header: {
            Text("Purchase")
        } footer: {
            Text("Free forever: daily reflection & your daily hexagram. Lifetime unlocks everything else — one payment, no subscription, no data selling.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(defaults.appVersion)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("First Launched", systemImage: "clock")
                Spacer()
                Text(defaults.firstLaunchDate, style: .date)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Total Reflections", systemImage: "sparkles")
                Spacer()
                Text("\(userProfile.totalInteractions)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    private func themeCard(_ theme: AppTheme) -> some View {
        ThemePreviewCard(
            theme: theme,
            isSelected: defaults.selectedTheme == theme
        ) {
            withAnimation(.easeInOut(duration: 0.25)) {
                defaults.selectedTheme = theme
            }
        }
    }

    // MARK: - 数据操作

    private func saveProfile() {
        do {
            try db.saveUserProfile(userProfile)
        } catch {
            print("[Settings] Failed to save profile: \(error)")
        }
    }

    private func resetAllData() async {
        isResettingData = true
        defer { isResettingData = false }

        do {
            try await privacyService.clearAllData(preserveCollection: false)
            // 重建默认画像
            userProfile = UserProfile()
            UserDefaultsManager.shared.resetAll()
        } catch {
            print("[Settings] Failed to reset data: \(error)")
        }
    }

    private func clearConversationsOnly() async {
        isResettingData = true
        defer { isResettingData = false }

        do {
            try await privacyService.clearAllData(preserveCollection: true)
            // 重建画像但保留卦象收藏
            let unlockedIDs = userProfile.unlockedHexagramIDs
            userProfile = UserProfile(unlockedHexagramIDs: unlockedIDs, isNewUser: true)
        } catch {
            print("[Settings] Failed to clear conversations: \(error)")
        }
    }
}

// MARK: - 主题预览卡

/// 设置页中的单张皮肤预览卡
///
/// 以该皮肤自身的调色板渲染一张迷你预览，点击即切换。
/// 选中态显示勾选标记，并轻微放大强调。
struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 迷你预览：皮肤背景渐变 + 强调圆点 + 爻线
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.palette.backgroundGradient)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.palette.cardBorder, lineWidth: 1)
                    )
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(theme.palette.accent)
                                .frame(width: 16, height: 16)
                                .offset(x: -10, y: -10)
                            VStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle()
                                        .fill(theme.palette.ink)
                                        .frame(width: 22, height: 2)
                                }
                            }
                            .offset(x: 8, y: 8)
                        }
                    )

                // 文案
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.displayName)
                        .font(.headline)
                        .foregroundColor(Color("YiInk"))
                    Text(theme.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(theme.palette.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("YiInk").opacity(isSelected ? 0.06 : 0.02))
                    .stroke(
                        isSelected ? theme.palette.accent : Color("YiInk").opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.01 : 1.0)
    }
}

// MARK: - 绑定扩展（UserDefaults属性双向绑定）

extension UserDefaultsManager {
    // SwiftUI Picker 需要 Binding<String>
    // 这些通过 computed property 在 SettingsView 中直接使用 @State 包装
}
