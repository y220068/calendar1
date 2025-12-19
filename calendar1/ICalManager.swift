//
//  ICalManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/11/21.
//

// このクラスはアプリの予定データを iCal(.ics) 形式で読み書きするためのヘルパーです。
// コードが読めない人向けの説明：
// - 予定を内蔵のデータ形式（Event）で扱い、ファイルに保存したり、ファイルから読み込んだりします。
// - iCal 形式はカレンダーで使われる一般的なファイル形式で、BEGIN:VEVENT / END:VEVENT のような行で1件ずつ予定が記録されます。

import Foundation

final class ICalManager {
    // ファイル保存先（ドキュメントフォルダ内の events.ics）
    private let fileURL: URL
    // ics 内の日付形式（UTC）を扱うフォーマッタ
    private let dateFormatter: DateFormatter
    // アプリ内で日付キー（yyyy-MM-dd）を作るためのフォーマッタ
    private let dateKeyFormatter: DateFormatter

    init(fileName: String = "events.ics") {
        // ドキュメントフォルダを取得してファイルのパスを作る
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documentDirectory.appendingPathComponent(fileName)

        // iCal の日時表現は UTC の形式が多いので、このフォーマッタを使って変換する
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormatter = formatter

        // アプリ内で使う「日付キー」を作るためのフォーマッタ
        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "ja_JP")
        keyFormatter.dateFormat = "yyyy-MM-dd"
        self.dateKeyFormatter = keyFormatter
    }

    // loadEvents:
    // - もし保存ファイルが存在すれば読み込み、Event の配列を日付キーごとにまとめて辞書で返します。
    // - ファイルがなければ空の辞書を返します。
    func loadEvents() -> [String: [Event]] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [:] }

        var events: [String: [Event]] = [:]

        // 一時的に VEVENT ブロックの情報を保持する変数
        var currentTitle: String?
        var currentStart: Date?
        var currentEnd: Date?

        // ファイルを行ごとに読み、SUMMARY / DTSTART / DTEND を探して VEVENT の終わりで Event を作る
        let lines = content.components(separatedBy: CharacterSet.newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("SUMMARY:") {
                currentTitle = unescapeICSString(String(line.dropFirst("SUMMARY:".count)))
            } else if line.hasPrefix("DTSTART") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentStart = dateFormatter.date(from: String(value))
                }
            } else if line.hasPrefix("DTEND") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentEnd = dateFormatter.date(from: String(value))
                }
            } else if line == "END:VEVENT" {
                // VEVENT が終わったら情報をまとめて Event を作る
                if let title = currentTitle, let start = currentStart, let end = currentEnd {
                    let event = Event(title: title, startTime: start, endTime: end)
                    let key = dateKeyFormatter.string(from: start)
                    events[key, default: []].append(event)
                }
                // 一時変数をリセット
                currentTitle = nil
                currentStart = nil
                currentEnd = nil
            }
        }

        // 各日のイベントを開始時刻でソートして返す
        for key in events.keys {
            events[key]?.sort { $0.startTime < $1.startTime }
        }
        return events
    }

    // saveEvents:
    // - in-memory の events 辞書を .ics 形式のテキストに変換してファイルに書き出します。
    // - 各 Event を VEVENT ブロックとして出力します。
    func saveEvents(_ events: [String: [Event]]) {
        var lines: [String] = []
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//calendar1//EN")

        let allEvents = events.values.flatMap { $0 }
        let timestamp = dateFormatter.string(from: Date())

        for event in allEvents {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(UUID().uuidString)")
            lines.append("DTSTAMP:\(timestamp)")
            lines.append("DTSTART:\(dateFormatter.string(from: event.startTime))")
            lines.append("DTEND:\(dateFormatter.string(from: event.endTime))")
            lines.append("SUMMARY:\(escapeICSString(event.title))")
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

    // エスケープ: iCal では特定の文字（\, ; , , , 改行など）をエスケープして保存する必要があるため
    private func escapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    // 逆に読み込み時にエスケープを戻す
    private func unescapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
