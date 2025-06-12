//
//  ContentView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

struct ContentView: View {
    @State private var currentDate = Date()
    @State private var selectedDate: Date? = nil
    @State private var showAddEvent = false
    @State private var newEventText = ""
    @State private var events: [String: [String]] = [:] // 日付文字列: 予定リスト
    
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
        VStack {
            // 月と年の表示
            Text(monthYearString(currentDate))
                .font(.title)
                .padding(.top)
            // 曜日表示
            HStack {
                ForEach(weekDays, id: \ .self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .primary))
                }
            }
            // 日付グリッド
            let leadingSpaces = Array(repeating: "", count: firstWeekday - 1)
            let days = daysInMonth.map { String(calendar.component(.day, from: $0)) }
            let allDays = leadingSpaces + days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(0..<allDays.count, id: \ .self) { i in
                    let isDate = i >= leadingSpaces.count
                    let date = isDate ? daysInMonth[i - leadingSpaces.count] : nil
                    ZStack {
                        if isDate, let date = date {
                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast)
                            Circle()
                                .fill(isSelected ? Color.blue.opacity(0.3) : Color.clear)
                                .frame(width: 36, height: 36)
                        }
                        Text(allDays[i])
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundColor((i % 7 == 0) ? .red : (i % 7 == 6 ? .blue : .primary))
                    }
                    .onTapGesture {
                        if isDate, let date = date {
                            selectedDate = date
                            showAddEvent = true
                        }
                    }
                }
            }
            // 選択した日付の予定表示
            if let selectedDate = selectedDate {
                let key = dateKey(selectedDate)
                VStack(alignment: .leading) {
                    Text("\(monthYearString(selectedDate)) \(calendar.component(.day, from: selectedDate))日の予定")
                        .font(.headline)
                        .padding(.top)
                    if let eventList = events[key], !eventList.isEmpty {
                        ForEach(eventList, id: \ .self) { event in
                            Text("・" + event)
                        }
                    } else {
                        Text("予定はありません")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showAddEvent) {
            VStack {
                Text("予定を追加")
                    .font(.headline)
                    .padding()
                TextField("予定を入力", text: $newEventText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                HStack {
                    Button("キャンセル") {
                        showAddEvent = false
                        newEventText = ""
                    }
                    .padding()
                    Spacer()
                    Button("追加") {
                        if let selectedDate = selectedDate, !newEventText.isEmpty {
                            let key = dateKey(selectedDate)
                            if events[key] != nil {
                                events[key]?.append(newEventText)
                            } else {
                                events[key] = [newEventText]
                            }
                        }
                        showAddEvent = false
                        newEventText = ""
                    }
                    .padding()
                }
            }
            .padding()
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
}

#Preview {
    ContentView()
}
