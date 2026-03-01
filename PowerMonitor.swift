import SwiftUI
import Combine
import IOKit
import IOKit.ps
import UserNotifications

// MARK: - Power Monitor

class PowerMonitor: ObservableObject {
    @Published var voltage: Int = 0
    @Published var amperage: Int = 0
    @Published var batteryPercent: Int = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var chargerWatts: Int = 0
    @Published var cycleCount: Int = 0

    private var runLoopSource: CFRunLoopSource?
    private var refreshTimer: AnyCancellable?
    private var lastNotificationDate: Date?
    private let notificationCooldown: TimeInterval = 300

    var batteryWatts: Double {
        Double(voltage) * Double(amperage) / 1_000_000.0
    }

    var systemWatts: Double {
        guard isPluggedIn, chargerWatts > 0 else { return abs(batteryWatts) }
        return Double(chargerWatts) - batteryWatts
    }

    var menuBarLabel: String {
        if !isPluggedIn {
            return "\(batteryPercent)%"
        }
        if amperage < 0 {
            return String(format: "%.0fW", abs(batteryWatts))
        }
        return String(format: "%.0fW", batteryWatts)
    }

    var iconName: String {
        if !isPluggedIn { return "minus.plus.batteryblock" }
        if amperage < 0 { return "exclamationmark.triangle.fill" }
        if isCharging { return "bolt.fill" }
        return "powerplug.fill"
    }

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        setupPowerMonitoring()
        updatePowerStatus()
    }

    private func setupPowerMonitoring() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { monitor.updatePowerStatus() }
        }, context)?.takeRetainedValue()

        if let source {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        // Lightweight backup timer to keep menu bar label fresh
        refreshTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updatePowerStatus() }
    }

    func updatePowerStatus() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return }

        voltage = dict["Voltage"] as? Int ?? 0
        amperage = dict["InstantAmperage"] as? Int ?? 0
        batteryPercent = dict["CurrentCapacity"] as? Int ?? 0
        isCharging = dict["IsCharging"] as? Bool ?? false
        isPluggedIn = dict["ExternalConnected"] as? Bool ?? false
        cycleCount = dict["CycleCount"] as? Int ?? 0

        if let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            chargerWatts = details["Watts"] as? Int ?? 0
        }

        if isPluggedIn && amperage < 0 {
            sendDrainWarning()
        }
    }

    private func sendDrainWarning() {
        let now = Date()
        if let last = lastNotificationDate, now.timeIntervalSince(last) < notificationCooldown { return }
        lastNotificationDate = now

        let content = UNMutableNotificationContent()
        content.title = "Power Warning"
        content.body = String(
            format: "Battery draining at %.1fW despite being plugged in (charger: %dW)",
            abs(batteryWatts), chargerWatts
        )
        content.sound = .default

        let request = UNNotificationRequest(identifier: "power-drain", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - App

@main
struct PowerMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = PowerMonitor()

    var body: some Scene {
        MenuBarExtra {
            Button {
                monitor.updatePowerStatus()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            Divider()
            if monitor.isPluggedIn {
                Label("Charger: \(monitor.chargerWatts)W", systemImage: "powerplug.fill")
                if monitor.amperage >= 0 {
                    Label(
                        String(format: "Battery: +%.1fW (charging)", monitor.batteryWatts),
                        systemImage: "bolt.fill"
                    )
                } else {
                    Label(
                        String(format: "Battery: %.1fW (draining!)", monitor.batteryWatts),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
                Label(String(format: "System: ~%.0fW", monitor.systemWatts), systemImage: "cpu")
            } else {
                Label("On Battery", systemImage: "minus.plus.batteryblock")
                Label(String(format: "Draw: %.1fW", abs(monitor.batteryWatts)), systemImage: "bolt.horizontal.fill")
            }
            Divider()
            Label("Battery: \(monitor.batteryPercent)%", systemImage: "battery.75")
            Label("Cycles: \(monitor.cycleCount)", systemImage: "arrow.2.squarepath")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: monitor.iconName)
            Text(monitor.menuBarLabel)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
