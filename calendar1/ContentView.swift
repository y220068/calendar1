//
//  ContentView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

// Event 構造体: カレンダー上の1つの予定を表現するモデル
// Identifiable に準拠して List / ForEach で利用可能にしている
struct Event: Identifiable {
    // 一意の識別子
    let id = UUID()
    // 予定のタイトル
    var title: String
    // 開始時刻
    var startTime: Date
    // 終了時刻
    var endTime: Date
}

// ContentView: アプリのメイン画面。月表示のカレンダー、日ごとの予定表示、予定の追加・編集・削除、テーマ設定、検索を提供する。
struct ContentView: View {
    // --- State / ViewModel 相当のプロパティ ---
    // 現在表示中の基準日（この月を表示するために用いる）
    @State private var currentDate = Date()
    // 選択された日付（予定表示 / 追加対象となる）
    @State private var selectedDate: Date? = nil
    // 予定追加用のモーダル表示フラグ
    @State private var showAddEvent = false
    // 追加する予定のタイトル
    @State private var newEventText = ""
    // 追加する予定の開始/終了時刻（時間部分のみ利用）
    @State private var newEventStartTime = Date()
    @State private var newEventEndTime = Date()
    // 予定の格納: 日付キー ("yyyy-MM-dd") -> Event 配列
    @State private var events: [String: [Event]] = [:] // 日付文字列: 予定リスト
    // 削除アラート表示フラグ
    @State private var showDeleteAlert = false
    // 削除対象の特定情報(日付キーと配列内インデックス)
    @State private var eventToDelete: (dateKey: String, index: Int)? = nil
    // 予定操作用アクションシート表示フラグ
    @State private var showActionSheet = false
    // 編集対象の特定情報
    @State private var eventToEdit: (dateKey: String, index: Int)? = nil
    // 編集用の入力状態
    @State private var editEventText = ""
    @State private var editEventStartTime = Date()
    @State private var editEventEndTime = Date()
    @State private var showEditSheet = false
    // テーマカラー関連の状態
    @State private var selectedThemeColor = Color.blue
    @State private var selectedThemeColorIndex = 0
    // 初回データ読込フラグ（onAppear で一度だけロードする）
    @State private var hasLoadedInitialData = false
    // テーマ設定モーダル、検索画面フラグ
    @State private var showThemeSettings = false
    @State private var showSearchView = false
    
    // 利用可能なテーマカラー配列（カラーパレット）
    private let themeColors: [Color] = [
        .blue, .red, .green, .orange, .purple, .pink, .teal, .indigo,
        .mint, .cyan, .brown, .yellow, .gray,
        Color(red: 0.2, green: 0.6, blue: 0.8), // スカイブルー
        Color(red: 0.4, green: 0.8, blue: 0.4), // エメラルドグリーン
        Color(red: 0.8, green: 0.4, blue: 0.2), // コーラル
        Color(red: 0.6, green: 0.4, blue: 0.8), // ラベンダー
        Color(red: 0.8, green: 0.6, blue: 0.4), // サルモン
        Color(red: 0.4, green: 0.6, blue: 0.8), // コーンフラワーブルー
        Color(red: 0.8, green: 0.4, blue: 0.6), // ローズピンク
        Color(red: 0.6, green: 0.8, blue: 0.4), // ライトグリーン
        Color(red: 0.8, green: 0.6, blue: 0.2), // ゴールド
        Color(red: 0.4, green: 0.4, blue: 0.8), // パープルブルー
        Color(red: 0.8, green: 0.2, blue: 0.4), // ディープローズ
        Color(red: 0.2, green: 0.8, blue: 0.6), // ターコイズ
        Color(red: 0.8, green: 0.4, blue: 0.8), // マゼンタ
        Color(red: 0.6, green: 0.2, blue: 0.8), // バイオレット
        Color(red: 0.8, green: 0.8, blue: 0.4), // ライトイエロー
        Color(red: 0.4, green: 0.8, blue: 0.8)  // ライトシアン
    ]
    
    // UserDefaults に保存するキー（選択したテーマ色のインデックス）
    private let themeColorKey = "selectedThemeColorIndex"
    // カレンダー情報（現在のロケールのカレンダ）
    private var calendar: Calendar { Calendar.current }
    // iCal 読み書き用のユーティリティ
    private let icalManager = ICalManager()
    
