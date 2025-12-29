// CategorySettingsView.swift
// カテゴリの追加・編集・削除・有効/無効の管理画面を提供する UI

import SwiftUI

// ========================================
// CategorySettingsView 構造体
// ========================================
// - View プロトコル準拠。
// - カテゴリ一覧の表示・編集・削除を行う SwiftUI ビュー。
// - CategoryManager との同期を行います。

struct CategorySettingsView: View {
    // ========================================
    // @Binding var categories
    // ========================================
    // - 親ビューから渡されたカテゴリ配列への参照。
    // - このビュー内で categories を編集すると、親ビューも自動更新。
    @Binding var categories: [Category]
    
    // ========================================
    // @Binding var selectedThemeColor
    // ========================================
    // - 親ビューから渡されたテーマカラー。
    // - UI の色合いを統一するため使用。
    @Binding var selectedThemeColor: Color
    
    // ========================================
    // @Environment(\.presentationMode)
    // ========================================
    // - このビューを閉じる（dismiss）ために使用。
    // - presentationMode.wrappedValue.dismiss() で画面を閉じる。
    @Environment(\.presentationMode) var presentationMode

    // ========================================
    // @State private var showAdd
    // ========================================
    // - 新規カテゴリ追加シートの表示フラグ。
    // - true になると AddCategoryView シートが表示される。
    @State private var showAdd = false
    
    // ========================================
    // @State private var editingIndex
    // ========================================
    // - 現在編集中のカテゴリ配列インデックス。
    // - nil = 編集中でない。
    // - 整数値 = そのインデックスのカテゴリを編集中。
    @State private var editingIndex: Int? = nil

    // ========================================
    // save メソッド（private）
    // ========================================
    // - ローカルの categories 配列を CategoryManager に反映。
    // - CategoryManager.shared.saveCategories() で UserDefaults に保存。
    private func save() {
        // ========================================
        // CategoryManager.shared.categories = categories
        // ========================================
        // - シングルトンの categories を、このビューのローカル配列で上書き。
        CategoryManager.shared.categories = categories
        // ========================================
        // saveCategories()
        // ========================================
        // - UserDefaults に JSON 形式で保存。
        // - 購読しているビューが自動更新される。
        CategoryManager.shared.saveCategories()
    }

