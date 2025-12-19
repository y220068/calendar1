//
//  ContentView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

// このファイルはアプリのメイン画面を定義しています。
// ここでは「月表示のカレンダー」「日付ごとの予定一覧」「予定の追加・編集・削除」「テーマ（色）設定」「検索画面への遷移」など
// ユーザーが直接触る主要な UI と、そのために必要なデータ（予定の保存・読み込み）をまとめています。
//
// 以下はコードが読めない方にもわかるように、
// - 何が保存されているか（状態）
// - どの操作で何が起きるか（動作）
// - 主要な補助関数の役割
// を、やさしく書いたコメントです。

import SwiftUI

// --- 予定（Event）というデータの説明（モデル） ---
// Event はカレンダー上の 1 件の予定を表します。
// - id: この予定を一意に識別するための番号（プログラム内部で使う）
// - title: 予定の名前（例: 会議、ランチ）
// - startTime / endTime: 予定の開始と終了の日時
struct Event: Identifiable {
    let id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
}

// --- メイン画面 ContentView の説明（非専門家向け） ---
// この画面は次のことを行います：
// 1) 画面上部に「年・月」と左右ボタンを表示して、月を切り替えられます。
// 2) 曜日行と日付のグリッドでその月のカレンダーを表示します。
// 3) 日付をタップすると、その日の予定一覧を下に表示し、新しい予定を追加できます。
// 4) 予定をタップすると編集・削除の選択ができます。
// 5) 画面右上に検索ボタン（検索画面へ）とテーマ設定ボタン（色を選べる）があります。
//
// 「この説明だけ見れば何ができるか分かる」ように、状態と主な処理を平易に書いています。

struct ContentView: View {
    // --- 保存される「状態（State）」の説明 ---
    // currentDate: 現在表示中の基準日（例: 2025年12月ならその月を表示）
    @State private var currentDate = Date()
    // selectedDate: カレンダーでユーザーが選んだ日（その日の予定を表示する）
    @State private var selectedDate: Date? = nil

    // 予定追加ダイアログを表示するかどうかのフラグ
    @State private var showAddEvent = false
    // 追加中の予定タイトル、開始時間、終了時間（入力中の一時保存）
    @State private var newEventText = ""
    @State private var newEventStartTime = Date()
    @State private var newEventEndTime = Date()

    // events: 実際に保存している予定データ
    // キーは日付文字列（例: "2025-12-19"）、値はその日に登録された Event の配列
    @State private var events: [String: [Event]] = [:]

    // 予定削除時の確認ダイアログ表示フラグ
    @State private var showDeleteAlert = false
    // 削除対象を特定するための一時情報（日付キーと配列のインデックス）
    @State private var eventToDelete: (dateKey: String, index: Int)? = nil

    // 予定を編集するためのアクションシート表示フラグと編集対象情報
    @State private var showActionSheet = false
    @State private var eventToEdit: (dateKey: String, index: Int)? = nil
    @State private var editEventText = ""
    @State private var editEventStartTime = Date()
    @State private var editEventEndTime = Date()
    @State private var showEditSheet = false

    // テーマ色（ユーザーが画面の色を変えられる）、とそのインデックス（保存用）
    @State private var selectedThemeColor = Color.blue
    @State private var selectedThemeColorIndex = 0

    // 初期読み込みが済んでいるか（iCal から読み込むのは一度だけで良い）
    @State private var hasLoadedInitialData = false

    // テーマ設定画面・検索画面を開くフラグ
    @State private var showThemeSettings = false
    @State private var showSearchView = false

