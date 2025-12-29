//
//  SimilarWordsManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

import Foundation

// ========================================
// SimilarWordsManager: 類義語グループ管理
// ========================================
// - 役割: 類義語の追加・更新・削除・検索、永続化（保存/読み込み）を担当します。
// - データ構造: `similarWordsGroups` は Observable な配列で、UI（SwiftUI）の監視対象になります。
// - 保存形式: JSON にエンコードしたデータを UserDefaults に保存します。
// - 起動時の挙動: 初期化時に `loadSimilarWords()` を呼び、ファイルが無ければデフォルトデータを生成します。

// ========================================
// 使い方（簡単）:
// ========================================
// - 読み取り: `SimilarWordsManager.shared.similarWordsGroups` を参照してください。
// - 変更: `addGroup`, `updateGroup`, `deleteGroup` を利用すると自動的に保存されます。
// - 検索: `findSimilarWords(for:)` に単語を渡すと、その単語を含むグループの単語リスト（類義語）を返します。

// ========================================
// 注意点:
// ========================================
// - データ量が増えた場合は、UserDefaults ではなくファイルまたはデータベースの使用を検討してください。

class SimilarWordsManager: ObservableObject {
    // ========================================
    // static let shared
    // ========================================
    // - シングルトンパターン。
    // - アプリ全体で一つのインスタンスを共有します。
    static let shared = SimilarWordsManager()
    
    // ========================================
    // @Published var similarWordsGroups
    // ========================================
    // - 類義語グループの配列。
    // - @Published により、値が変わると自動的に購読しているビューが更新されます。
    // - 初期値は空配列で、起動時に loadSimilarWords で読み込まれます。
    @Published var similarWordsGroups: [SimilarWordsGroup] = []
    
    // ========================================
    // userDefaults
    // ========================================
    // - iOS の UserDefaults に直接アクセスするための標準 API。
    private let userDefaults = UserDefaults.standard
    
    // ========================================
    // similarWordsKey
    // ========================================
    // - UserDefaults に保存される時のキー名。
    private let similarWordsKey = "SimilarWordsGroups"
    
    // ========================================
    // private init
    // ========================================
    // - シングルトン実装のため、直接の初期化を禁止します。
    // - 起動時に一度だけ実行され、loadSimilarWords を呼びます。
    private init() {
        loadSimilarWords()
    }
    
    // ========================================
    /// 類義語グループを UserDefaults に保存します。
    // ========================================
    // - JSONEncoder で similarWordsGroups を JSON に変換。
    // - 失敗時はコンソールにエラーをプリント。
    func saveSimilarWords() {
        do {
            // ========================================
            // JSONEncoder().encode
            // ========================================
            // - Codable プロトコル準拠のデータを JSON に変換します。
            let data = try JSONEncoder().encode(similarWordsGroups)
            // ========================================
            // userDefaults.set
            // ========================================
            // - JSON データを UserDefaults に保存。
            userDefaults.set(data, forKey: similarWordsKey)
        } catch {
            print("Failed to save similar words: \(error)")
        }
    }
    
    // ========================================
    /// UserDefaults から類義語グループを読み込みます。
    /// - 失敗した場合: デフォルトの類似単語グループを作成します。
    // ========================================
    private func loadSimilarWords() {
        // ========================================
        // userDefaults.data(forKey:)
        // ========================================
        // - UserDefaults から Data を取得。
        // - nil = 保存されたデータがない（初回起動など）。
        guard let data = userDefaults.data(forKey: similarWordsKey) else {
            // 初回起動時はデフォルトの類似単語グループを作成
            createDefaultSimilarWords()
            return
        }
        
        do {
            // ========================================
            // JSONDecoder().decode
            // ========================================
            // - JSON データを [SimilarWordsGroup] の配列に変換。
            similarWordsGroups = try JSONDecoder().decode([SimilarWordsGroup].self, from: data)
        } catch {
            print("Failed to load similar words: \(error)")
            // デコード失敗時もデフォルトを作成
            createDefaultSimilarWords()
        }
    }
    
