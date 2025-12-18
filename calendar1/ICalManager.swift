//
//  ICalManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/11/21.
//

import Foundation

// iCal（.ics）ファイルから予定を読み込み、保存する機能を提供します。
final class ICalManager {
    // 保存先のファイル URL
    private let fileURL: URL
    // iCal の日時フォーマット（UTC）
    private let dateFormatter: DateFormatter
    // 日付キー（yyyy-MM-dd）を生成するためのフォーマッタ
    private let dateKeyFormatter: DateFormatter
    
    // 初期化: 保存ファイル名を受け取り、ドキュメントディレクトリ内の URL を構築します。
    init(fileName: String = "events.ics") {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documentDirectory.appendingPathComponent(fileName)
        
        // iCal の日時形式は通常 'yyyyMMdd'T'HHmmss'Z'（UTC）で表現されるため設定
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormatter = formatter
        
        // アプリ内で日付キーを作るためのローカライズされたフォーマット
        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "ja_JP")
        keyFormatter.dateFormat = "yyyy-MM-dd"
        self.dateKeyFormatter = keyFormatter
    }
    
    // ics ファイルが存在すれば読み込み、辞書（日付キー -> Event 配列）を返す
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
        
        // 行ごとにパースして VEVENT ブロック単位でイベントを生成
        let lines = content.components(separatedBy: CharacterSet.newlines)
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            
            if line.hasPrefix("SUMMARY:") {
                // SUMMARY: の後ろがイベントタイトル（エスケープ解除して格納）
                currentTitle = unescapeICSString(String(line.dropFirst("SUMMARY:".count)))
            } else if line.hasPrefix("DTSTART") {
                // DTSTART:YYYYMMDDTHHMMSSZ の形式を期待
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentStart = dateFormatter.date(from: String(value))
                }
            } else if line.hasPrefix("DTEND") {
                // DTEND:YYYYMMDDTHHMMSSZ の形式を期待
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentEnd = dateFormatter.date(from: String(value))
                }
            } else if line == "END:VEVENT" {
                // VEVENT ブロック終了時に Event を作成して辞書に追加
                if let title = currentTitle, let start = currentStart, let end = currentEnd {
                    let event = Event(title: title, startTime: start, endTime: end)
                    let key = dateKeyFormatter.string(from: start)
                    events[key, default: []].append(event)
                }
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
    
    // アプリ内のイベント辞書を .ics 形式で保存する
    func saveEvents(_ events: [String: [Event]]) {
        var lines: [String] = []
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//calendar1//EN")
        
        let allEvents = events.values.flatMap { $0 }
        let timestamp = dateFormatter.string(from: Date())
        
        for event in allEvents {
            lines.append("BEGIN:VEVENT")
            // UID は各イベントに一意の識別子を採番
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
    
    // ics 用に文字列をエスケープ（バックスラッシュ、セミコロン、カンマ、改行）
    private func escapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    // ics から読み込んだエスケープ済み文字列を元に戻す
    private func unescapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
