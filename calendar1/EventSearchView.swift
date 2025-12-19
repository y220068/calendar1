//
//  EventSearchView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

// このファイルは「予定を検索する画面」を実装しています。
// 初心者向けの説明：
// - 検索バーにキーワードを入力して、保存されている予定の中から該当するものを探します。
// - 「前方一致」「後方一致」「完全一致」「部分一致」を切り替えて検索方法を変えられます。
// - 類似語（SimilarWordsManager が管理）を使って、たとえば「会議」と入力すると「ミーティング」も一緒に検索する、という挙動をします。

import SwiftUI

// 検索モードの種類（ユーザーが選べる）
enum SearchMode: String, CaseIterable {
    case prefix = "前方一致"
    case suffix = "後方一致"
    case exact = "完全一致"
    case contains = "部分一致"
}

// EventSearchView の説明（非専門家向け）:
// - 検索欄に文字を入れると、少し遅延（0.3 秒）して検索を行います（タイプ中の連続検索を防ぐため）。
// - 類似語グループに含まれる単語も検索対象に拡張します（例: 会議 -> ミーティング など）。
// - 検索結果は「似た単語ごとにグループ化」して表示します。
struct EventSearchView: View {
    @Binding var events: [String: [Event]]
    @Binding var selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var similarWordsManager = SimilarWordsManager.shared

    @State private var searchText = ""
    @State private var searchResults: [EventGroup] = []
    @State private var isSearching = false
    @State private var showSimilarWordsSettings = false
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
                    if !searchText.isEmpty { performSearch(query: searchText) }
                }

                // 検索結果の表示
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
                        EventGroupSection(group: group, selectedThemeColor: selectedThemeColor)
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
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(selectedThemeColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSimilarWordsSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(selectedThemeColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showSimilarWordsSettings) {
            SimilarWordsSettingsView(similarWordsGroups: $similarWordsManager.similarWordsGroups, selectedThemeColor: $selectedThemeColor, onSelectWord: { word in
                // 類似語設定画面で単語を選ぶと、その単語で検索を実行する
                searchText = word
                performSearch(query: word)
                showSimilarWordsSettings = false
            })
        }
    }

    // performSearch: 入力されたキーワードで実際に検索を行う
    // - 空入力は無視
    // - 類似語グループを expand して検索語を増やす
    // - 検索は少し遅延させる（0.3 秒）
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let lowercaseQuery = query.lowercased()
            // 類似語グループにマッチしたらそのグループの単語すべてを検索対象にする
            let searchKeywords = similarWordsManager.findSimilarWords(for: lowercaseQuery).map { $0.lowercased() }

            var allEvents: [Event] = []
            for (_, eventList) in events {
                for event in eventList {
                    let eventTitle = event.title.lowercased()
                    if matchesEventTitle(eventTitle, keywords: searchKeywords) {
                        allEvents.append(event)
                    }
                }
            }
            // 見つかったイベントを「類似語単位」でグループ化して結果にする
            searchResults = groupSimilarEvents(allEvents, query: lowercaseQuery)
            isSearching = false
        }
    }

    // matchesEventTitle: 1 件のイベントタイトルがキーワードのどれかにマッチするか判定する
    private func matchesEventTitle(_ title: String, keywords: [String]) -> Bool {
        for keyword in keywords {
            let isMatch: Bool
            switch selectedSearchMode {
            case .prefix:
                isMatch = title.hasPrefix(keyword)
            case .suffix:
                isMatch = title.hasSuffix(keyword)
            case .exact:
                isMatch = title == keyword
            case .contains:
                isMatch = title.contains(keyword)
            }
            if isMatch { return true }
        }
        return false
    }

    // groupSimilarEvents: 見つかったイベントを「グループ名（類似語グループ or 抽出キーワード）」ごとにまとめる
    private func groupSimilarEvents(_ events: [Event], query: String) -> [EventGroup] {
        var groups: [String: [Event]] = [:]
        for event in events {
            let title = event.title.lowercased()
            let groupName = findBestGroupMatch(title: title, query: query)
            groups[groupName, default: []].append(event)
        }
        return groups.map { key, events in
            EventGroup(id: key, keyword: key, events: events.sorted { $0.startTime < $1.startTime })
        }.sorted { $0.keyword < $1.keyword }
    }

    // findBestGroupMatch: イベントタイトルから最もふさわしいグループ名（またはキーワード）を決める
    // 1) まず SimilarWordsManager のグループに含まれる単語がタイトルにあればそのグループ名を返す
    // 2) 次にキーワード抽出を行い、最も近いキーワードを選ぶ
    private func findBestGroupMatch(title: String, query: String) -> String {
        let lowercaseQuery = query.lowercased()
        for group in similarWordsManager.similarWordsGroups {
            for word in group.words {
                if title.contains(word.lowercased()) { return group.name }
            }
            for word in group.words {
                if word.lowercased() == lowercaseQuery { return group.name }
            }
        }
        let keywords = extractKeywords(from: title)
        let bestMatch = findBestMatch(keywords: keywords, query: lowercaseQuery)
        if keywords.contains(lowercaseQuery) { return lowercaseQuery }
        return bestMatch
    }

    // extractKeywords: タイトルから助詞や記号を取り除いて意味のある語を抜き出す
    // （簡易的な処理で完全ではありませんが、検索用の候補を作るのに使います）
    private func extractKeywords(from title: String) -> [String] {
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
        return cleanedTitle.components(separatedBy: " ").filter { !$0.isEmpty && $0.count > 1 }
    }

    // findBestMatch: 複数の候補キーワードからクエリに最も近いものを探す
    // - 完全一致を優先
    // - 部分一致を次に優先
    // - 最後にレーベンシュタイン距離（編集距離）で類似度計算をして最良候補を返す
    private func findBestMatch(keywords: [String], query: String) -> String {
        for keyword in keywords { if keyword == query { return keyword } }
        for keyword in keywords { if keyword.contains(query) || query.contains(keyword) { return keyword } }
        var bestMatch = keywords.first ?? query
        var bestScore = calculateSimilarity(query, keywords.first ?? "")
        for keyword in keywords {
            let score = calculateSimilarity(query, keyword)
            if score > bestScore { bestScore = score; bestMatch = keyword }
        }
        return bestMatch
    }

    // calculateSimilarity / levenshteinDistance: 文字列の類似度を計算する（補助関数）
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        if longer.isEmpty { return 1.0 }
        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }

    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let a = Array(str1)
        let b = Array(str2)
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { matrix[i][0] = i }
        for j in 0...b.count { matrix[0][j] = j }
        for i in 1...a.count { for j in 1...b.count {
            if a[i-1] == b[j-1] { matrix[i][j] = matrix[i-1][j-1] }
            else { matrix[i][j] = min(matrix[i-1][j], matrix[i][j-1], matrix[i-1][j-1]) + 1 }
        }}
        return matrix[a.count][b.count]
    }
}