    // ========================================
    // var body: some View
    // ========================================
    // - ビューの本体。Navigation + VStack + List で構成。
    var body: some View {
        // ========================================
        // NavigationView
        // ========================================
        // - ナビゲーション機能を有効にし、NavigationTitle などが使用可能に。
        NavigationView {
            VStack {
                // ========================================
                // if categories.isEmpty
                // ========================================
                // - カテゴリが1件も無い場合、空状態UI を表示。
                if categories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tag")
                            .font(.system(size: 44))
                            .foregroundColor(selectedThemeColor.opacity(0.6))
                        Text("カテゴリがありません")
                            .foregroundColor(.gray)
                        Text("右上の「+」でカテゴリを追加できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // ========================================
                    // List
                    // ========================================
                    // - カテゴリ一覧を表示。スワイプで削除可能。
                    List {
                        // ========================================
                        // ForEach(categories.indices)
                        // ========================================
                        // - インデックスでループ。配列の値と参照を同時に扱うため indices を使用。
                        ForEach(categories.indices, id: \.self) { idx in
                            HStack {
                                // ========================================
                                // Category name on the left
                                // ========================================
                                Text(categories[idx].name)
                                    .lineLimit(1)

                                Spacer()

                                // ========================================
                                // Toggle: 有効/無効スイッチ
                                // ========================================
                                // - カテゴリの isEnabled フラグをトグル。
                                // - true: カテゴリの予定が表示
                                // - false: カテゴリの予定が非表示（フィルタ）
                                Toggle("表示", isOn: Binding(get: { categories[idx].isEnabled }, set: { newVal in
                                    // ========================================
                                    // Create updated category
                                    // ========================================
                                    // - 元のカテゴリコピーを作成。
                                    var updated = categories[idx]
                                    // ========================================
                                    // updated.isEnabled = newVal
                                    // ========================================
                                    // - トグルされた値を反映。
                                    updated.isEnabled = newVal
                                    // ========================================
                                    // CategoryManager.shared.updateCategory
                                    // ========================================
                                    // - マネージャーの categories も更新し、保存・通知。
                                    CategoryManager.shared.updateCategory(updated)
                                    // ========================================
                                    // categories[idx] = updated
                                    // ========================================
                                    // - ローカル配列も同期。
                                    categories[idx] = updated
                                }))
                                .toggleStyle(SwitchToggleStyle(tint: selectedThemeColor))
                                .padding(.trailing, 8)

                                // ========================================
                                // Edit button
                                // ========================================
                                // - 編集シート表示用のボタン。
                                Button(action: { editingIndex = idx }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 8)

                                // ========================================
                                // Delete button
                                // ========================================
                                // - カテゴリ削除。
                                Button(action: {
                                    categories.remove(at: idx)
                                    save()
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .contentShape(Rectangle())
                        }
                        // ========================================
                        // .onDelete
                        // ========================================
                        // - List でのスワイプ削除を有効。
                        // - リスト行をスワイプすると削除オプション表示。
                        .onDelete { offsets in
                            offsets.forEach { categories.remove(at: $0) }
                            save()
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                Spacer()
            }
            // ========================================
            // .navigationTitle
            // ========================================
            // - ナビゲーションバーのタイトル。
            .navigationTitle("カテゴリ設定")
            .navigationBarTitleDisplayMode(.inline)
            // ========================================
            // .toolbar
            // ========================================
            // - ナビゲーションバーボタン。
            .toolbar {
                // ========================================
                // ToolbarItem(placement: .navigationBarLeading)
                // ========================================
                // - ナビゲーションバー左側（戻るボタン）。
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(selectedThemeColor)
                }
                // ========================================
                // ToolbarItem(placement: .navigationBarTrailing)
                // ========================================
                // - ナビゲーションバー右側（＋ボタン）。
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // ========================================
                        // Button(action: { showAdd = true })
                        // ========================================
                        // - 新規追加シート表示フラグを ON。
                        Button(action: { showAdd = true }) { Image(systemName: "plus") }
                            .foregroundColor(selectedThemeColor)
                    }
                }
            }
        }
        // ========================================
        // .sheet(isPresented: $showAdd)
        // ========================================
        // - 新規カテゴリ追加シート。
        // - showAdd フラグが true になるとシート表示。
        .sheet(isPresented: $showAdd) {
            AddCategoryView(onSave: { name in
                // ========================================
                // Category(name:)
                // ========================================
                // - 入力されたカテゴリ名で新規 Category を作成。
                // - id と isEnabled はデフォルト値で自動生成。
                let cat = Category(name: name)
                categories.append(cat)
                save()
            }, selectedThemeColor: selectedThemeColor)
        }
        // ========================================
        // .sheet(item: Binding)
        // ========================================
        // - 編集シート。
        // - editingIndex != nil の時に EditCategoryView を表示。
        .sheet(item: Binding(get: { editingIndex == nil ? nil : categories[editingIndex!] }, set: { _ in editingIndex = nil })) { cat in
            // ========================================
            // Find index again
            // ========================================
            // - Binding から id を抽出して、配列インデックスを再検索。
            let idx = categories.firstIndex(where: { $0.id == cat.id })
            if let idx = idx {
                // ========================================
                // EditCategoryView
                // ========================================
                // - カテゴリ編集・削除画面。
                EditCategoryView(category: Binding(get: { categories[idx] }, set: { categories[idx] = $0 }), onSave: {
                    save()
                    editingIndex = nil
                }, onDelete: {
                    categories.removeAll { $0.id == cat.id }
                    save()
                    editingIndex = nil
                }, selectedThemeColor: selectedThemeColor)
            } else {
                EmptyView()
            }
        }
    }
}

// ========================================
// AddCategoryView 構造体
// ========================================
// - 新規カテゴリ追加用のモーダル画面。
// - ユーザーがカテゴリ名を入力して保存ボタンを押すと、onSave クロージャが実行される。

struct AddCategoryView: View {
    // ========================================
    // let onSave: (String) -> Void
    // ========================================
    // - 保存ボタン押下時に呼ばれるコールバック。
    // - 引数は入力されたカテゴリ名（String）。
    let onSave: (String) -> Void
    
    // ========================================
    // let selectedThemeColor
    // ========================================
    // - UI のテーマカラー。
    let selectedThemeColor: Color
    
    // ========================================
    // @Environment(\.presentationMode)
    // ========================================
    // - このビューを閉じるための環境値。
    @Environment(\.presentationMode) var presentationMode
    
    // ========================================
    // @State private var name
    // ========================================
    // - テキストフィールドの入力値。
    @State private var name = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // ========================================
                // TextField
                // ========================================
                // - カテゴリ名の入力欄。
                TextField("カテゴリ名", text: $name).textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
            }
            .padding()
            .navigationTitle("新しいカテゴリ")
            // ========================================
            // .toolbar
            // ========================================
            // - キャンセルボタン（左）と保存ボタン（右）。
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    // ========================================
                    // Cancel ボタン
                    // ========================================
                    // - 入力をキャンセルしてシートを閉じる。
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() } 
                }
                ToolbarItem(placement: .navigationBarTrailing) { 
                    // ========================================
                    // Save ボタン
                    // ========================================
                    // - onSave コールバックを実行して、シートを閉じる。
                    // - 空文字列の場合はボタン disabled。
                    Button("保存") { 
                        onSave(name)
                        presentationMode.wrappedValue.dismiss() 
                    }
                    // ========================================
                    // .disabled
                    // ========================================
                    // - 空白のみの場合ボタンが無効。
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) 
                }
            }
        }
    }
}

