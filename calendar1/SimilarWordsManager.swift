//
//  SimilarWordsManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import Foundation

// アプリ内で共有されるシングルトンのマネージャ
class SimilarWordsManager: ObservableObject {
    // 共有インスタンス
    static let shared = SimilarWordsManager()
    
    // 類似語グループの配列（UI が監視するため @Published）
    @Published var similarWordsGroups: [SimilarWordsGroup] = []
    
    private let userDefaults = UserDefaults.standard
    private let similarWordsKey = "SimilarWordsGroups"
    
    // プライベートイニシャライザでシングルトンを維持
    private init() {
        loadSimilarWords()
    }
    
    // グループ配列を UserDefaults に JSON エンコードして保存
    func saveSimilarWords() {
        do {
            let data = try JSONEncoder().encode(similarWordsGroups)
            userDefaults.set(data, forKey: similarWordsKey)
        } catch {
            print("Failed to save similar words: \(error)")
        }
    }
    
    // UserDefaults から読み込み、失敗した場合はデフォルトグループを作成
    private func loadSimilarWords() {
        guard let data = userDefaults.data(forKey: similarWordsKey) else {
            // 初回起動時はデフォルトの類似語グループを作成
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
    
    // デフォルトの類似語グループを生成して保存
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
    
    // 新しいグループを追加して保存
    func addGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.append(group)
        saveSimilarWords()
    }
    
    // 既存グループを更新して保存
    func updateGroup(_ group: SimilarWordsGroup) {
        if let index = similarWordsGroups.firstIndex(where: { $0.id == group.id }) {
            similarWordsGroups[index] = group
            saveSimilarWords()
        }
    }
    
    // グループを削除して保存
    func deleteGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.removeAll { $0.id == group.id }
        saveSimilarWords()
    }
    
    // 指定した単語に一致するグループ内の単語群を返す（見つからなければ単語自身を返す）
    func findSimilarWords(for word: String) -> [String] {
        let lowercaseWord = word.lowercased()
        
        for group in similarWordsGroups {
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                return group.words
            }
        }
        
        return [word]
    }
    
    // 単語がどのグループ名に属するかを返す。見つからなければ単語を返す。
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