// EventGroup: 検索結果をグループ化して扱うための構造体
struct EventGroup: Identifiable {
    let id: String
    let keyword: String
    let events: [Event]
}

// EventGroupSection: グループ（キーワード単位）を折りたたみ可能に表示するビュー
struct EventGroupSection: View {
    let group: EventGroup
    let selectedThemeColor: Color
    @State private var isExpanded = true
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Text(group.keyword).font(.headline).fontWeight(.bold).foregroundColor(selectedThemeColor)
                    Spacer()
                    Text("\(group.events.count)件").font(.caption).foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.caption).foregroundColor(selectedThemeColor)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.1), radius: 2, x: 0, y: 1))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.events) { event in
                        EventSearchResultRow(event: event, selectedThemeColor: selectedThemeColor)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
}

// EventSearchResultRow: 検索結果の1行表示（日時・タイトル・今日/明日マークなど）
struct EventSearchResultRow: View {
    let event: Event
    let selectedThemeColor: Color
    private var calendar: Calendar { Calendar.current }
    var body: some View {
        HStack(spacing: 15) {
            VStack(spacing: 4) {
                Text(dayString(event.startTime)).font(.caption).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 6).fill(selectedThemeColor))
                Text(monthString(event.startTime)).font(.caption2).foregroundColor(.gray)
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline).fontWeight(.semibold).foregroundColor(.primary).lineLimit(2)
                HStack { Image(systemName: "clock").font(.caption).foregroundColor(selectedThemeColor); Text("\(timeString(event.startTime)) - \(timeString(event.endTime))").font(.caption).foregroundColor(.secondary) }
                if calendar.isDateInToday(event.startTime) { HStack { Image(systemName: "star.fill").font(.caption2).foregroundColor(.orange); Text("今日").font(.caption2).foregroundColor(.orange).fontWeight(.medium) } }
                else if calendar.isDateInTomorrow(event.startTime) { HStack { Image(systemName: "star.fill").font(.caption2).foregroundColor(.blue); Text("明日").font(.caption2).foregroundColor(.blue).fontWeight(.medium) } }
            }

            Spacer()
        }
        .padding(.vertical, 8).padding(.horizontal, 12).background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.1), radius: 2, x: 0, y: 1))
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.dateFormat = "d"; return formatter.string(from: date)
    }
    private func monthString(_ date: Date) -> String { let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.dateFormat = "M月"; return formatter.string(from: date) }
    private func timeString(_ date: Date) -> String { let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ja_JP"); formatter.dateFormat = "HH:mm"; return formatter.string(from: date) }
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
