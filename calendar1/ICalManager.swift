import Foundation

// ========================================
// ICalManager.swift
// ========================================
// このファイルは、アプリ内で作成した予定を iCal (.ics) ファイル形式で
// アプリの Documents ディレクトリに保存・読み込みします。
//
// iCal形式の説明：
// - カレンダーで広く使われるテキストフォーマット。
// - BEGIN:VEVENT / END:VEVENT のような行で予定が区切られます。
// - 保存の際はイベントのタイトル・開始・終了時刻を SUMMARY/DTSTART/DTEND として書き出します。
// - 読み込みの際は各 VEVENT ブロックをパースして `Event` オブジェクトに変換します。

// ========================================
// final class ICalManager
// ========================================
// - iCal ファイルの読み書きを担当するクラス。
// - final を付けることでサブクラス化を禁止（パフォーマンス向上）。

final class ICalManager {
    // ========================================
    // fileURL: URL
    // ========================================
    // - iCal ファイルの保存場所。
    // - アプリの Documents ディレクトリ内に events.ics として保存。
    private let fileURL: URL
    
    // ========================================
    // dateFormatter: DateFormatter
    // ========================================
    // - Date を iCal 形式の文字列に変換するためのフォーマッタ。
    // - フォーマット: "yyyyMMdd'T'HHmmss'Z'" (例: 20250510T090000Z)
    // - タイムゾーン: UTC（'Z' は Zulu time = UTC）。
    private let dateFormatter: DateFormatter
    
    // ========================================
    // dateKeyFormatter: DateFormatter
    // ========================================
    // - Date を日付キーに変換するためのフォーマッタ。
    // - フォーマット: "yyyy-MM-dd" (例: 2025-05-10)
    // - ContentView 内で予定を日ごとに分類する際に使用。
    private let dateKeyFormatter: DateFormatter

