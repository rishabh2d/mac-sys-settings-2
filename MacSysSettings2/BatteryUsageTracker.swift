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
    var weekBuckets: [Int]
    var monthBuckets: [Int]
    var yearBuckets: [Int]
    var isCharging: Bool
}

enum BatteryUsageTracker {
    private struct Reading {
        var percent: Int
        var isCharging: Bool
    }

    private nonisolated static let schemaVersionKey = "battery.usage.schemaVersion"
    private nonisolated static let currentSchemaVersion = 7

    private nonisolated static let lastPercentKey = "battery.usage.lastPercent"
    private nonisolated static let usedTodayKey = "battery.usage.used.today"
    private nonisolated static let usedWeekKey = "battery.usage.used.week"
    private nonisolated static let usedMonthKey = "battery.usage.used.month"
    private nonisolated static let usedYearKey = "battery.usage.used.year"
    private nonisolated static let dailyLedgerKey = "battery.usage.dailyLedger"
    private nonisolated static let weekBucketsKey = "battery.usage.buckets.week"
    private nonisolated static let monthBucketsKey = "battery.usage.buckets.month"
    private nonisolated static let yearBucketsKey = "battery.usage.buckets.year"

    private nonisolated static let dayIDKey = "battery.usage.day.id"
    private nonisolated static let weekIDKey = "battery.usage.week.id"
    private nonisolated static let monthIDKey = "battery.usage.month.id"
    private nonisolated static let yearIDKey = "battery.usage.year.id"

    static func updateAndRead() -> BatteryUsageSnapshot? {
        guard let reading = readBattery() else { return nil }

        migrateLegacyKeysIfNeeded()
        pruneDailyLedger()

        let lastPercent = UserDefaults.standard.object(forKey: lastPercentKey) as? Int ?? reading.percent
        if reading.percent < lastPercent {
            addDrain(lastPercent - reading.percent)
        }

        UserDefaults.standard.set(reading.percent, forKey: lastPercentKey)

        let weekBuckets = weekBucketsFromLedger()
        let monthBuckets = monthBucketsFromLedger()
        let yearBuckets = yearBucketsFromLedger()
        let usedToday = ledgerValue(for: dateID())
        let usedWeek = weekBuckets.reduce(0, +)
        let usedMonth = monthBuckets.reduce(0, +)
        let usedYear = yearBuckets.reduce(0, +)
        UserDefaults.standard.set(usedToday, forKey: usedTodayKey)
        UserDefaults.standard.set(usedWeek, forKey: usedWeekKey)
        UserDefaults.standard.set(usedMonth, forKey: usedMonthKey)
        UserDefaults.standard.set(usedYear, forKey: usedYearKey)
        UserDefaults.standard.set(weekBuckets, forKey: weekBucketsKey)
        UserDefaults.standard.set(monthBuckets, forKey: monthBucketsKey)
        UserDefaults.standard.set(yearBuckets, forKey: yearBucketsKey)

        return BatteryUsageSnapshot(
            remainingPercent: reading.percent,
            usedTodayPercent: usedToday,
            usedWeekPercent: usedWeek,
            usedMonthPercent: usedMonth,
            usedYearPercent: usedYear,
            weekBuckets: weekBuckets,
            monthBuckets: monthBuckets,
            yearBuckets: yearBuckets,
            isCharging: reading.isCharging
        )
    }

    private static func addDrain(_ drop: Int) {
        guard drop > 0, drop < 80 else { return }
        var ledger = dailyLedger()
        let today = dateID()
        ledger[today, default: 0] += drop
        saveDailyLedger(ledger)
    }

