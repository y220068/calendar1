//
//  EventSearchView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

enum SearchMode: String, CaseIterable {
    case prefix = "前方一致"
    case suffix = "後方一致"
    case exact = "完全一致"
    case contains = "部分一致"
}

struct EventSearchView: View {
    @Binding var events: [String: [Event]]
    @Binding var selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var similarWordsManager = SimilarWordsManager.shared
    
    @State private var searchText = ""
    @State private var searchResults: [EventGroup] = []
    @State private var isSearching = false
    @State private var selectedSearchMode: SearchMode = .contains
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(selectedThemeColor)
                        .font(.title2)
                    
                    TextField("予定を検索...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button("クリア") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(selectedThemeColor)
                    }
                }
                .padding()
                
                // 検索モード選択
                Picker("検索モード", selection: $selectedSearchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedSearchMode) { _ in
                    if !searchText.isEmpty {
                        performSearch(query: searchText)
                    }
                }
                
                // 検索結果
                if isSearching {
                    ProgressView("検索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(selectedThemeColor.opacity(0.5))
                        
                        Text("検索結果が見つかりません")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("別のキーワードで検索してみてください")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(selectedThemeColor.opacity(0.5))
                        
                        Text("予定を検索")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("検索バーにキーワードを入力してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { group in
                        EventGroupSection(
                            group: group,
                            selectedThemeColor: selectedThemeColor
                        )
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("予定検索")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(selectedThemeColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SimilarWordsSettingsView(
                        similarWordsGroups: $similarWordsManager.similarWordsGroups,
                        selectedThemeColor: $selectedThemeColor
                    )) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(selectedThemeColor)
                    }
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // 検索を少し遅延させて、ユーザーが入力中に頻繁に検索が実行されるのを防ぐ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let lowercaseQuery = query.lowercased()
            
            var allEvents: [Event] = []
            
            // 全ての予定を検索
            for (_, eventList) in events {
                for event in eventList {
                    let eventTitle = event.title.lowercased()
                    var matches = false
                    
                    switch selectedSearchMode {
                    case .prefix:
                        // 前方一致
                        matches = eventTitle.hasPrefix(lowercaseQuery)
                    case .suffix:
                        // 後方一致
                        matches = eventTitle.hasSuffix(lowercaseQuery)
                    case .exact:
                        // 完全一致
                        matches = eventTitle == lowercaseQuery
                    case .contains:
                        // 部分一致
                        matches = eventTitle.contains(lowercaseQuery)
                    }
                    
                    if matches {
                        allEvents.append(event)
                    }
                }
            }
            
            // 類似単語でグループ化
            searchResults = groupSimilarEvents(allEvents, query: lowercaseQuery)
            isSearching = false
        }
    }
    
    private func groupSimilarEvents(_ events: [Event], query: String) -> [EventGroup] {
        var groups: [String: [Event]] = [:]
        
        for event in events {
            let title = event.title.lowercased()
            
            // カスタム類似単語を使用してグループ化
            let groupName = findBestGroupMatch(title: title, query: query)
            
            if groups[groupName] == nil {
                groups[groupName] = []
            }
            groups[groupName]?.append(event)
        }
        
        // グループをソートして返す
        return groups.map { key, events in
            EventGroup(
                id: key,
                keyword: key,
                events: events.sorted { $0.startTime < $1.startTime }
            )
        }.sorted { $0.keyword < $1.keyword }
    }
    
    private func findBestGroupMatch(title: String, query: String) -> String {
        let lowercaseQuery = query.lowercased()
        
        // まず、カスタム類似単語グループをチェック
        for group in similarWordsManager.similarWordsGroups {
            // タイトルにグループ内の単語が含まれているかチェック
            for word in group.words {
                if title.contains(word.lowercased()) {
                    return group.name
                }
            }
            
            // クエリがグループ内の単語と一致するかチェック
            for word in group.words {
                if word.lowercased() == lowercaseQuery {
                    return group.name
                }
            }
        }
        
        // カスタムグループにマッチしない場合は、従来のロジックを使用
        let keywords = extractKeywords(from: title)
        let bestMatch = findBestMatch(keywords: keywords, query: lowercaseQuery)
        
        // クエリ自体がキーワードに含まれている場合は、そのキーワードを返す
        if keywords.contains(lowercaseQuery) {
            return lowercaseQuery
        }
        
        return bestMatch
    }
    
    private func extractKeywords(from title: String) -> [String] {
        // 日本語の助詞や記号を除去してキーワードを抽出
        let cleanedTitle = title
            .replacingOccurrences(of: "の", with: " ")
            .replacingOccurrences(of: "を", with: " ")
            .replacingOccurrences(of: "に", with: " ")
            .replacingOccurrences(of: "で", with: " ")
            .replacingOccurrences(of: "と", with: " ")
            .replacingOccurrences(of: "は", with: " ")
            .replacingOccurrences(of: "が", with: " ")
            .replacingOccurrences(of: "、", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: "・", with: " ")
            .replacingOccurrences(of: " ", with: " ")
        
        return cleanedTitle.components(separatedBy: " ")
            .filter { !$0.isEmpty && $0.count > 1 }
    }
    
    private func findBestMatch(keywords: [String], query: String) -> String {
        // 完全一致を優先
        for keyword in keywords {
            if keyword == query {
                return keyword
            }
        }
        
        // 部分一致を探す
        for keyword in keywords {
            if keyword.contains(query) || query.contains(keyword) {
                return keyword
            }
        }
        
        // 類似度が高いキーワードを探す
        var bestMatch = keywords.first ?? query
        var bestScore = calculateSimilarity(query, keywords.first ?? "")
        
        for keyword in keywords {
            let score = calculateSimilarity(query, keyword)
            if score > bestScore {
                bestScore = score
                bestMatch = keyword
            }
        }
        
        return bestMatch
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty {
            return 1.0
        }
        
        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let a = Array(str1)
        let b = Array(str2)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(matrix[i-1][j], matrix[i][j-1], matrix[i-1][j-1]) + 1
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
}

