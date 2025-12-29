// CategoryManager.swift
// 予定のカテゴリ（タグ）を管理し、UserDefaults に永続化するマネージャークラス

import Foundation

// ========================================
// Category 構造体
// ========================================
// - カテゴリの情報（名前、有効/無効フラグ）を保持します。
// - Identifiable: SwiftUI のループ内で一意に識別可能にします（id プロパティ必須）。
// - Codable: JSON へのシリアライズ・デシリアライズ自動化。
// - Equatable: == で比較可能にします。

struct Category: Identifiable, Codable, Equatable {
    // ========================================
    // id: String
    // ========================================
    // - カテゴリのユニークな識別子。
    // - 新規作成時は UUID().uuidString で自動生成されます。
    // - 予定の categoryID フィールドと対応します。
    let id: String
    
    // ========================================
    // name: String
    // ========================================
    // - カテゴリの表示名（例："仕事"、"プライベート"、"運動"）。
    // - ユーザーが編集・設定画面で変更可能です。
    var name: String
    
    // ========================================
    // isEnabled: Bool
    // ========================================
    // - カテゴリが表示対象かどうかのフラグ。
    // - true：このカテゴリの予定が画面に表示されます。
    // - false：この カテゴリの予定が非表示になります（フィルタ機能）。
    var isEnabled: Bool

    // ========================================
    // init イニシャライザ
    // ========================================
    // id デフォルト値: UUID().uuidString
    //   - 新規作成時に自動生成される一意の文字列。
    // isEnabled デフォルト値: true
    //   - デフォルトでは作成直後に有効です。
    init(id: String = UUID().uuidString, name: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
    }
}

// ========================================
// CategoryOld 構造体（マイグレーション用）
// ========================================
// - 以前は isEnabled フラグがなかった形式。
// - ファイルアップグレード時に旧形式を読み込むために保持。
// - 新規作成では使用しません。
private struct CategoryOld: Identifiable, Codable {
    let id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

// ========================================
// CategoryManager クラス
// ========================================
// - 全アプリ共通のカテゴリ管理を行うシングルトン。
// - ObservableObject：@Published プロパティで SwiftUI ビューを自動更新。
// - UserDefaults に JSON 形式で保存します。

final class CategoryManager: ObservableObject {
    // ========================================
    // static let shared
    // ========================================
    // - シングルトンパターン。
    // - アプリ全体で一つのインスタンスを共有します。
    // - 複数の ViewController から CategoryManager.shared でアクセス可能。
    static let shared = CategoryManager()

    // ========================================
    // @Published var categories
    // ========================================
    // - カテゴリの配列。
    // - @Published により、値が変わると自動的に購読しているビューが更新されます。
    // - 初期値は空配列で、起動時に loadCategories で読み込まれます。
    @Published var categories: [Category] = []

    // ========================================
    // userDefaults
    // ========================================
    // - iOS の UserDefaults（キー・バリューストレージ）へアクセスするための標準 API。
    // - アプリ終了後もデータが保存されます。
    private let userDefaults = UserDefaults.standard
    
    // ========================================
    // categoriesKey
    // ========================================
    // - UserDefaults に保存される時のキー名。
    // - この文字列でカテゴリデータを出し入れします。
    private let categoriesKey = "EventCategories"

    // ========================================
    // private init
    // ========================================
    // - シングルトン実装のため、直接の初期化を禁止します。
    // - 代わりに CategoryManager.shared でアクセスします。
    // - 起動時に一度だけ実行され、loadCategories を呼びます。
    private init() {
        loadCategories()
    }

    // ========================================
    // saveCategories メソッド
    // ========================================
    // - 現在のカテゴリ配列を UserDefaults に保存します。
    // - JSONEncoder でカテゴリを JSON に変換してから保存。
    // - 失敗時はコンソールにエラーをプリント。
    // - DispatchQueue.main.async で UI 更新通知を確実に行う。
    func saveCategories() {
        do {
            // ========================================
            // JSONEncoder().encode
            // ========================================
            // - Codable プロトコル準拠のデータを JSON に変換します。
            // - encode の戻り値は Data 型（バイナリデータ）。
            let data = try JSONEncoder().encode(categories)
            
            // ========================================
            // userDefaults.set(data, forKey:)
            // ========================================
            // - JSON データを UserDefaults に保存。
            // - キーは categoriesKey ("EventCategories")。
            userDefaults.set(data, forKey: categoriesKey)
            
            // ========================================
            // DispatchQueue.main.async
            // ========================================
            // - メインスレッドに UI 更新タスクをキューイング。
            // - SwiftUI ビューの更新は必ずメインスレッドで実行する必要があります。
            // - objectWillChange.send() で、購読しているビューに変更を通知。
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            // エンコード失敗時のエラーハンドリング
            print("Failed to save categories: \(error)")
        }
    }

