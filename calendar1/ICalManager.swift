//
//  ICalManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/11/21.
//

import Foundation

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
        
        // 各日の予定を開始時間でソート
        for key in events.keys {
            events[key]?.sort { $0.startTime < $1.startTime }
        }
        
        return events
    }
    
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

