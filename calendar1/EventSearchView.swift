//
//  EventSearchView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import SwiftUI

// ========================================
// 検索画面：キーワード入力、検索モード選択、結果表示
// ========================================
// - 変更点：レーベンシュタイン距離による類似度を廃止し、
//   SimilarWordsManager の類義語グループに基づく簡潔な判定に置き換えています。

// ========================================
// enum SearchMode
// ========================================
// - 検索方法の種類を定義する列挙型。
// - CaseIterable: 全ケースをループ可能に（PickerStyle などで使用）。

enum SearchMode: String, CaseIterable {
    // ========================================
    // prefix: 前方一致
    // ========================================
    // - 予定のタイトルが入力キーワードで始まる場合にマッチ。
    // - 例: "会議" で「会議開始」「会議予定」がマッチ。
    case prefix = "前方一致"
    
    // ========================================
    // suffix: 後方一致
    // ========================================
    // - タイトルが入力キーワードで終わる場合にマッチ。
    // - 例: "会議" で「午前の会議」「定例会議」がマッチ。
    case suffix = "後方一致"
    
    // ========================================
    // exact: 完全一致
    // ========================================
    // - タイトルが入力キーワードと完全に一致する場合のみマッチ。
    // - 例: "会議" で「会議」のみマッチ。「会議室予約」はマッチしない。
    case exact = "完全一致"
    
    // ========================================
    // contains: 部分一致
    // ========================================
    // - タイトルに入力キーワードが含まれる場合にマッチ。
    // - 例: "会議" で「午前の会議開始」「会議室確保」がマッチ。
    case contains = "部分一致"
    
    // ========================================
    // synonym: 類義語一致
    // ========================================
    // - SimilarWordsManager で定義された類義語グループをマッチ。
    // - 例: "会議" の類義語「ミーティング」「打ち合わせ」もマッチ。
    case synonym = "類義語一致"
}

// ========================================
// EventSearchView 構造体
// ========================================
// - 検索機能を提供するビュー。
// - 検索バー、モード選択、結果表示からなる。

struct EventSearchView: View {
    // ========================================
    // @Binding var events
    // ========================================
    // - 親ビュー（ContentView）の全イベント辞書への参照。
    // - ここでは読み取り専用で使用（編集しない）。
    @Binding var events: [String: [Event]]
    
    // ========================================
    // @Binding var selectedThemeColor
    // ========================================
    // - テーマカラー。
    @Binding var selectedThemeColor: Color
    
    // ========================================
    // @Environment(\.presentationMode)
    // ========================================
    // - このビューを閉じるための環境値。
    @Environment(\.presentationMode) var presentationMode
    
    // ========================================
    // @StateObject private var similarWordsManager
    // ========================================
    // - SimilarWordsManager シングルトン。
    // - @StateObject で生存期間を管理。
    // - 類義語グループの読み込み・検索に使用。
    @StateObject private var similarWordsManager = SimilarWordsManager.shared

    // ========================================
    // @State private var searchText
    // ========================================
    // - 検索バーの入力テキスト。
    @State private var searchText = ""
    
    // ========================================
    // @State private var searchResults
    // ========================================
    // - 検索結果として表示する EventGroup の配列。
    @State private var searchResults: [EventGroup] = []
    
    // ========================================
    // @State private var isSearching
    // ========================================
    // - 検索処理中フラグ。true なら ProgressView を表示。
    @State private var isSearching = false
    
    // ========================================
    // @State private var showSimilarWordsSettings
    // ========================================
    // - 類義語設定シート表示フラグ。
    @State private var showSimilarWordsSettings = false
    
    // ========================================
    // @State private var selectedSearchMode
    // ========================================
    // - 現在選択されている検索モード（デフォルト: contains 部分一致）。
    @State private var selectedSearchMode: SearchMode = .contains

