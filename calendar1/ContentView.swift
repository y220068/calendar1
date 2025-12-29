//
//  ContentView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

// このファイルは EventModel.swift で定義された共有 Event モデルを使用する
// Use shared Event model defined in EventModel.swift
// ContentView はアプリのメイン画面を表す SwiftUI ビュー
struct ContentView: View {
    // CategoryManager のシングルトンを StateObject として保持（カテゴリ一覧と永続化を管理）
    // Category manager for category list and persistence
    @StateObject private var categoryManager = CategoryManager.shared
    // カテゴリ設定シートの表示制御フラグ
    // Controls category settings sheet
    @State private var showCategorySettings = false

    // 現在表示している月の基準日（カレンダーの基準）
    @State private var currentDate = Date()
    // 選択中の日付（タップで予定一覧を表示するために保持）
    @State private var selectedDate: Date? = nil
    // 新規予定追加シート表示フラグ
    @State private var showAddEvent = false
    // 新規予定のタイトル入力バインディング
    @State private var newEventText = ""
    // 新規予定の開始時間
    @State private var newEventStartTime = Date()
    // 新規予定の終了時間
    @State private var newEventEndTime = Date()
    // 新規予定に紐付けるカテゴリID（任意）
    @State private var newEventCategoryID: String? = nil
    // 予定の保存データ（キーは日付文字列、値はその日の Event 配列）
    @State private var events: [String: [Event]] = [:] // 日付文字列: 予定リスト
    // 削除確認アラートの表示フラグ
    @State private var showDeleteAlert = false
    // 削除対象のイベント位置情報（dateKey と配列インデックス）
    @State private var eventToDelete: (dateKey: String, index: Int)? = nil
    // アクションシート（編集/削除選択）の表示フラグ
    @State private var showActionSheet = false
    // 編集対象の情報（dateKey とインデックス）
    @State private var eventToEdit: (dateKey: String, index: Int)? = nil
    // 編集用の入力状態（タイトル）
    @State private var editEventText = ""
    // 編集用の開始時間
    @State private var editEventStartTime = Date()
    // 編集用の終了時間
    @State private var editEventEndTime = Date()
    // 編集用のカテゴリID
    @State private var editEventCategoryID: String? = nil
    // 編集シート表示フラグ
    @State private var showEditSheet = false
    // 選択中のテーマカラー（UI のアクセント色）
    @State private var selectedThemeColor = Color.blue
    // 選択中のテーマカラーのインデックス（色一覧での位置）
    @State private var selectedThemeColorIndex = 0
    // 初期データが読み込まれたかどうかのフラグ（onAppear で一度実行）
    @State private var hasLoadedInitialData = false
    // テーマ設定シートの表示フラグ
    @State private var showThemeSettings = false
    // 検索画面の表示フラグ
    @State private var showSearchView = false
    
    // 利用可能なテーマカラー一覧（配列）
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
    