struct EventGroup: Identifiable {
    let id: String
    let keyword: String
    let events: [Event]
}

struct EventGroupSection: View {
    let group: EventGroup
    let selectedThemeColor: Color
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // グループヘッダー
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(group.keyword)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(selectedThemeColor)
                    
                    Spacer()
                    
                    Text("\(group.events.count)件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedThemeColor.opacity(0.1))
                        )
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(selectedThemeColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: selectedThemeColor.opacity(0.1), radius: 2, x: 0, y: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // イベントリスト
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.events) { event in
                        EventSearchResultRow(
                            event: event,
                            selectedThemeColor: selectedThemeColor
                        )
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
}

struct EventSearchResultRow: View {
    let event: Event
    let selectedThemeColor: Color
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        HStack(spacing: 15) {
            // 日付表示
            VStack(spacing: 4) {
                Text(dayString(event.startTime))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedThemeColor)
                    )
                
                Text(monthString(event.startTime))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 50)
            
            // 予定情報
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(selectedThemeColor)
                    
                    Text("\(timeString(event.startTime)) - \(timeString(event.endTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if calendar.isDateInToday(event.startTime) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("今日")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                } else if calendar.isDateInTomorrow(event.startTime) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("明日")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: selectedThemeColor.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func monthString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
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
    EventSearchView(
        events: .constant([
            "2025-05-10": [
                Event(title: "会議", startTime: Date(), endTime: Date().addingTimeInterval(3600)),
                Event(title: "重要な会議", startTime: Date().addingTimeInterval(7200), endTime: Date().addingTimeInterval(10800)),
                Event(title: "ミーティング", startTime: Date().addingTimeInterval(14400), endTime: Date().addingTimeInterval(18000))
            ]
        ]),
        selectedThemeColor: .constant(.blue)
    )
}
