//
//  SimilarWordsManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import Foundation

// SimilarWordsManager: 類義語グループ（SimilarWordsGroup の配列）を管理するシングルトンです。
// - 役割: 類義語の追加・更新・削除・検索、永続化（保存/読み込み）を担当します。
// - データ構造: `similarWordsGroups` は Observable な配列で、UI（SwiftUI）の監視対象になります。
// - 保存形式: JSON にエンコードしたデータをアプリの Documents フォルダ（similar_words.json）に保存します。
// - 起動時の挙動: 初期化時に `loadSimilarWords()` を呼び、ファイルが無ければ UserDefaults からの移行を試み、さらに無ければデフォルトデータを生成します。

// 使い方（簡単）:
// - 読み取り: `SimilarWordsManager.shared.similarWordsGroups` を参照してください。
// - 変更: `addGroup`, `updateGroup`, `deleteGroup` を利用すると自動的に保存されます。
// - 検索: `findSimilarWords(for:)` に単語を渡すと、その単語を含むグループの単語リスト（類義語）を返します。

// 注意点:
// - ファイルアクセスに失敗する可能性があるため、デコードに失敗した場合はデフォルトセットを作成して保存します。
// - データ量が増えた場合は、UserDefaults ではなくファイルまたはデータベースの使用を検討してください。

class SimilarWordsManager: ObservableObject {
    static let shared = SimilarWordsManager()
    
    @Published var similarWordsGroups: [SimilarWordsGroup] = []
    
    private let userDefaults = UserDefaults.standard
    private let similarWordsKey = "SimilarWordsGroups"
    
    private init() {
        loadSimilarWords()
    }
    
    /// 類義語グループを UserDefaults に保存します。
    func saveSimilarWords() {
        do {
            let data = try JSONEncoder().encode(similarWordsGroups)
            userDefaults.set(data, forKey: similarWordsKey)
        } catch {
            print("Failed to save similar words: \(error)")
        }
    }
    
    /// UserDefaults から類義語グループを読み込みます。
    /// - 失敗した場合: デフォルトの類似単語グループを作成します。
    private func loadSimilarWords() {
        guard let data = userDefaults.data(forKey: similarWordsKey) else {
            // 初回起動時はデフォルトの類似単語グループを作成
            createDefaultSimilarWords()
            return
        }
        
        do {
            similarWordsGroups = try JSONDecoder().decode([SimilarWordsGroup].self, from: data)
        } catch {
            print("Failed to load similar words: \(error)")
            createDefaultSimilarWords()
        }
    }
    
    /// デフォルトの類似単語グループを作成します。
    private func createDefaultSimilarWords() {
        similarWordsGroups = [
            SimilarWordsGroup(name: "会議関連", words: ["会議", "ミーティング", "打ち合わせ", "会合"]),
            SimilarWordsGroup(name: "食事関連", words: ["ランチ", "ディナー", "食事", "お昼", "夕食"]),
            SimilarWordsGroup(name: "運動関連", words: ["ジム", "運動", "トレーニング", "ランニング", "散歩"]),
            SimilarWordsGroup(name: "買い物関連", words: ["買い物", "ショッピング", "購入", "お買い物"]),
            SimilarWordsGroup(name: "勉強関連", words: ["勉強", "学習", "読書", "研修", "講習"])
        ]
        saveSimilarWords()
    }
    
    /// 類義語グループを追加します。
    /// - Parameter group: 追加する類義語グループ
    func addGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.append(group)
        saveSimilarWords()
    }
    
    /// 類義語グループを更新します。
    /// - Parameter group: 更新する類義語グループ
    func updateGroup(_ group: SimilarWordsGroup) {
        if let index = similarWordsGroups.firstIndex(where: { $0.id == group.id }) {
            similarWordsGroups[index] = group
            saveSimilarWords()
        }
    }
    
    /// 類義語グループを削除します。
    /// - Parameter group: 削除する類義語グループ
    func deleteGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.removeAll { $0.id == group.id }
        saveSimilarWords()
    }
    
    /// 単語に関連する類義語を検索します。
    /// - Parameter word: 検索する単語
    /// - Returns: 類義語の配列
    func findSimilarWords(for word: String) -> [String] {
        let lowercaseWord = word.lowercased()
        
        for group in similarWordsGroups {
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                return group.words
            }
        }
        
        return [word]
    }
    
    /// 単語に関連するグループ名を取得します。
    /// - Parameter word: 検索する単語
    /// - Returns: グループ名
    func getGroupName(for word: String) -> String {
        let lowercaseWord = word.lowercased()
        
        for group in similarWordsGroups {
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                return group.name
            }
        }
        
        return word
    }
}
