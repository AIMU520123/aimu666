import Foundation
import UserNotifications

/// 每日反思提醒调度（本地通知）
///
/// 解决评审 P1-1「留存机制空心」的最后一块：离线也能推，契合隐私叙事。
/// 不依赖任何服务器，所有调度在设备端完成。
@MainActor
final class ReminderManager {
    static let shared = ReminderManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// 当前通知授权状态
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 请求通知授权。用户开启提醒时调用。
    /// - Returns: 是否获得授权
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[ReminderManager] Authorization error: \(error)")
            return false
        }
    }

    /// 根据当前偏好（开关 + 时间）刷新提醒调度
    ///
    /// - 开启：请求授权（未授权则尝试），排程每日本地通知
    /// - 关闭：移除所有已排程的反思提醒
    func refreshReminderFromPreferences() async {
        let defaults = UserDefaultsManager.shared
        guard defaults.dailyReflectionReminder else {
            await removePendingReminders()
            return
        }

        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional:
            await scheduleDailyReminder(at: defaults.reflectionReminderTime)
        case .notDetermined:
            let granted = await requestAuthorization()
            if granted {
                await scheduleDailyReminder(at: defaults.reflectionReminderTime)
            } else {
                defaults.dailyReflectionReminder = false
            }
        default:
            // denied：无法排程，回退开关
            defaults.dailyReflectionReminder = false
        }
    }

    /// 排程每日固定时间的本地通知（重复）
    private func scheduleDailyReminder(at timeString: String) async {
        await removePendingReminders()

        let components = timeString.split(separator: ":")
        let hour = Int(components.first ?? "8") ?? 8
        let minute = Int(components.last ?? "0") ?? 0

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "A moment with Yi"
        content.body = "Take a quiet pause to reflect on today. Your hexagram is waiting."
        content.sound = .default
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-reflection",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("[ReminderManager] Scheduled daily reminder at \(timeString)")
        } catch {
            print("[ReminderManager] Failed to schedule: \(error)")
        }
    }

    private func removePendingReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reflection"])
    }
}