    // --- 簡単に使う補助データ ---
    // いくつかのテーマ色を配列で持っておく（ユーザーはここから色を選ぶ）
    private let themeColors: [Color] = [
        .blue, .red, .green, .orange, .purple, .pink, .teal, .indigo,
        .mint, .cyan, .brown, .yellow, .gray,
        Color(red: 0.2, green: 0.6, blue: 0.8),
        Color(red: 0.4, green: 0.8, blue: 0.4),
        Color(red: 0.8, green: 0.4, blue: 0.2),
        Color(red: 0.6, green: 0.4, blue: 0.8),
        Color(red: 0.8, green: 0.6, blue: 0.4),
        Color(red: 0.4, green: 0.6, blue: 0.8),
        Color(red: 0.8, green: 0.4, blue: 0.6),
        Color(red: 0.6, green: 0.8, blue: 0.4),
        Color(red: 0.8, green: 0.6, blue: 0.2),
        Color(red: 0.4, green: 0.4, blue: 0.8),
        Color(red: 0.8, green: 0.2, blue: 0.4),
        Color(red: 0.2, green: 0.8, blue: 0.6),
        Color(red: 0.8, green: 0.4, blue: 0.8),
        Color(red: 0.6, green: 0.2, blue: 0.8),
        Color(red: 0.8, green: 0.8, blue: 0.4),
        Color(red: 0.4, green: 0.8, blue: 0.8)
    ]

    // UserDefaults に保存するキー名（テーマ色）
    private let themeColorKey = "selectedThemeColorIndex"
    // カレンダー（曜日や日付計算に使う）
    private var calendar: Calendar { Calendar.current }
    // iCal の読み書きを行うヘルパー（別ファイルで実装）
    private let icalManager = ICalManager()