    // ========================================
    // init イニシャライザ
    // ========================================
    // fileName: ファイル名（デフォルト: "events.ics"）
    init(fileName: String = "events.ics") {
        // ========================================
        // FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        // ========================================
        // - アプリの Documents ディレクトリへのパスを取得。
        // - .documentDirectory: ユーザーが作成したファイルを保存する場所。
        // - .userDomainMask: ユーザーホーム内を指定。
        // - .first!: 通常は1つ返されるため、最初の要素を取得。
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // ========================================
        // appendingPathComponent
        // ========================================
        // - Documents ディレクトリに fileName を追加してパス構築。
        self.fileURL = documentDirectory.appendingPathComponent(fileName)

        // ========================================
        // dateFormatter 初期化
        // ========================================
        let formatter = DateFormatter()
        // ========================================
        // locale = Locale(identifier: "en_US_POSIX")
        // ========================================
        // - DateFormatter の動作を確定的にするため、POSIX ロケール指定。
        // - 地域設定に左右されない安定したフォーマット。
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // ========================================
        // dateFormat
        // ========================================
        // - iCal 形式のタイムスタンプ: 20250510T090000Z
        // - 'T' と 'Z' はシングルクォートで囲みリテラル文字として指定。
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        // ========================================
        // timeZone = TimeZone(secondsFromGMT: 0)
        // ========================================
        // - UTC (GMT) タイムゾーン指定（秒数: 0）。
        // - iCal 形式では UTC での時刻記録が標準。
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormatter = formatter

        // ========================================
        // dateKeyFormatter 初期化
        // ========================================
        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "ja_JP")
        // ========================================
        // dateFormat = "yyyy-MM-dd"
        // ========================================
        // - 辞書キー用フォーマット。例: 2025-05-10
        keyFormatter.dateFormat = "yyyy-MM-dd"
        self.dateKeyFormatter = keyFormatter
    }

    // ========================================
    // loadEvents メソッド
    // ========================================
    // - ファイルが存在すれば iCal テキストを読み、VEVENT ブロックごとに
    //   SUMMARY / DTSTART / DTEND / CATEGORIES / X-EVENT-ID を取り出して Event を生成します。
    // - 戻り値は日付キー (yyyy-MM-dd) -> Event 配列 の辞書です。
    //   これにより ContentView で日ごとに予定が表示できます。
    // - 失敗時は空の辞書 [:] を返す。
    
    func loadEvents() -> [String: [Event]] {
        // ========================================
        // FileManager.default.fileExists
        // ========================================
        // - 指定パスにファイルが存在するか確認。
        // - ファイルが無い場合（初回起動など）は空の辞書で早期リターン。
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        // ========================================
        // String(contentsOf: encoding:)
        // ========================================
        // - ファイルからテキスト全体を読み込む。
        // - encoding: .utf8 で UTF-8 として読み込み。
        // - 失敗時（try?）は nil で早期リターン。
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        // ========================================
        // events 辞書初期化
        // ========================================
        // - [日付キー: Event配列] の構造。
        // - 各行を解析して Events を集めます。
        var events: [String: [Event]] = [:]

        // ========================================
        // パース用の一時変数
        // ========================================
        // - VEVENT ブロック内から抽出した値を一時保存。
        // - END:VEVENT に達したら、これらから Event を生成。
        var currentTitle: String?
        var currentStart: Date?
        var currentEnd: Date?
        var currentCategory: String? = nil
        var currentID: UUID? = nil

        // ========================================
        // components(separatedBy: CharacterSet.newlines)
        // ========================================
        // - テキストを改行で分割して行の配列に。
        let lines = content.components(separatedBy: CharacterSet.newlines)

        // ========================================
        // for rawLine in lines
        // ========================================
        // - 各行をループ処理。
        for rawLine in lines {
            // ========================================
            // trimmingCharacters(in: .whitespacesAndNewlines)
            // ========================================
            // - 行の前後から空白・改行を削除。
            // - 空行を処理から除外。
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // ========================================
            // SUMMARY: タイトル行の処理
            // ========================================
            // - "SUMMARY:会議" という形式から ":会議" 部分を抽出。
            if line.hasPrefix("SUMMARY:") {
                currentTitle = unescapeICSString(String(line.dropFirst("SUMMARY:".count)))
            }
            // ========================================
            // DTSTART: 開始日時行の処理
            // ========================================
            // - "DTSTART:20250101T090000Z" 形式から タイムスタンプ部分抽出。
            else if line.hasPrefix("DTSTART") {
                // split(separator: maxSplits: omittingEmptySubsequences:)
                // で ":" で分割（最大1分割）。
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    // dateFormatter で Date に変換。
                    currentStart = dateFormatter.date(from: String(value))
                }
            }
            // ========================================
            // DTEND: 終了日時行の処理
            // ========================================
            else if line.hasPrefix("DTEND") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    currentEnd = dateFormatter.date(from: String(value))
                }
            }
            // ========================================
            // CATEGORIES: カテゴリID行の処理
            // ========================================
            // - "CATEGORIES:category-id-123" からカテゴリID抽出。
            else if line.hasPrefix("CATEGORIES:") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    let raw = String(value)
                    currentCategory = unescapeICSString(raw).isEmpty ? nil : unescapeICSString(raw)
                }
            }
            // ========================================
            // X-EVENT-ID: カスタム UUID 行の処理
            // ========================================
            // - "X-EVENT-ID:550e8400-e29b-41d4-a716-446655440000" から UUID 抽出。
            else if line.hasPrefix("X-EVENT-ID:") {
                if let value = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last {
                    let raw = String(value)
                    currentID = UUID(uuidString: raw)
                }
            }
            // ========================================
            // END:VEVENT: VEVENT ブロック終了
            // ========================================
            // - 集めた値から Event を生成して辞書に追加します。
            else if line == "END:VEVENT" {
                // ========================================
                // guard let title, let start, let end
                // ========================================
                // - 必須フィールドが揃っているか確認。
                // - 不完全なブロックは無視。
                if let title = currentTitle, let start = currentStart, let end = currentEnd {
                    // ========================================
                    // Event 作成
                    // ========================================
                    // - categoryID は読み取った値を使う。
                    let event: Event
                    if let id = currentID {
                        // ========================================
                        // 保存された UUID がある場合
                        // ========================================
                        // - 元の ID を保持することで、編集後も同じ予定として扱う。
                        event = Event(id: id, title: title, startTime: start, endTime: end, categoryID: currentCategory)
                    } else {
                        // ========================================
                        // 保存された UUID がない場合
                        // ========================================
                        // - 新しい UUID を生成（初期化パラメータで自動生成）。
                        event = Event(title: title, startTime: start, endTime: end, categoryID: currentCategory)
                    }
                    
                    // ========================================
                    // dateKeyFormatter で日付キー生成
                    // ========================================
                    // - startTime から "yyyy-MM-dd" 形式のキーを作成。
                    let key = dateKeyFormatter.string(from: start)
                    // ========================================
                    // events[key, default: []].append(event)
                    // ========================================
                    // - key が存在しなければデフォルト空配列、存在すれば既存配列。
                    // - その配列に event を追加。
                    events[key, default: []].append(event)
                }
                // ========================================
                // 一時変数をリセット
                // ========================================
                // - 次の VEVENT ブロック処理の準備。
                currentTitle = nil
                currentStart = nil
                currentEnd = nil
                currentCategory = nil
                currentID = nil
            }
        }

        // ========================================
        // 各日の予定を開始時間でソート
        // ========================================
        // - 同一日の複数予定を時系列順に並び替え。
        for key in events.keys {
            events[key]?.sort { $0.startTime < $1.startTime }
        }

        return events
    }

    // ========================================
    // saveEvents メソッド
    // ========================================
    // - アプリ内のイベント辞書を受け取り、iCal テキストを作ってファイルに保存します。
    // - SUMMARY/DTSTART/DTEND に加えて、CATEGORIES とカスタム X-EVENT-ID を書き出します。
    
    func saveEvents(_ events: [String: [Event]]) {
        // ========================================
        // lines 配列初期化
        // ========================================
        // - iCal 形式の行を順番に追加していく。
        var lines: [String] = []
        
        // ========================================
        // BEGIN:VCALENDAR / VERSION:2.0 / PRODID
        // ========================================
        // - iCal ファイルのヘッダ。固定。
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//calendar1//EN")

        // ========================================
        // allEvents 構築
        // ========================================
        // - 辞書の全イベント（複数キー）をフラット配列に変換。
        // - values で値の配列配列を取得、flatMap で1次元に。
        let allEvents = events.values.flatMap { $0 }
        
        // ========================================
        // timestamp
        // ========================================
        // - 現在日時を iCal タイムスタンプで取得。
        // - DTSTAMP に使用。
        let timestamp = dateFormatter.string(from: Date())

        // ========================================
        // for event in allEvents
        // ========================================
        // - 各イベントを iCal ブロックとして出力。
        for event in allEvents {
            // ========================================
            // BEGIN:VEVENT
            // ========================================
            lines.append("BEGIN:VEVENT")
            
            // ========================================
            // X-EVENT-ID: カスタム UUID
            // ========================================
            // - 元のイベント ID を保持して、読み込み時に照合可能にする。
            lines.append("X-EVENT-ID:\(event.id.uuidString)")
            
            // ========================================
            // UID: iCal 標準の ID（異なる UUID）
            // ========================================
            // - iCal 仕様で必須。内部用。
            lines.append("UID:\(UUID().uuidString)")
            
            // ========================================
            // DTSTAMP: タイムスタンプ
            // ========================================
            // - ファイル作成時刻。iCal 仕様。
            lines.append("DTSTAMP:\(timestamp)")
            
            // ========================================
            // DTSTART / DTEND
            // ========================================
            // - イベント開始・終了時刻を iCal 形式で出力。
            lines.append("DTSTART:\(dateFormatter.string(from: event.startTime))")
            lines.append("DTEND:\(dateFormatter.string(from: event.endTime))")
            
            // ========================================
            // SUMMARY: タイトル
            // ========================================
            // - escapeICSString で特殊文字をエスケープして記録。
            lines.append("SUMMARY:\(escapeICSString(event.title))")
            
            // ========================================
            // CATEGORIES: カテゴリID（オプション）
            // ========================================
            // - categoryID が存在する場合だけ追加。
            // - nil の場合は出力しない（未分類）。
            if let cid = event.categoryID {
                lines.append("CATEGORIES:\(escapeICSString(cid))")
            }
            
            // ========================================
            // END:VEVENT
            // ========================================
            lines.append("END:VEVENT")
        }

        // ========================================
        // END:VCALENDAR
        // ========================================
        // - iCal ファイルフッタ。
        lines.append("END:VCALENDAR")

        // ========================================
        // joined(separator: "\n")
        // ========================================
        // - 行配列を改行で連結してテキスト生成。
        let output = lines.joined(separator: "\n")

        do {
            // ========================================
            // write(to: atomically: encoding:)
            // ========================================
            // - テキストをファイルに書き込み。
            // - atomically: true で、完全に書き込まれてからファイル確定。
            // - encoding: .utf8 で UTF-8 として保存。
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save iCal file: \(error)")
        }
    }

    // ========================================
    // escapeICSString メソッド（private）
    // ========================================
    // - iCal では ; , \n などをエスケープする必要があります。
    // - これらの文字が含まれる場合は バックスラッシュでエスケープ。
    
    private func escapeICSString(_ value: String) -> String {
        // ========================================
        // replacingOccurrences(of: with:)
        // ========================================
        // - 指定の文字列を別の文字列に置換。
        // - 複数回チェーンして、複数の置換を実行。
        // - 順序注意: \\ を最初に処理（既存の \\ と新規追加の \\ を区別するため）。
        return value
            .replacingOccurrences(of: "\\", with: "\\\\") // バックスラッシュをエスケープ
            .replacingOccurrences(of: ";", with: "\\;")   // セミコロンをエスケープ
            .replacingOccurrences(of: ",", with: "\\,")   // カンマをエスケープ
            .replacingOccurrences(of: "\n", with: "\\n")  // 改行をエスケープ
    }

    // ========================================
    // unescapeICSString メソッド（private）
    // ========================================
    // - escapeICSString の逆処理。
    // - ファイル読み込み時に、エスケープされた文字を元に戻す。
    // - 順序注意: \\\ を最後に処理（他のエスケープシーケンスと区別するため）。
    
    private func unescapeICSString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\n", with: "\n")   // 改行エスケープを元に戻す
            .replacingOccurrences(of: "\\,", with: ",")    // カンマエスケープを元に戻す
            .replacingOccurrences(of: "\\;", with: ";")    // セミコロンエスケープを元に戻す
            .replacingOccurrences(of: "\\\\", with: "\\")  // バックスラッシュエスケープを元に戻す
    }
}