    // テーマカラーの保存キー（UserDefaults）
    private let themeColorKey = "selectedThemeColorIndex"
    // カレンダーインスタンス（ローカル）
    private var calendar: Calendar { Calendar.current }
    // iCalManager のインスタンス（予定の読み書きに使用）
    private let icalManager = ICalManager()
    // その月の日付配列を返す計算プロパティ
    private var daysInMonth: [Date] {
        // 当月の開始と終了の間隔を取得
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return [] }
        var dates: [Date] = []
        var date = monthInterval.start
        // 開始日から終了日まで 1 日ずつ追加
        while date < monthInterval.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return dates
    }
    // 月の最初の曜日番号（1 = 日曜日 等）
    private var firstWeekday: Int {
        calendar.component(.weekday, from: daysInMonth.first ?? Date())
    }
    // 曜日のラベル配列（日本語）
    private let weekDays = ["日", "月", "火", "水", "木", "金", "土"]
    
    // メインのビュー本体
    var body: some View {
        ZStack {
            // 背景のグラデーションを描画
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
                // ヘッダー: 月表示と操作ボタン群
                HStack(spacing: 12) {
                    // 前月ボタン（左）
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
                    
                    // 現在の月と年を表示するテキスト
                    Text(monthYearString(currentDate))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(selectedThemeColor)
                        .shadow(color: selectedThemeColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    // 翌月ボタン（右）
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
                        // 検索ボタン（虫眼鏡）
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
                        
                        // テーマ設定ボタン（筆アイコン）
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
                        
                        // カテゴリ設定ボタン（ヘッダー内）
                        Button(action: { showCategorySettings = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.white)
                                Text("カテゴリ")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(selectedThemeColor))
                        }
                     }
                 }
                 .padding(.top)
                 .padding(.horizontal)
                
                // カレンダーを囲むコンテナ（白背景のカード）
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
                    
                    // 日付グリッドを構築するための前後空白と日付ラベル生成
                    let leadingSpaces = Array(repeating: "", count: firstWeekday - 1)
                    let days = daysInMonth.map { String(calendar.component(.day, from: $0)) }
                    let allDays = leadingSpaces + days
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(0..<allDays.count, id: \ .self) { i in
                            let isDate = i >= leadingSpaces.count
                            let date = isDate ? daysInMonth[i - leadingSpaces.count] : nil
                            ZStack {
                                if isDate, let date = date {
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast)
                                    let isToday = calendar.isDateInToday(date)
                                    let dateKey = dateKey(date)
                                    // 表示対象のイベントをカテゴリフィルタを考慮して取得
                                    let dayEvents = visibleEvents(for: dateKey)

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
                                        
                                        // その日に含まれる予定を最大3件まで表示
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
                                    // 日付でないセルは透明文字で高さだけ確保
                                    Text(allDays[i])
                                        .foregroundColor(.clear)
                                        .frame(height: 50)
                                }
                            }
                            .onTapGesture {
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
                
                // 選択した日付の詳細な予定リスト表示（カテゴリフィルタを考慮）
                if let selectedDate = selectedDate {
                    let key = dateKey(selectedDate)
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("\(monthYearString(selectedDate)) \(calendar.component(.day, from: selectedDate))日の予定")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(selectedThemeColor)
                                .shadow(color: selectedThemeColor.opacity(0.3), radius: 1, x: 0, y: 1)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // カテゴリフィルタ後の表示イベントを取得
                        let visible = visibleEvents(for: key)
                        if !visible.isEmpty {
                            let sortedEvents = visible.sorted { $0.startTime < $1.startTime }
                            ForEach(sortedEvents.indices, id: \.self) { idx in
                                let event = sortedEvents[idx]
                                HStack {
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
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("・\(event.title)")
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        if let cname = categoryManager.name(for: event.categoryID) {
                                            Text(cname)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
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
                                    // 編集や削除のために元の保存先インデックスを特定
                                    if let originalList = events[key], let originalIndex = originalList.firstIndex(where: { $0.id == event.id }) {
                                        eventToEdit = (key, originalIndex)
                                        showActionSheet = true
                                    }
                                }
                            }
                        } else {
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
            // 初回表示時に iCal から予定を読み込み、テーマを復元
            if !hasLoadedInitialData {
                events = icalManager.loadEvents()
                loadThemeColor()
                hasLoadedInitialData = true
            }
        }
        .sheet(isPresented: $showAddEvent) {
            VStack {
                Text("予定を追加")
                    .font(.headline)
                    .padding()
                TextField("予定を入力", text: $newEventText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                // カテゴリ選択（任意）
                VStack(alignment: .leading) {
                    Text("カテゴリ（任意）").font(.caption).foregroundColor(.secondary)
                    Picker("カテゴリ", selection: Binding(get: { newEventCategoryID ?? "" }, set: { newEventCategoryID = $0.isEmpty ? nil : $0 })) {
                        Text("なし").tag("")
                        ForEach(categoryManager.categories) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal)
                }
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
                        showAddEvent = false
                        newEventText = ""
                        newEventStartTime = Date()
                        newEventEndTime = Date()
                        newEventCategoryID = nil
                    }
                    .padding()
                    Spacer()
                    Button("追加") {
                        if let selectedDate = selectedDate, !newEventText.isEmpty {
                            let key = dateKey(selectedDate)
                            let start = combine(date: selectedDate, time: newEventStartTime)
                            let end = combine(date: selectedDate, time: newEventEndTime)
                            let event = Event(title: newEventText, startTime: start, endTime: end, categoryID: newEventCategoryID)
                            if events[key] != nil {
                                events[key]?.append(event)
                                events[key]?.sort { $0.startTime < $1.startTime }
                            } else {
                                events[key] = [event]
                            }
                            saveEventsToICal()
                        }
                        showAddEvent = false
                        newEventText = ""
                        newEventStartTime = Date()
                        newEventEndTime = Date()
                        newEventCategoryID = nil
                    }
                    .foregroundColor(selectedThemeColor)
                    .padding()
                }
            }
            .padding()
        }
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
                            // 編集時にカテゴリを事前設定
                            editEventCategoryID = event.categoryID
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
        .sheet(isPresented: $showEditSheet) {
            VStack {
                Text("予定を編集")
                    .font(.headline)
                    .padding()
                TextField("予定を入力", text: $editEventText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                // カテゴリ選択（任意）
                VStack(alignment: .leading, spacing: 6) {
                    Text("カテゴリ（任意）").font(.caption).foregroundColor(.secondary)
                    Picker("カテゴリ", selection: Binding(get: { editEventCategoryID ?? "" }, set: { editEventCategoryID = $0.isEmpty ? nil : $0 })) {
                        Text("なし").tag("")
                        ForEach(categoryManager.categories) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal)
                }
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
                        showEditSheet = false
                        editEventText = ""
                        editEventStartTime = Date()
                        editEventEndTime = Date()
                        eventToEdit = nil
                    }
                    .padding()
                    Spacer()
                    Button("保存") {
                        if let info = eventToEdit, !editEventText.isEmpty {
                            var list = events[info.dateKey] ?? []
                            let oldID = list[info.index].id
                            let reconstructed = Event(id: oldID, title: editEventText, startTime: editEventStartTime, endTime: editEventEndTime, categoryID: editEventCategoryID)
                            list[info.index] = reconstructed
                            events[info.dateKey] = list
                            saveEventsToICal()
                        }
                        showEditSheet = false
                        editEventText = ""
                        editEventStartTime = Date()
                        editEventEndTime = Date()
                        eventToEdit = nil
                        editEventCategoryID = nil
                    }
                    .foregroundColor(selectedThemeColor)
                    .padding()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showSearchView) {
            EventSearchView(
                events: $events,
                selectedThemeColor: $selectedThemeColor
            )
        }
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
        // カテゴリ設定用シート
        .sheet(isPresented: $showCategorySettings) {
            CategorySettingsView(categories: $categoryManager.categories, selectedThemeColor: $selectedThemeColor)
        }
        
        // 右下に浮くカテゴリボタンのオーバーレイ
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showCategorySettings = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "tag") .foregroundColor(.white)
                    Text("カテゴリ") .foregroundColor(.white)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(selectedThemeColor))
                .shadow(radius: 6)
                .padding()
            }
            .zIndex(2)
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
    
    // 指定した日付キーに対してカテゴリのオン/オフフィルタを適用した後のイベントを返す
    // If an event has no category (nil), it is shown regardless of category toggles.
    private func visibleEvents(for dateKey: String) -> [Event] {
        guard let list = events[dateKey] else { return [] }
        // CategoryManager のヘルパーで有効なカテゴリIDのセットを構築（直接プロパティにアクセスしない）
        let enabledIDs = CategoryManager.enabledCategoryIDs()
        // もし有効なカテゴリが無ければ全て表示
        if enabledIDs.isEmpty { return list }
        // それ以外はカテゴリが nil の予定（未分類）または有効なカテゴリの予定のみを含める
        return list.filter { ev in
            guard let cid = ev.categoryID else { return true }
            return enabledIDs.contains(cid)
        }
    }
    
    // 指定した日付を "yyyy年M月" 形式で返す
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    // 日付のキーを "yyyy-MM-dd" 形式で返す（辞書のキーとして使用）
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 時刻を "HH:mm" 形式で返すヘルパー
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 日付と時刻を組み合わせて Date を生成するユーティリティ
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
    
    // 保存用のヘルパー: icalManager を呼んでイベントを iCal に保存
    private func saveEventsToICal() {
        icalManager.saveEvents(events)
    }
    
    // 月を切り替える（-1: 前月, +1: 翌月）
    private func changeMonth(by value: Int) {
        if let nextDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = nextDate
            // 月が変わったら選択日をリセット
            selectedDate = nil
        }
    }
    
    // 保存されているテーマカラーをロード（UserDefaults）
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
    
    // テーマカラー選択を保存
    private func saveThemeColor(index: Int) {
        UserDefaults.standard.set(index, forKey: themeColorKey)
    }
}

#Preview {
    ContentView()
}