    // ========================================
    /// デフォルトの類似単語グループを作成します。
    // ========================================
    // - アプリ初回起動時や、データが破損したときに呼ばれます。
    // - 予め用意されたカテゴリ・単語セットで初期化。
    private func createDefaultSimilarWords() {
        // ========================================
        // SimilarWordsGroup の配列
        // ========================================
        // - 各グループは、関連する単語をまとめたもの。
        // - 例："会議関連" グループには「会議」「ミーティング」など。
        similarWordsGroups = [
            // ========================================
            // 会議関連グループ
            // ========================================
            SimilarWordsGroup(name: "会議関連", words: ["会議", "ミーティング", "打ち合わせ", "会合"]),
            
            // ========================================
            // 食事関連グループ
            // ========================================
            SimilarWordsGroup(name: "食事関連", words: ["ランチ", "ディナー", "食事", "お昼", "夕食"]),
            
            // ========================================
            // 運動関連グループ
            // ========================================
            SimilarWordsGroup(name: "運動関連", words: ["ジム", "運動", "トレーニング", "ランニング", "散歩"]),
            
            // ========================================
            // 買い物関連グループ
            // ========================================
            SimilarWordsGroup(name: "買い物関連", words: ["買い物", "ショッピング", "購入", "お買い物"]),
            
            // ========================================
            // 勉強関連グループ
            // ========================================
            SimilarWordsGroup(name: "勉強関連", words: ["勉強", "学習", "読書", "研修", "講習"])
        ]
        // デフォルトを作成後、保存
        saveSimilarWords()
    }
    
    // ========================================
    /// 類義語グループを追加します。
    /// - Parameter group: 追加する類義語グループ
    // ========================================
    func addGroup(_ group: SimilarWordsGroup) {
        // ========================================
        // append
        // ========================================
        // - 配列の末尾にグループを追加。
        similarWordsGroups.append(group)
        saveSimilarWords()
    }
    
    // ========================================
    /// 類義語グループを更新します。
    /// - Parameter group: 更新する類義語グループ
    // ========================================
    // - id が一致するグループを探して置き換え。
    func updateGroup(_ group: SimilarWordsGroup) {
        // ========================================
        // firstIndex(where:)
        // ========================================
        // - id が一致するグループのインデックスを取得。
        if let index = similarWordsGroups.firstIndex(where: { $0.id == group.id }) {
            // ========================================
            // similarWordsGroups[index] = group
            // ========================================
            // - 該当グループを新しい内容に置き換え。
            similarWordsGroups[index] = group
            saveSimilarWords()
        }
    }
    
    // ========================================
    /// 類義語グループを削除します。
    /// - Parameter group: 削除する類義語グループ
    // ========================================
    func deleteGroup(_ group: SimilarWordsGroup) {
        // ========================================
        // removeAll(where:)
        // ========================================
        // - id が一致するすべてのグループを削除。
        // - 通常は最大1件。
        similarWordsGroups.removeAll { $0.id == group.id }
        saveSimilarWords()
    }
    
    // ========================================
    /// 単語に関連する類義語を検索します。
    /// - Parameter word: 検索する単語
    /// - Returns: 類義語の配列（見つからない場合は引数の単語そのもの）
    // ========================================
    func findSimilarWords(for word: String) -> [String] {
        // ========================================
        // lowercased()
        // ========================================
        // - 大文字小文字を区別しないために小文字に変換。
        let lowercaseWord = word.lowercased()
        
        // ========================================
        // for group in similarWordsGroups
        // ========================================
        // - すべてのグループをループ。
        for group in similarWordsGroups {
            // ========================================
            // contains(where:)
            // ========================================
            // - グループ内に該当単語が存在するか確認。
            // - 大文字小文字を区別しない比較。
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                // ========================================
                // return group.words
                // ========================================
                // - マッチしたグループのすべての単語を返す（類義語）。
                return group.words
            }
        }
        
        // ========================================
        // return [word]
        // ========================================
        // - どのグループにも見つからない場合は、入力単語そのもので返す。
        // - これにより、グループ外の単語でも検索が成立します。
        return [word]
    }
    
    // ========================================
    /// 単語に関連するグループ名を取得します。
    /// - Parameter word: 検索する単語
    /// - Returns: グループ名（見つからない場合は入力単語そのもの）
    // ========================================
    func getGroupName(for word: String) -> String {
        let lowercaseWord = word.lowercased()
        
        // ========================================
        // for group in similarWordsGroups
        // ========================================
        // - すべてのグループをループ。
        for group in similarWordsGroups {
            // ========================================
            // contains(where:)
            // ========================================
            // - グループ内に該当単語が存在するか確認。
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                // ========================================
                // return group.name
                // ========================================
                // - マッチしたグループの名前を返す。
                return group.name
            }
        }
        
        // 見つからない場合は入力単語をそのまま返す
        return word
    }
}