    private static func migrateLegacyKeysIfNeeded() {
        let existingSchemaVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        guard existingSchemaVersion != currentSchemaVersion else { return }

        let existingToday = UserDefaults.standard.integer(forKey: usedTodayKey)
        let existingWeek = UserDefaults.standard.integer(forKey: usedWeekKey)
        let existingMonth = UserDefaults.standard.integer(forKey: usedMonthKey)
        let existingYear = UserDefaults.standard.integer(forKey: usedYearKey)
        let existingWeekBuckets = UserDefaults.standard.array(forKey: weekBucketsKey) as? [Int] ?? []
        let existingMonthBuckets = UserDefaults.standard.array(forKey: monthBucketsKey) as? [Int] ?? []
        for key in [
            "battery.usage.day.baseline",
            "battery.usage.week.baseline",
            "battery.usage.month.baseline",
            "battery.usage.year.baseline",
            "battery.usage.integratedTotalPercent",
            "battery.usage.lastTimestamp",
            "battery.usage.lastTelemetryKey",
            "battery.usage.sessionStartPercent",
            "battery.usage.sessionStartTelemetryPercent",
            weekBucketsKey,
            monthBucketsKey,
            yearBucketsKey
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        if dailyLedger().isEmpty {
            seedDailyLedger(
                todayTotal: existingToday,
                periodTotal: max(existingToday, existingWeek, existingMonth, existingYear),
                weekBuckets: existingWeekBuckets,
                monthBuckets: existingMonthBuckets
            )
        } else if existingSchemaVersion < 7 {
            repairLegacyYearSeededLedger()
        }
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
    }

    private static func seedDailyLedger(todayTotal: Int, periodTotal: Int, weekBuckets: [Int], monthBuckets: [Int]) {
        var ledger: [String: Int] = [:]
        let now = Date()
        let calendar = Calendar.current

        for (index, value) in weekBuckets.enumerated() where value > 0 {
            if let date = calendar.date(byAdding: .day, value: index - weekBucketIndex(now), to: calendar.startOfDay(for: now)) {
                ledger[dateID(date), default: 0] = max(ledger[dateID(date), default: 0], value)
            }
        }

        for (index, value) in monthBuckets.enumerated() where value > 0 {
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = index + 1
            if let date = calendar.date(from: components) {
                ledger[dateID(date), default: 0] = max(ledger[dateID(date), default: 0], value)
            }
        }

        ledger[dateID(now), default: 0] = max(ledger[dateID(now), default: 0], todayTotal)
        let missingTrackedTotal = max(0, periodTotal - ledger.values.reduce(0, +))
        if missingTrackedTotal > 0,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) {
            ledger[dateID(yesterday), default: 0] += missingTrackedTotal
        }
        saveDailyLedger(ledger)
    }

    private static func repairLegacyYearSeededLedger() {
        let calendar = Calendar.current
        let now = Date()
        guard let firstDayOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ),
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return
        }

        let firstDayID = dateID(firstDayOfMonth)
        let todayID = dateID(now)
        let yesterdayID = dateID(yesterday)
        guard firstDayID != todayID else { return }

        var ledger = dailyLedger()
        guard let legacyMonthValue = ledger[firstDayID], legacyMonthValue > 0 else { return }
        ledger[firstDayID] = nil
        ledger[yesterdayID, default: 0] += legacyMonthValue
        saveDailyLedger(ledger)
    }

    private static func dailyLedger() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: dailyLedgerKey) as? [String: Int]) ?? [:]
    }

    private static func saveDailyLedger(_ ledger: [String: Int]) {
        UserDefaults.standard.set(ledger, forKey: dailyLedgerKey)
    }

    private static func ledgerValue(for id: String) -> Int {
        dailyLedger()[id] ?? 0
    }

    private static func pruneDailyLedger() {
        let calendar = Calendar.current
        guard let oldestKeptDate = calendar.date(byAdding: .year, value: -1, to: Date()) else { return }
        let oldestKeptID = dateID(oldestKeptDate)
        let pruned = dailyLedger().filter { $0.key >= oldestKeptID }
        saveDailyLedger(pruned)
    }

    private static func weekBucketsFromLedger(_ date: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)
        guard let monday = calendar.date(byAdding: .day, value: -weekBucketIndex(date), to: todayStart) else {
            return Array(repeating: 0, count: 7)
        }
        let ledger = dailyLedger()
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return 0 }
            return ledger[dateID(day)] ?? 0
        }
    }

    private static func monthBucketsFromLedger(_ date: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        let days = daysInCurrentMonth(date)
        let components = calendar.dateComponents([.year, .month], from: date)
        let ledger = dailyLedger()
        return (1...days).map { day in
            var dayComponents = components
            dayComponents.day = day
            guard let bucketDate = calendar.date(from: dayComponents) else { return 0 }
            return ledger[dateID(bucketDate)] ?? 0
        }
    }

    private static func yearBucketsFromLedger(_ date: Date = Date()) -> [Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        return dailyLedger().reduce(into: Array(repeating: 0, count: 12)) { buckets, entry in
            guard let entryDate = dateFormatter.date(from: entry.key),
                  calendar.component(.year, from: entryDate) == currentYear else {
                return
            }
            let month = calendar.component(.month, from: entryDate) - 1
            guard buckets.indices.contains(month) else { return }
            buckets[month] += entry.value
        }
    }

    private static func weekBucketIndex(_ date: Date = Date()) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    private static func monthBucketIndex(_ date: Date = Date()) -> Int {
        max(0, Calendar.current.component(.day, from: date) - 1)
    }

    private static func yearBucketIndex(_ date: Date = Date()) -> Int {
        max(0, Calendar.current.component(.month, from: date) - 1)
    }

    private static func daysInCurrentMonth(_ date: Date = Date()) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    private static func dateID(_ date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
