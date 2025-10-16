//
//  SimilarWordsManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import Foundation

class SimilarWordsManager: ObservableObject {
    static let shared = SimilarWordsManager()
    
    @Published var similarWordsGroups: [SimilarWordsGroup] = []
    
    private let userDefaults = UserDefaults.standard
    private let similarWordsKey = "SimilarWordsGroups"
    
    private init() {
        loadSimilarWords()
    }
    
    func saveSimilarWords() {
        do {
            let data = try JSONEncoder().encode(similarWordsGroups)
            userDefaults.set(data, forKey: similarWordsKey)
        } catch {
            print("Failed to save similar words: \(error)")
        }
    }
    
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
    
    func addGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.append(group)
        saveSimilarWords()
    }
    
    func updateGroup(_ group: SimilarWordsGroup) {
        if let index = similarWordsGroups.firstIndex(where: { $0.id == group.id }) {
            similarWordsGroups[index] = group
            saveSimilarWords()
        }
    }
    
    func deleteGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.removeAll { $0.id == group.id }
        saveSimilarWords()
    }
    
    func findSimilarWords(for word: String) -> [String] {
        let lowercaseWord = word.lowercased()
        
        for group in similarWordsGroups {
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                return group.words
            }
        }
        
        return [word]
    }
    
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
