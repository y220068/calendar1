//
//  ContentView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

struct Event: Identifiable {
    let id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
}

struct ContentView: View {
    @State private var currentDate = Date()
    @State private var selectedDate: Date? = nil
    @State private var showAddEvent = false
    @State private var newEventText = ""
    @State private var newEventStartTime = Date()
    @State private var newEventEndTime = Date()
    @State private var events: [String: [Event]] = [:] // 日付文字列: 予定リスト
    @State private var showDeleteAlert = false
    @State private var eventToDelete: (dateKey: String, index: Int)? = nil
    @State private var showActionSheet = false
    @State private var eventToEdit: (dateKey: String, index: Int)? = nil
    @State private var editEventText = ""
    @State private var editEventStartTime = Date()
    @State private var editEventEndTime = Date()
    @State private var showEditSheet = false
    @State private var selectedThemeColor = Color.blue
    @State private var showThemeSettings = false
    @State private var showSearchView = false
    
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
    
    private var calendar: Calendar { Calendar.current }
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
    private var firstWeekday: Int {
        calendar.component(.weekday, from: daysInMonth.first ?? Date())
    }
    private let weekDays = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        ZStack {
            // 背景グラデーション
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
                // ヘッダー（月表示とボタン群）
                HStack {
                    Text(monthYearString(currentDate))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(selectedThemeColor)
                        .shadow(color: selectedThemeColor.opacity(0.3), radius: 2, x: 0, y: 1)
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // 検索ボタン
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
                        
                        // テーマ設定ボタン
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
                    // 曜日表示
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
                    
                    // 日付グリッド
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
                                    let dayEvents = events[dateKey] ?? []
                                    
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
                                        
                                        // 予定の表示（最大3件）
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
                
                // 選択した日付の予定表示
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
                        
                        if let eventList = events[key], !eventList.isEmpty {
                            let sortedEvents = eventList.sorted { $0.startTime < $1.startTime }
                            ForEach(sortedEvents.indices, id: \ .self) { idx in
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
                                    // 元のリストでのインデックスを取得
                                    if let originalIndex = eventList.firstIndex(where: { $0.id == event.id }) {
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
                        showAddEvent = false
                        newEventText = ""
                        newEventStartTime = Date()
                        newEventEndTime = Date()
                    }
                    .padding()
                    Spacer()
                    Button("追加") {
                        if let selectedDate = selectedDate, !newEventText.isEmpty {
                            let key = dateKey(selectedDate)
                            let event = Event(title: newEventText, startTime: newEventStartTime, endTime: newEventEndTime)
                            if events[key] != nil {
                                events[key]?.append(event)
                            } else {
                                events[key] = [event]
                            }
                        }
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
                            list[info.index] = Event(title: editEventText, startTime: editEventStartTime, endTime: editEventEndTime)
                            events[info.dateKey] = list
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
                    ForEach(themeColors, id: \ .self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(selectedThemeColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedThemeColor = color
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
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("予定の削除"),
                message: Text("この予定を削除しますか？"),
                primaryButton: .destructive(Text("削除")) {
                    if let info = eventToDelete, var list = events[info.dateKey] {
                        list.remove(at: info.index)
                        events[info.dateKey] = list.isEmpty ? nil : list
                    }
                    eventToDelete = nil
                },
                secondaryButton: .cancel {
                    eventToDelete = nil
                }
            )
        }
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
    
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