    // daysInMonth: 現在の currentDate の月に含まれる日をすべて返す（表示用）
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return [] }
        var dates: [Date] = []
        var date = monthInterval.start
        while date < monthInterval.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return dates
    }

    // firstWeekday: 月の最初の日の曜日番号（例: 日曜=1, 月曜=2, ...）
    private var firstWeekday: Int {
        calendar.component(.weekday, from: daysInMonth.first ?? Date())
    }

    // 曜日のラベル（表示用）
    private let weekDays = ["日", "月", "火", "水", "木", "金", "土"]

    // ---------------- メインの表示部分（UI） ----------------
    var body: some View {
        ZStack {
            // 背景: 選んだテーマ色を薄く使ってグラデーションにしています。
            LinearGradient(
                gradient: Gradient(colors: [
                    selectedThemeColor.opacity(0.15),
                    selectedThemeColor.opacity(0.05),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                // ヘッダー: 月表示と左右の移動ボタン、検索・テーマボタン
                HStack(spacing: 12) {
                    // 左ボタン: 前の月へ移動
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(selectedThemeColor)
                            .font(.title2)
                            .padding(10)
                            .background(Circle().fill(selectedThemeColor.opacity(0.1)))
                    }

                    // 中央: 現在表示している年月を表示
                    Text(monthYearString(currentDate))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(selectedThemeColor)
                        .shadow(color: selectedThemeColor.opacity(0.3), radius: 2, x: 0, y: 1)

                    // 右ボタン: 次の月へ移動
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(selectedThemeColor)
                            .font(.title2)
                            .padding(10)
                            .background(Circle().fill(selectedThemeColor.opacity(0.1)))
                    }

                    Spacer()

                    // 右上のアイコン群: 検索（虫眼鏡）とテーマ設定（筆）
                    HStack(spacing: 12) {
                        Button(action: { showSearchView = true }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(12)
                                .background(Circle().fill(selectedThemeColor.opacity(0.8)))
                        }

                        Button(action: { showThemeSettings = true }) {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(12)
                                .background(Circle().fill(selectedThemeColor))
                        }
                    }
                }
                .padding(.top)
                .padding(.horizontal)

                // カレンダー表示部分（曜日行 + 日付グリッド）
                VStack(spacing: 0) {
                    // 曜日の行
                    HStack {
                        ForEach(weekDays, id: \ .self) { day in
                            Text(day)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedThemeColor.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedThemeColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : selectedThemeColor))
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // 日付グリッド: 月の最初に空セルを入れる（曜日合わせ）
                    let leadingSpaces = Array(repeating: "", count: firstWeekday - 1)
                    let days = daysInMonth.map { String(calendar.component(.day, from: $0)) }
                    let allDays = leadingSpaces + days
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(0..<allDays.count, id: \ .self) { i in
                            let isDate = i >= leadingSpaces.count
                            let date = isDate ? daysInMonth[i - leadingSpaces.count] : nil
                            ZStack {
                                if isDate, let date = date {
                                    // 選択状態・今日・その日のイベント一覧を判定
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast)
                                    let isToday = calendar.isDateInToday(date)
                                    let dateKey = dateKey(date)
                                    let dayEvents = events[dateKey] ?? []

                                    // セルの背景を選択/今日で色分け
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            isSelected ? selectedThemeColor.opacity(0.4) :
                                            isToday ? selectedThemeColor.opacity(0.2) : Color.white
                                        )
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? selectedThemeColor : Color.clear, lineWidth: 3))
                                        .shadow(color: isSelected ? selectedThemeColor.opacity(0.3) : Color.black.opacity(0.1), radius: isSelected ? 6 : 2, x: 0, y: isSelected ? 3 : 1)
                                        .frame(height: 50)

                                    VStack(spacing: 2) {
                                        // 日にちの数字
                                        Text(allDays[i])
                                            .fontWeight(isToday ? .bold : .semibold)
                                            .font(.system(size: 16))
                                            .foregroundColor(isSelected ? .white : (i % 7 == 0) ? .red : (i % 7 == 6 ? .blue : .primary))

                                        // その日の予定を最大3件まで表示（超えると +N 表示）
                                        if !dayEvents.isEmpty {
                                            VStack(spacing: 1) {
                                                ForEach(0..<min(dayEvents.count, 3), id: \.self) { idx in
                                                    let event = dayEvents[idx]
                                                    Text(event.title)
                                                        .font(.system(size: 8))
                                                        .fontWeight(.medium)
                                                        .foregroundColor(isSelected ? .white : selectedThemeColor)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                }
                                                if dayEvents.count > 3 {
                                                    Text("+\(dayEvents.count - 3)")
                                                        .font(.system(size: 7))
                                                        .foregroundColor(isSelected ? .white : selectedThemeColor)
                                                        .fontWeight(.bold)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // 月の前後に入る空セル（見た目調整）
                                    Text(allDays[i])
                                        .foregroundColor(.clear)
                                        .frame(height: 50)
                                }
                            }
                            .onTapGesture {
                                // 日付セルをタップしたらその日を選択し、新規予定の追加ダイアログを開く
                                if isDate, let date = date {
                                    selectedDate = date
                                    showAddEvent = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.3), radius: 15, x: 0, y: 8))
                .padding(.horizontal)

                // 選択した日の予定一覧を表示する領域
                if let selectedDate = selectedDate {
                    let key = dateKey(selectedDate)
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("\(monthYearString(selectedDate)) \(calendar.component(.day, from: selectedDate))日 の予定")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(selectedThemeColor)
                                .shadow(color: selectedThemeColor.opacity(0.3), radius: 1, x: 0, y: 1)
                            Spacer()
                        }
                        .padding(.horizontal)

                        if let eventList = events[key], !eventList.isEmpty {
                            // その日の予定を開始時刻順に並べて表示
                            let sortedEvents = eventList.sorted { $0.startTime < $1.startTime }
                            ForEach(sortedEvents.indices, id: \ .self) { idx in
                                let event = sortedEvents[idx]
                                HStack {
                                    // 時刻ラベル: 09:00-10:00 のように表示
                                    Text("\(timeString(event.startTime)) - \(timeString(event.endTime))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(selectedThemeColor))

                                    // 予定タイトル
                                    Text("・\(event.title)")
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.2), radius: 4, x: 0, y: 2))
                                .onTapGesture {
                                    // 既存の予定をタップすると編集または削除のメニューを表示
                                    if let originalIndex = eventList.firstIndex(where: { $0.id == event.id }) {
                                        eventToEdit = (key, originalIndex)
                                        showActionSheet = true
                                    }
                                }
                            }
                        } else {
                            // 予定が何もない場合の表示
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(selectedThemeColor.opacity(0.6))
                                    .font(.title2)
                                Text("予定はありません")
                                    .foregroundColor(.gray)
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.15), radius: 3, x: 0, y: 1))
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        // この onAppear は画面が最初に表示されたときに呼ばれます。
        // iCal から予定を読み込み（ファイルがあれば）、テーマ色も復元します。
        .onAppear {
            if !hasLoadedInitialData {
                events = icalManager.loadEvents()
                loadThemeColor()
                hasLoadedInitialData = true
            }
        }
        // --------------- ここからダイアログ・シートなどの処理 ---------------
        // 新規予定を追加するシート（モーダル）
        .sheet(isPresented: $showAddEvent) {
            VStack {
                Text("予定を追加")
                    .font(.headline)
                    .padding()

                // 予定のタイトルを入力する欄
                TextField("予定を入力", text: $newEventText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                // 時刻選択（開始 / 終了）
                HStack {
                    VStack(alignment: .leading) {
                        Text("開始時間")
                            .font(.caption)
                        DatePicker("", selection: $newEventStartTime, displayedComponents: .hourAndMinute)
                    }
                    VStack(alignment: .leading) {
                        Text("終了時間")
                            .font(.caption)
                        DatePicker("", selection: $newEventEndTime, displayedComponents: .hourAndMinute)
                    }
                }
                .padding()

                // キャンセル・追加ボタン
                HStack {
                    Button("キャンセル") {
                        // モーダルを閉じて入力をクリアする
                        showAddEvent = false
                        newEventText = ""
                        newEventStartTime = Date()
                        newEventEndTime = Date()
                    }
                    .padding()
                    Spacer()
                    Button("追加") {
                        // 必要な情報が揃っていれば events に追加し、iCal に保存
                        if let selectedDate = selectedDate, !newEventText.isEmpty {
                            let key = dateKey(selectedDate)
                            let start = combine(date: selectedDate, time: newEventStartTime)
                            let end = combine(date: selectedDate, time: newEventEndTime)
                            let event = Event(title: newEventText, startTime: start, endTime: end)
                            if events[key] != nil {
                                events[key]?.append(event)
                                events[key]?.sort { $0.startTime < $1.startTime }
                            } else {
                                events[key] = [event]
                            }
                            saveEventsToICal()
                        }
                        // 入力をリセットしてモーダルを閉じる
                        showAddEvent = false
                        newEventText = ""
                        newEventStartTime = Date()
                        newEventEndTime = Date()
                    }
                    .foregroundColor(selectedThemeColor)
                    .padding()
                }
            }
            .padding()
        }

        // 予定を編集/削除するためのアクションシート
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("予定の操作"),
                message: Text("この予定を編集または削除しますか？"),
                buttons: [
                    .default(Text("編集")) {
                        // 編集を選んだら、編集用のシートを開く準備をする
                        if let info = eventToEdit, let list = events[info.dateKey] {
                            let event = list[info.index]
                            editEventText = event.title
                            editEventStartTime = event.startTime
                            editEventEndTime = event.endTime
                            showEditSheet = true
                        }
                    },
                    .destructive(Text("削除")) {
                        // 削除を選んだら確認アラートを表示
                        eventToDelete = eventToEdit
                        showDeleteAlert = true
                    },
                    .cancel {
                        eventToEdit = nil
                    }
                ]
            )
        }

        // 予定編集のためのシート（保存・キャンセル）
        .sheet(isPresented: $showEditSheet) {
            VStack {
                Text("予定を編集")
                    .font(.headline)
                    .padding()
                TextField("予定を入力", text: $editEventText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                HStack {
                    VStack(alignment: .leading) {
                        Text("開始時間")
                            .font(.caption)
                        DatePicker("", selection: $editEventStartTime, displayedComponents: .hourAndMinute)
                    }
                    VStack(alignment: .leading) {
                        Text("終了時間")
                            .font(.caption)
                        DatePicker("", selection: $editEventEndTime, displayedComponents: .hourAndMinute)
                    }
                }
                .padding()
                HStack {
                    Button("キャンセル") {
                        // 編集を破棄して閉じる
                        showEditSheet = false
                        editEventText = ""
                        editEventStartTime = Date()
                        editEventEndTime = Date()
                        eventToEdit = nil
                    }
                    .padding()
                    Spacer()
                    Button("保存") {
                        // 編集内容を保持して iCal に保存
                        if let info = eventToEdit, !editEventText.isEmpty {
                            var list = events[info.dateKey] ?? []
                            list[info.index] = Event(title: editEventText, startTime: editEventStartTime, endTime: editEventEndTime)
                            events[info.dateKey] = list
                            saveEventsToICal()
                        }
                        showEditSheet = false
                        editEventText = ""
                        editEventStartTime = Date()
                        editEventEndTime = Date()
                        eventToEdit = nil
                    }
                    .foregroundColor(selectedThemeColor)
                    .padding()
                }
            }
            .padding()
        }

        // 検索画面をモーダルで表示
        .sheet(isPresented: $showSearchView) {
            EventSearchView(events: $events, selectedThemeColor: $selectedThemeColor)
        }

        // テーマ設定（色選択）をモーダルで表示
        .sheet(isPresented: $showThemeSettings) {
            VStack {
                Text("テーマカラーを選択")
                    .font(.headline)
                    .padding()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                    ForEach(Array(themeColors.enumerated()), id: \.offset) { index, color in
                        Circle()
                            .fill(color)
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(selectedThemeColorIndex == index ? Color.primary : Color.clear, lineWidth: 3))
                            .onTapGesture {
                                selectedThemeColorIndex = index
                                selectedThemeColor = color
                                saveThemeColor(index: index)
                            }
                    }
                }
                .padding()

                Button("完了") {
                    showThemeSettings = false
                }
                .foregroundColor(selectedThemeColor)
                .padding()
            }
            .padding()
        }

        // 削除確認アラート
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("予定の削除"),
                message: Text("この予定を削除しますか？"),
                primaryButton: .destructive(Text("削除")) {
                    if let info = eventToDelete, var list = events[info.dateKey] {
                        list.remove(at: info.index)
                        events[info.dateKey] = list.isEmpty ? nil : list
                        saveEventsToICal()
                    }
                    eventToDelete = nil
                },
                secondaryButton: .cancel {
                    eventToDelete = nil
                }
            )
        }
    }

    // ---------------- 補助関数（このアプリの内部で使う小さな処理） ----------------

    // monthYearString: Date を "YYYY年M月" 形式の文字列に変換して返す
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    // dateKey: 日付をキー用の文字列 ("yyyy-MM-dd") に変換する
    // これを使って events の辞書のキーを統一している
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // timeString: 時刻を "HH:mm" 形式で返す（表示用）
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // combine: 日付（年月日）と時間（時分）を組み合わせて 1 つの Date を作る
    // 例: date が 2025-12-19、time が 09:00 を表す Date の場合、出力は 2025-12-19 09:00
    private func combine(date: Date, time: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second ?? 0

        return calendar.date(from: combinedComponents) ?? date
    }

    // saveEventsToICal: 現在の events を iCal 形式で保存する（ファイルに書く）
    private func saveEventsToICal() {
        icalManager.saveEvents(events)
    }

    // changeMonth: 月を増減させる。呼ぶと currentDate が変わり表示が切り替わる。
    private func changeMonth(by value: Int) {
        if let nextDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = nextDate
            // 月を変えたときは日付選択をリセットする
            selectedDate = nil
        }
    }

    // loadThemeColor: 保存されているテーマのインデックスを読み出して色を復元する
    private func loadThemeColor() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: themeColorKey) != nil {
            let storedIndex = defaults.integer(forKey: themeColorKey)
            if themeColors.indices.contains(storedIndex) {
                selectedThemeColorIndex = storedIndex
                selectedThemeColor = themeColors[storedIndex]
                return
            }
        }
        // 保存がなければ最初の色を使う
        selectedThemeColorIndex = 0
        selectedThemeColor = themeColors.first ?? .blue
    }

    // saveThemeColor: 選んだテーマ色のインデックスを保存する
    private func saveThemeColor(index: Int) {
        UserDefaults.standard.set(index, forKey: themeColorKey)
    }
}

#Preview {
    ContentView()
}