    // 現在の currentDate の月に含まれる全ての日付配列を作って返す computed property
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
    // 月の最初の日の曜日（1=日曜, 2=月曜, ...）を返す
    private var firstWeekday: Int {
        calendar.component(.weekday, from: daysInMonth.first ?? Date())
    }
    // 曜日のラベル（日本語）
    private let weekDays = ["日", "月", "火", "水", "木", "金", "土"]
    
    // ビュー本体
    var body: some View {
        ZStack {
            // 背景グラデーション: テーマ色を薄く使った柔らかい背景
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
                // ヘッダー（年月、月移動ボタン、検索・テーマボタン）
                HStack(spacing: 12) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(selectedThemeColor)
                            .font(.title2)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(selectedThemeColor.opacity(0.1))
                            )
                    }
                    
                    Text(monthYearString(currentDate))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(selectedThemeColor)
                        .shadow(color: selectedThemeColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(selectedThemeColor)
                            .font(.title2)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(selectedThemeColor.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // 検索ボタン: 押すと検索ビューをモーダルで開く
                        Button(action: {
                            showSearchView = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(selectedThemeColor.opacity(0.8))
                                        .shadow(color: selectedThemeColor.opacity(0.4), radius: 4, x: 0, y: 2)
                                )
                        }
                        
                        // テーマ設定ボタン: カラーピッカー的なモーダルを開く
                        Button(action: {
                            showThemeSettings = true
                        }) {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(selectedThemeColor)
                                        .shadow(color: selectedThemeColor.opacity(0.4), radius: 4, x: 0, y: 2)
                                )
                        }
                    }
                }
                .padding(.top)
                .padding(.horizontal)
                
                // カレンダーコンテナ
                VStack(spacing: 0) {
                    // 曜日表示行
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
                    
                    // 日付グリッド生成のための配列準備
                    let leadingSpaces = Array(repeating: "", count: firstWeekday - 1)
                    let days = daysInMonth.map { String(calendar.component(.day, from: $0)) }
                    let allDays = leadingSpaces + days
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(0..<allDays.count, id: \ .self) { i in
                            let isDate = i >= leadingSpaces.count
                            let date = isDate ? daysInMonth[i - leadingSpaces.count] : nil
                            ZStack {
                                if isDate, let date = date {
                                    // セルの選択状態 / 今日判定 / 当日のイベント取得
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast)
                                    let isToday = calendar.isDateInToday(date)
                                    let dateKey = dateKey(date)
                                    let dayEvents = events[dateKey] ?? []
                                    
                                    // セルの背景（選択 or 今日で色分け）
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            isSelected ? selectedThemeColor.opacity(0.4) :
                                            isToday ? selectedThemeColor.opacity(0.2) : Color.white
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    isSelected ? selectedThemeColor : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .shadow(
                                            color: isSelected ? selectedThemeColor.opacity(0.3) : Color.black.opacity(0.1),
                                            radius: isSelected ? 6 : 2,
                                            x: 0,
                                            y: isSelected ? 3 : 1
                                        )
                                        .frame(height: 50)
                                    
                                    VStack(spacing: 2) {
                                        Text(allDays[i])
                                            .fontWeight(isToday ? .bold : .semibold)
                                            .font(.system(size: 16))
                                            .foregroundColor(
                                                isSelected ? .white :
                                                (i % 7 == 0) ? .red : (i % 7 == 6 ? .blue : .primary)
                                            )
                                        
                                        // その日の予定を最大3件まで表示し、超過があれば +N 表示する
                                        if !dayEvents.isEmpty {
                                            VStack(spacing: 1) {
                                                ForEach(0..<min(dayEvents.count, 3), id: \.self) { idx in
                                                    let event = dayEvents[idx]
                                                    Text(event.title)
                                                        .font(.system(size: 8))
                                                        .fontWeight(.medium)
                                                        .foregroundColor(
                                                            isSelected ? .white :
                                                            selectedThemeColor
                                                        )
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                }
                                                if dayEvents.count > 3 {
                                                    Text("+\(dayEvents.count - 3)")
                                                        .font(.system(size: 7))
                                                        .foregroundColor(
                                                            isSelected ? .white :
                                                            selectedThemeColor
                                                        )
                                                        .fontWeight(.bold)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // 月の前後の空セル（見た目揃え用）
                                    Text(allDays[i])
                                        .foregroundColor(.clear)
                                        .frame(height: 50)
                                }
                            }
                            .onTapGesture {
                                // 日付セルをタップすると選択して予定追加モーダルを開く
                                if isDate, let date = date {
                                    selectedDate = date
                                    showAddEvent = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: selectedThemeColor.opacity(0.3), radius: 15, x: 0, y: 8)
                )
                .padding(.horizontal)
                
                // 選択した日の予定一覧表示エリア
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
                            // 日付に登録された予定を開始時間でソートして表示
                            let sortedEvents = eventList.sorted { $0.startTime < $1.startTime }
                            ForEach(sortedEvents.indices, id: \ .self) { idx in
                                let event = sortedEvents[idx]
                                HStack {
                                    // 時刻ラベル（開始-終了）
                                    Text("\(timeString(event.startTime))-\(timeString(event.endTime))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedThemeColor)
                                                .shadow(color: selectedThemeColor.opacity(0.4), radius: 2, x: 0, y: 1)
                                        )
                                    
                                    // タイトル
                                    Text("・\(event.title)")
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: selectedThemeColor.opacity(0.2), radius: 4, x: 0, y: 2)
                                )
                                .onTapGesture {
                                    // 元のリストでのインデックスを取得して編集対象にセット
                                    if let originalIndex = eventList.firstIndex(where: { $0.id == event.id }) {
                                        eventToEdit = (key, originalIndex)
                                        showActionSheet = true
                                    }
                                }
                            }
                        } else {
                            // 予定がない場合のプレースホルダ表示
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
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: selectedThemeColor.opacity(0.15), radius: 3, x: 0, y: 1)
                            )
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            // 初回表示時に iCal から予定をロードし、テーマを復元する
            if !hasLoadedInitialData {
                events = icalManager.loadEvents()
                loadThemeColor()
                hasLoadedInitialData = true
            }
        }
        // 予定追加のモーダル
        .sheet(isPresented: $showAddEvent) {
            VStack {
                Text("予定を追加")
                    .font(.headline)
                    .padding()
                TextField("予定を入力", text: $newEventText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
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
                HStack {
                    Button("キャンセル") {
                        // 入力を破棄してモーダルを閉じる
                        showAddEvent = false
                        newEventText = ""
                        newEventStartTime = Date()
                        newEventEndTime = Date()
                    }
                    .padding()
                    Spacer()
                    Button("追加") {
                        // 選択日があり、タイトルが空でなければイベントを追加
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
                        // モーダルを閉じて入力リセット
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
        // 予定の操作（編集 / 削除）用アクションシート
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("予定の操作"),
                message: Text("この予定を編集または削除しますか？"),
                buttons: [
                    .default(Text("編集")) {
                        if let info = eventToEdit, let list = events[info.dateKey] {
                            let event = list[info.index]
                            editEventText = event.title
                            editEventStartTime = event.startTime
                            editEventEndTime = event.endTime
                            showEditSheet = true
                        }
                    },
                    .destructive(Text("削除")) {
                        eventToDelete = eventToEdit
                        showDeleteAlert = true
                    },
                    .cancel {
                        eventToEdit = nil
                    }
                ]
            )
        }
        // 編集用モーダル
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
                        // 編集内容を保存して iCal に書き出す
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
        // 検索画面モーダル
        .sheet(isPresented: $showSearchView) {
            EventSearchView(
                events: $events,
                selectedThemeColor: $selectedThemeColor
            )
        }
        // テーマ設定モーダル
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
                            .overlay(
                                Circle()
                                    .stroke(selectedThemeColorIndex == index ? Color.primary : Color.clear, lineWidth: 3)
                            )
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
    
    // --- ユーティリティ関数群 ---
    // 月年を日本語フォーマットで返す
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    // 日付キー (yyyy-MM-dd) を生成する
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 時刻を HH:mm 形式で返す
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 日付（Y/M/D）と時間（H:M）を組み合わせて1つの Date を作る
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
    
    // iCal に保存するラッパー
    private func saveEventsToICal() {
        icalManager.saveEvents(events)
    }
    
    // 月を変更するヘルパー。月を変更したら日付選択をリセットする
    private func changeMonth(by value: Int) {
        if let nextDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = nextDate
            // 月を変えたときは日付選択をリセット
            selectedDate = nil
        }
    }
    
    // 保存済みのテーマ色を UserDefaults から読み込む
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
        selectedThemeColorIndex = 0
        selectedThemeColor = themeColors.first ?? .blue
    }
    
    // 選択したテーマ色インデックスを保存
    private func saveThemeColor(index: Int) {
        UserDefaults.standard.set(index, forKey: themeColorKey)
    }
}

#Preview {
    ContentView()
}
