//
//  BatteryUsageTracker.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

struct BatteryUsageSnapshot {
    var remainingPercent: Int
    var usedTodayPercent: Int
    var usedWeekPercent: Int
    var usedMonthPercent: Int
    var usedYearPercent: Int
    var isCharging: Bool
}

enum BatteryUsageTracker {
    private struct Reading {
        var percent: Int
        var isCharging: Bool
    }

    private nonisolated static let schemaVersionKey = "battery.usage.schemaVersion"
    private nonisolated static let currentSchemaVersion = 4

    private nonisolated static let lastPercentKey = "battery.usage.lastPercent"
    private nonisolated static let usedTodayKey = "battery.usage.used.today"
    private nonisolated static let usedWeekKey = "battery.usage.used.week"
    private nonisolated static let usedMonthKey = "battery.usage.used.month"
    private nonisolated static let usedYearKey = "battery.usage.used.year"

    private nonisolated static let dayIDKey = "battery.usage.day.id"
    private nonisolated static let weekIDKey = "battery.usage.week.id"
    private nonisolated static let monthIDKey = "battery.usage.month.id"
    private nonisolated static let yearIDKey = "battery.usage.year.id"

    static func updateAndRead() -> BatteryUsageSnapshot? {
        guard let reading = readBattery() else { return nil }

        migrateLegacyKeysIfNeeded()
        resetPeriodsIfNeeded(now: Date())

        let lastPercent = UserDefaults.standard.object(forKey: lastPercentKey) as? Int ?? reading.percent
        if reading.percent < lastPercent {
            addDrain(lastPercent - reading.percent)
        }

        UserDefaults.standard.set(reading.percent, forKey: lastPercentKey)

        return BatteryUsageSnapshot(
            remainingPercent: reading.percent,
            usedTodayPercent: UserDefaults.standard.integer(forKey: usedTodayKey),
            usedWeekPercent: UserDefaults.standard.integer(forKey: usedWeekKey),
            usedMonthPercent: UserDefaults.standard.integer(forKey: usedMonthKey),
            usedYearPercent: UserDefaults.standard.integer(forKey: usedYearKey),
            isCharging: reading.isCharging
        )
    }

    private static func addDrain(_ drop: Int) {
        guard drop > 0, drop < 80 else { return }
        for key in [usedTodayKey, usedWeekKey, usedMonthKey, usedYearKey] {
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + drop, forKey: key)
        }
    }

    private static func migrateLegacyKeysIfNeeded() {
        guard UserDefaults.standard.integer(forKey: schemaVersionKey) != currentSchemaVersion else { return }

        for key in [
            "battery.usage.day.baseline",
            "battery.usage.week.baseline",
            "battery.usage.month.baseline",
            "battery.usage.year.baseline",
            "battery.usage.integratedTotalPercent",
            "battery.usage.lastTimestamp",
            "battery.usage.lastTelemetryKey",
            "battery.usage.sessionStartPercent",
            "battery.usage.sessionStartTelemetryPercent"
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        clampUsageTotal(usedTodayKey)
        clampUsageTotal(usedWeekKey)
        clampUsageTotal(usedMonthKey)
        clampUsageTotal(usedYearKey)
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
    }

    private static func clampUsageTotal(_ key: String) {
        let value = UserDefaults.standard.integer(forKey: key)
        guard value < 0 || value > 1_000 else { return }
        UserDefaults.standard.set(max(0, min(value, 1_000)), forKey: key)
    }

    private static func resetPeriodsIfNeeded(now: Date) {
        resetPeriod(idKey: dayIDKey, valueKey: usedTodayKey, periodID: periodID(now, component: .day))
        resetPeriod(idKey: weekIDKey, valueKey: usedWeekKey, periodID: periodID(now, component: .weekOfYear))
        resetPeriod(idKey: monthIDKey, valueKey: usedMonthKey, periodID: periodID(now, component: .month))
        resetPeriod(idKey: yearIDKey, valueKey: usedYearKey, periodID: periodID(now, component: .year))
    }

    private static func resetPeriod(idKey: String, valueKey: String, periodID: String) {
        if UserDefaults.standard.string(forKey: idKey) != periodID {
            UserDefaults.standard.set(periodID, forKey: idKey)
            UserDefaults.standard.set(0, forKey: valueKey)
        }
    }

    private static func readBattery() -> Reading? {
        let output = run("/usr/bin/pmset", arguments: ["-g", "batt"])
        guard let percent = regexInt(#"(\d+)%"#, in: output) else { return nil }

        let powerText = output.lowercased()
        let isDischarging = powerText.contains("discharging")
        let pluggedIn = powerText.contains("ac power") ||
            (!isDischarging && (powerText.contains("; charging") || powerText.contains("; charged")))

        return Reading(
            percent: percent,
            isCharging: pluggedIn
        )
    }

    private static func run(_ path: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private static func regexInt(_ pattern: String, in output: String) -> Int? {
        guard let range = output.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(output[range])
        guard let numberRange = match.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(match[numberRange])
    }

    private static func periodID(_ date: Date, component: Calendar.Component) -> String {
        let calendar = Calendar.current
        switch component {
        case .day:
            return formatted(date, "yyyy-MM-dd")
        case .weekOfYear:
            let week = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)
            return "\(year)-W\(week)"
        case .month:
            return formatted(date, "yyyy-MM")
        case .year:
            return formatted(date, "yyyy")
        default:
            return formatted(date, "yyyy-MM-dd")
        }
    }

    private static func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