    // ========================================
    // loadCategories メソッド（private）
    // ========================================
    // - UserDefaults からカテゴリデータを読み込みます。
    // - 起動時にイニシャライザから呼ばれます。
    // - マイグレーション対応：古い形式から新しい形式への自動アップグレード。
    private func loadCategories() {
        // ========================================
        // userDefaults.data(forKey:)
        // ========================================
        // - UserDefaults から Data を取得。
        // - nil = 保存されたデータがない（初回起動など）。
        guard let data = userDefaults.data(forKey: categoriesKey) else {
            // no saved categories -> start empty
            // 初回起動時は空のカテゴリ配列で開始。
            categories = []
            return
        }

        let decoder = JSONDecoder()
        do {
            // ========================================
            // Try new format first (with isEnabled)
            // ========================================
            // - 新しい形式（isEnabled を含む）をまず試す。
            // - 成功したら categories に代入して終了。
            categories = try decoder.decode([Category].self, from: data)
            return
        } catch {
            // Try old format without isEnabled and migrate
            // ========================================
            // 新形式の読み込み失敗時、旧形式を試す
            // ========================================
            // - マイグレーション：旧形式データを新形式に変換。
            // - [CategoryOld] として読み込んで、isEnabled = true で新 Category に変換。
            do {
                let old = try decoder.decode([CategoryOld].self, from: data)
                // 旧形式を新形式にマッピング。isEnabled = true（デフォルト有効）。
                categories = old.map { Category(id: $0.id, name: $0.name, isEnabled: true) }
                // Save migrated format back
                // ========================================
                // マイグレーション後、新形式で保存しなおす
                // ========================================
                saveCategories()
                return
            } catch {
                // どちらの形式でも読み込めない場合
                print("Failed to load categories (both new and old formats): \(error)")
                categories = []
            }
        }
    }

    // ========================================
    // addCategory メソッド
    // ========================================
    // - 新しいカテゴリを追加します。
    // - name: カテゴリの表示名。
    // - 自動的に saveCategories() で保存。
    func addCategory(name: String) {
        // ========================================
        // Category(name:)
        // ========================================
        // - id と isEnabled はデフォルト値で自動生成。
        let c = Category(name: name)
        categories.append(c)
        saveCategories()
    }

    // ========================================
    // updateCategory メソッド
    // ========================================
    // - 既存カテゴリの内容を更新します。
    // - category: 更新内容を含むカテゴリオブジェクト（id で照合）。
    // - id が一致するカテゴリを探して置き換え。
    func updateCategory(_ category: Category) {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            // ========================================
            // firstIndex(where:)
            // ========================================
            // - クロージャ条件に合致する最初のインデックスを返す。
            // - ここでは id が一致するカテゴリを探す。
            categories[idx] = category
            saveCategories()
        }
    }

    // ========================================
    // deleteCategory メソッド
    // ========================================
    // - カテゴリを削除します。
    // - category: 削除対象のカテゴリ。
    // - id が一致するすべてのカテゴリを削除（通常は最大1件）。
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
    }

    // ========================================
    // name(for:) メソッド
    // ========================================
    // - カテゴリ ID からカテゴリ名を取得。
    // - id: カテゴリの ID（nil の場合は nil を返す）。
    // - 戻り値: マッチしたカテゴリの name。見つからない場合は nil。
    // - 予定に紐付けられたカテゴリ名を表示する際に使用。
    func name(for id: String?) -> String? {
        guard let id = id else { return nil }
        // ========================================
        // first(where:)
        // ========================================
        // - クロージャ条件に合致する最初の要素を返す。
        // - nil = 見つからない。
        return categories.first(where: { $0.id == id })?.name
    }

    // ========================================
    // idForName メソッド
    // ========================================
    // - カテゴリ名からカテゴリ ID を取得。
    // - name: カテゴリの名前。
    // - 戻り値: マッチしたカテゴリの id。見つからない場合は nil。
    func idForName(_ name: String) -> String? {
        return categories.first(where: { $0.name == name })?.id
    }

    // ========================================
    // enabledCategoryIDs() スタティックメソッド
    // ========================================
    // - 現在有効なカテゴリの ID セットを返す。
    // - isEnabled == true のカテゴリ ID だけを集めます。
    // - ContentView でカテゴリフィルタを実装する際に使用。
    // - 使用例: visibleEvents でどのカテゴリの予定を表示するか判定。
    
    // Return a set of enabled category IDs for filtering events.
    // This helper is used by ContentView to decide which categories are visible.
    // ========================================
    // filter { $0.isEnabled }
    // ========================================
    // - isEnabled == true のカテゴリだけを取り出す。
    
    // ========================================
    // map { $0.id }
    // ========================================
    // - フィルタ済みカテゴリから id だけを取り出す。
    
    // ========================================
    // Set(...)
    // ========================================
    // - ID の配列をセット（重複なし）に変換。
    // - 高速な ID メンバシップ判定が可能に。
    static func enabledCategoryIDs() -> Set<String> {
        return Set(CategoryManager.shared.categories.filter { $0.isEnabled }.map { $0.id })
    }
}