// ========================================
// EditCategoryView 構造体
// ========================================
// - 既存カテゴリの編集・削除画面。
// - カテゴリ名の編集と、削除確認アラートを提供。

struct EditCategoryView: View {
    // ========================================
    // @Binding var category
    // ========================================
    // - 編集対象のカテゴリへの参照。
    // - このビューで category.name を編集すると、親ビューにも反映。
    @Binding var category: Category
    
    // ========================================
    // let onSave / onDelete
    // ========================================
    // - 保存・削除時のコールバック。
    let onSave: (() -> Void)?
    let onDelete: (() -> Void)?
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    
    // ========================================
    // @State private var name
    // ========================================
    // - テキストフィールド用の入力値。
    // - 初期値は category.name。
    @State private var name: String = ""
    
    // ========================================
    // @State private var showDeleteAlert
    // ========================================
    // - 削除確認アラート表示フラグ。
    @State private var showDeleteAlert = false

    // ========================================
    // init イニシャライザ
    // ========================================
    // - @State プロパティの初期化。
    init(category: Binding<Category>, onSave: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, selectedThemeColor: Color) {
        self._category = category
        self.onSave = onSave
        self.onDelete = onDelete
        self.selectedThemeColor = selectedThemeColor
        // ========================================
        // _name = State(initialValue:)
        // ========================================
        // - @State の underlying storage に直接初期値を設定。
        self._name = State(initialValue: category.wrappedValue.name)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextField("カテゴリ名", text: $name).textFieldStyle(RoundedBorderTextFieldStyle())

                Spacer()

                // ========================================
                // Delete button
                // ========================================
                // - 削除ボタン。押すと確認アラート表示。
                Button(action: { showDeleteAlert = true }) {
                    Text("カテゴリを削除").foregroundColor(.white).frame(maxWidth: .infinity).padding().background(RoundedRectangle(cornerRadius: 10).fill(Color.red))
                }
                // ========================================
                // .alert
                // ========================================
                // - 削除確認ダイアログ。
                .alert(isPresented: $showDeleteAlert) {
                    Alert(title: Text("カテゴリを削除"), message: Text("このカテゴリを削除しますか？"), primaryButton: .destructive(Text("削除")) {
                        // ========================================
                        // onDelete?()
                        // ========================================
                        // - 削除コールバック実行。
                        onDelete?()
                        presentationMode.wrappedValue.dismiss()
                    }, secondaryButton: .cancel())
                }
            }
            .padding()
            .navigationTitle("カテゴリを編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() } 
                }
                ToolbarItem(placement: .navigationBarTrailing) { 
                    // ========================================
                    // Save ボタン
                    // ========================================
                    // - 編集内容を category に反映してから保存。
                    Button("保存") { 
                        category.name = name
                        onSave?()
                        presentationMode.wrappedValue.dismiss() 
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) 
                }
            }
        }
    }
}

// ========================================
// #Preview
// ========================================
// - Xcode プレビュー用のサンプルデータ表示。
#Preview {
    CategorySettingsView(categories: .constant([Category(name: "仕事"), Category(name: "プライベート")] ), selectedThemeColor: .constant(.blue))
}