    // ========================================
    // private var calendar
    // ========================================
    // - 日付操作用カレンダー。
    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationView {
            VStack {
                // ========================================
                // 検索バー
                // ========================================
                // - HStack で虫眼鏡アイコン、入力フィールド、クリアボタンを配置。
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(selectedThemeColor)
                        .font(.title2)

                    // ========================================
                    // TextField
                    // ========================================
                    // - ユーザーが検索キーワードを入力。
                    // - onChange で入力変更時に検索実行。
                    TextField("予定を検索...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            performSearch(query: newValue)
                        }

                    // ========================================
                    // クリアボタン
                    // ========================================
                    // - searchText が空でない時だけ表示。
                    if !searchText.isEmpty {
                        Button("クリア") {
                            searchText = ""
                            searchResults = []
                        }
                        .foregroundColor(selectedThemeColor)
                    }
                }
                .padding()

                // ========================================
                // 検索モード選択（SegmentedPickerStyle）
                // ========================================
                // - ユーザーが検索方法を選択。
                // - 選択モード変更時は既存検索を再実行。
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

                // ========================================
                // 検索結果表示エリア
                // ========================================
                // - 3つの状態を分岐表示：
                //   1. 検索中 → ProgressView
                //   2. 検索結果なし → 空状態UI
                //   3. 結果あり → リスト表示
                if isSearching {
                    ProgressView("検索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    // ========================================
                    // 検索結果なし UI
                    // ========================================
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
                    // ========================================
                    // 初期状態 UI（検索未実行）
                    // ========================================
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
                    Button(action: {
                        showSimilarWordsSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(selectedThemeColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showSimilarWordsSettings) {
            SimilarWordsSettingsView(
                similarWordsGroups: $similarWordsManager.similarWordsGroups,
                selectedThemeColor: $selectedThemeColor,
                onSelectWord: { word in
                    searchText = word
                    performSearch(query: word)
                    showSimilarWordsSettings = false
                }
            )
        }
    }

    // 検索実行: 遅延して実行。SearchMode が .synonym の場合のみ類義語リストを展開し、
    // それ以外のモードではクエリそのものだけをキーワードとして厳密に判定します。
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let lowercaseQuery = trimmed.lowercased()

            // キーワード決定
            let searchKeywords: [String]
            if selectedSearchMode == .synonym {
                // 類義語モード：SimilarWordsManager が属するグループの単語一覧をキーワードとして使用
                searchKeywords = similarWordsManager.findSimilarWords(for: lowercaseQuery).map { $0.lowercased() }
            } else {
                // それ以外はクエリのみ
                searchKeywords = [lowercaseQuery]
            }

            var matched: [Event] = []
            for (_, list) in events {
                for ev in list {
                    let title = ev.title.lowercased()
                    if matchesEventTitle(title, keywords: searchKeywords) {
                        matched.append(ev)
                    }
                }
            }

            // SimilarWordsManager のグループに基づき簡潔にグループ化
            searchResults = groupSimilarEvents(matched, query: lowercaseQuery)
            isSearching = false
        }
    }

    // 指定したモードに基づいて厳密に判定する
    private func matchesEventTitle(_ title: String, keywords: [String]) -> Bool {
        for keyword in keywords {
            switch selectedSearchMode {
            case .prefix:
                if title.hasPrefix(keyword) { return true }
            case .suffix:
                if title.hasSuffix(keyword) { return true }
            case .exact:
                if title == keyword { return true }
            case .contains:
                if title.contains(keyword) { return true }
            case .synonym:
                // 類義語モードでは、類義語リスト中の語がタイトルに含まれているかどうかで判定
                // （厳密な判定：含まれている場合にマッチ）
                if title.contains(keyword) { return true }
            }
        }
        return false
    }

    // 類義語グループに基づいてグループ化する。各イベントのタイトルがグループ内の語を含むかで判定。
    private func groupSimilarEvents(_ events: [Event], query: String) -> [EventGroup] {
        var groups: [String: [Event]] = [:]
        let lowerQuery = query.lowercased()

        for ev in events {
            let title = ev.title.lowercased()
            var assigned: String? = nil

            for g in similarWordsManager.similarWordsGroups {
                for word in g.words {
                    let w = word.lowercased()
                    if title.contains(w) {
                        assigned = g.name
                        break
                    }
                }
                if assigned != nil { break }
            }

            let key = assigned ?? lowerQuery
            groups[key, default: []].append(ev)
        }

        return groups.map { k, v in
            EventGroup(id: k, keyword: k, events: v.sorted { $0.startTime < $1.startTime })
        }.sorted { $0.keyword < $1.keyword }
    }

    // 互換用：単語からグループ名を取得（必要に応じて SimilarWordsManager を直接呼べます）
    private func getGroupName(for word: String) -> String {
        return similarWordsManager.getGroupName(for: word)
    }
}

// 表示用補助型・ビューは元のまま
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
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) { isExpanded.toggle() }
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
                        .background(RoundedRectangle(cornerRadius: 8).fill(selectedThemeColor.opacity(0.1)))

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(selectedThemeColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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

struct EventSearchResultRow: View {
    let event: Event
    let selectedThemeColor: Color

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        HStack(spacing: 15) {
            VStack(spacing: 4) {
                Text(dayString(event.startTime))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(selectedThemeColor))

                Text(monthString(event.startTime))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 50)

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
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.1), radius: 2, x: 0, y: 1))
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
