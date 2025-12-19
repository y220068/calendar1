//
//  SimilarWordsManager.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

// このクラスは「似た意味の単語グループ」を管理します。
// たとえば「会議」「ミーティング」「打ち合わせ」を一つのグループにしておくと、
// 検索時にそれらをまとめて扱えるようになります。

// 初心者向け説明：
// - このクラスはアプリ全体で一つだけ（シングルトン）しか作りません。
// - グループは名前（例: 会議関連）と、そのグループに含まれる単語の配列で構成されます。
// - グループの追加・更新・削除ができ、UserDefaults に保存されます。

import Foundation

class SimilarWordsManager: ObservableObject {
    // ここを通じてアプリのどこからでも同じデータにアクセスできます
    static let shared = SimilarWordsManager()

    // 類似語グループの配列（UI が変化を監視できるように @Published）
    @Published var similarWordsGroups: [SimilarWordsGroup] = []

    private let userDefaults = UserDefaults.standard
    private let similarWordsKey = "SimilarWordsGroups"

    // プライベートな初期化: 外部から生成できない（シングルトンを強制）
    private init() {
        loadSimilarWords()
    }

    // saveSimilarWords: グループ配列を JSON にして UserDefaults に保存する
    func saveSimilarWords() {
        do {
            let data = try JSONEncoder().encode(similarWordsGroups)
            userDefaults.set(data, forKey: similarWordsKey)
        } catch {
            print("Failed to save similar words: \(error)")
        }
    }

    // loadSimilarWords: 保存データがあれば読み込む。なければデフォルトのグループを作る
    private func loadSimilarWords() {
        guard let data = userDefaults.data(forKey: similarWordsKey) else {
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

    // createDefaultSimilarWords: 初回起動時の例となるグループを用意する
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

    // 外部からグループを追加
    func addGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.append(group)
        saveSimilarWords()
    }

    // 既存グループを更新（id が一致するものを置き換える）
    func updateGroup(_ group: SimilarWordsGroup) {
        if let index = similarWordsGroups.firstIndex(where: { $0.id == group.id }) {
            similarWordsGroups[index] = group
            saveSimilarWords()
        }
    }

    // グループを削除
    func deleteGroup(_ group: SimilarWordsGroup) {
        similarWordsGroups.removeAll { $0.id == group.id }
        saveSimilarWords()
    }

    // findSimilarWords: 指定した単語がどのグループにあるかを調べ、そのグループ内の単語を返す
    // 例: "会議" を渡すと ["会議", "ミーティング", ...] の配列を返す
    func findSimilarWords(for word: String) -> [String] {
        let lowercaseWord = word.lowercased()
        for group in similarWordsGroups {
            if group.words.contains(where: { $0.lowercased() == lowercaseWord }) {
                return group.words
            }
        }
        // 見つからなければ入力した単語だけを返す
        return [word]
    }

    // getGroupName: 単語が属するグループ名を返す（例: "会議" -> "会議関連"）。見つからなければ単語自身を返す
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
