import Foundation

// ICalManager.swift
// This file handles reading and writing events to a single iCal (.ics) file in the app Documents directory.
// Beginner explanation (Japanese):
// - アプリ内で作成した予定をファイル（events.ics）として保存したり、起動時にそのファイルから読み込んだりします。
// - iCal形式はカレンダーで広く使われるテキストフォーマットで、BEGIN:VEVENT / END:VEVENT のような行で予定が区切られます。
// - 保存の際はイベントのタイトル・開始・終了時刻を SUMMARY/DTSTART/DTEND として書き出します。
// - 読み込みの際は各 VEVENT ブロックをパースして `Event` オブジェクトに変換します。

final class ICalManager {
    private let fileURL: URL
    private let dateFormatter: DateFormatter
    private let dateKeyFormatter: DateFormatter

    init(fileName: String = "events.ics") {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documentDirectory.appendingPathComponent(fileName)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormatter = formatter

        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "ja_JP")
        keyFormatter.dateFormat = "yyyy-MM-dd"
        self.dateKeyFormatter = keyFormatter
    }

    // loadEvents:
    // - ファイルが存在すれば iCal テキストを読み、VEVENT ブロックごとに SUMMARY / DTSTART / DTEND / CATEGORIES / X-EVENT-ID を取り出して Event を生成します。
    // - 戻り値は日付キー (yyyy-MM-dd) -> Event 配列 の辞書です。これにより ContentView で日ごとに予定が表示できます。
    func loadEvents() -> [String: [Event]] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        var events: [String: [Event]] = [:]

        var currentTitle: String?
        var currentStart: Date?
        var currentEnd: Date?
        var currentCategory: String? = nil
        var currentID: UUID? = nil

        let lines = content.components(separatedBy: CharacterSet.newlines)

        for rawLine in lines {
            // 各行をトリムして処理します。空行は無視します。
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // SUMMARY: タイトル
            if line.hasPrefix("SUMMARY:") {
                currentTitle = unescapeICSString(String(line.dropFirst("SUMMARY:".count)))
            } else if line.hasPrefix("DTSTART") {
                // DTSTART は日付時刻。行は "DTSTART:20250101T090000Z" の形式になることが多い
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentStart = dateFormatter.date(from: String(value))
                }
            } else if line.hasPrefix("DTEND") {
                // DTEND は終了時刻
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentEnd = dateFormatter.date(from: String(value))
                }
            } else if line.hasPrefix("CATEGORIES:") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    let raw = String(value)
                    currentCategory = unescapeICSString(raw).isEmpty ? nil : unescapeICSString(raw)
                }
            } else if line.hasPrefix("X-EVENT-ID:") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    let raw = String(value)
                    currentID = UUID(uuidString: raw)
                }
            } else if line == "END:VEVENT" {
                // VEVENT の終わり。ここで collected な値から Event を作成して辞書に追加します。
                if let title = currentTitle, let start = currentStart, let end = currentEnd {
                    // categoryID は読み取った値を使う
                    let event: Event
                    if let id = currentID {
                        event = Event(id: id, title: title, startTime: start, endTime: end, categoryID: currentCategory)
                    } else {
                        event = Event(title: title, startTime: start, endTime: end, categoryID: currentCategory)
                    }
                    let key = dateKeyFormatter.string(from: start)
                    events[key, default: []].append(event)
                }
                currentTitle = nil
                currentStart = nil
                currentEnd = nil
                currentCategory = nil
                currentID = nil
            }
        }

        // 各日の予定を開始時間でソート
        for key in events.keys {
            events[key]?.sort { $0.startTime < $1.startTime }
        }

        return events
    }

    // saveEvents:
    // - アプリ内のイベント辞書を受け取り、iCal テキストを作ってファイルに保存します。
    // - SUMMARY/DTSTART/DTEND に加えて、CATEGORIES とカスタム X-EVENT-ID を書き出すように拡張しました。
    func saveEvents(_ events: [String: [Event]]) {
        var lines: [String] = []
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//calendar1//EN")

        let allEvents = events.values.flatMap { $0 }
        let timestamp = dateFormatter.string(from: Date())

        for event in allEvents {
            // VEVENT ブロックを追加
            lines.append("BEGIN:VEVENT")
            // Persist the original event id so it can be matched on load
            lines.append("X-EVENT-ID:\(event.id.uuidString)")
            lines.append("UID:\(UUID().uuidString)")
            lines.append("DTSTAMP:\(timestamp)")
            lines.append("DTSTART:\(dateFormatter.string(from: event.startTime))")
            lines.append("DTEND:\(dateFormatter.string(from: event.endTime))")
            // SUMMARY はタイトル
            lines.append("SUMMARY:\(escapeICSString(event.title))")
            // CATEGORIES にカテゴリIDを保存（存在する場合）
            if let cid = event.categoryID {
                lines.append("CATEGORIES:\(escapeICSString(cid))")
            }
            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")

        let output = lines.joined(separator: "\n")

        do {
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save iCal file: \(error)")
        }
    }

    // escapeICSString/unescapeICSString:
    // - iCal では ; , \n などをエスケープする必要があるため、保存時と読み込み時に置換を行います。
    private func escapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func unescapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
