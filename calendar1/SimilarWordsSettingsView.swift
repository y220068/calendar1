//
//  SimilarWordsSettingsView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

// ========================================
// SimilarWordsSettingsView
// ========================================
// このファイルは「類似語（同じ意味の単語）グループを管理する画面」を提供します。
//
// 初心者向け説明：
// - 似た意味を持つ単語をグループ化しておくと、検索時にまとめて探せます。
// - 例: 会議, ミーティング など を「会議関連」グループにまとめる。
// - グループの追加・編集・削除、グループに単語を追加・削除できます。

import SwiftUI

// ========================================
// struct SimilarWordsGroup
// ========================================
// - 類義語グループを表すモデル。
// - Identifiable: ForEach で一意に識別（id プロパティ必須）。
// - Codable: JSON のシリアライズ・デシリアライズ自動化。
// - Equatable: == で比較可能。

// Model
struct SimilarWordsGroup: Identifiable, Codable, Equatable {
    // ========================================
    // let id: String
    // ========================================
    // - グループのユニークな識別子。
    // - 新規作成時は UUID().uuidString で自動生成。
    let id: String
    
    // ========================================
    // var name: String
    // ========================================
    // - グループの表示名（例："会議関連"、"食事関連"）。
    // - ユーザーが編集・設定画面で変更可能。
    var name: String
    
    // ========================================
    // var words: [String]
    // ========================================
    // - グループに属する単語のリスト。
    // - 例: ["会議", "ミーティング", "打ち合わせ", "会合"]
    var words: [String]

    // ========================================
    // init イニシャライザ
    // ========================================
    init(id: String = UUID().uuidString, name: String, words: [String]) {
        self.id = id
        self.name = name
        self.words = words
    }
}

// Main settings view
struct SimilarWordsSettingsView: View {
    @Binding var similarWordsGroups: [SimilarWordsGroup]
    @Binding var selectedThemeColor: Color
    var onSelectWord: ((String) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode

    @State private var showAddGroup = false
    @State private var editingIndex: Int? = nil // which group is being edited

    private func saveSimilarWords() {
        SimilarWordsManager.shared.similarWordsGroups = similarWordsGroups
        SimilarWordsManager.shared.saveSimilarWords()
    }

    var body: some View {
        NavigationView {
            VStack {
                header

                if similarWordsGroups.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(similarWordsGroups.indices, id: \.self) { idx in
                            SimilarWordsGroupRow(
                                group: $similarWordsGroups[idx],
                                selectedThemeColor: selectedThemeColor,
                                onEditGroup: { _ in editingIndex = idx },
                                onTapWord: { word in handleWordSelection(word) },
                                onGroupChanged: { saveSimilarWords() }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { similarWordsGroups.remove(at: $0) }
                            saveSimilarWords()
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                Spacer()
            }
            .navigationTitle("類似語設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(selectedThemeColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddGroup = true }) { HStack { Image(systemName: "plus"); Text("グループを追加") } }
                        .foregroundColor(selectedThemeColor)
                }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            AddSimilarWordsGroupView(onSave: { name, words in
                let g = SimilarWordsGroup(name: name, words: words)
                similarWordsGroups.append(g)
                saveSimilarWords()
            }, selectedThemeColor: selectedThemeColor)
        }
        .sheet(isPresented: Binding(get: { editingIndex != nil }, set: { if !$0 { editingIndex = nil } })) {
            if let idx = editingIndex, similarWordsGroups.indices.contains(idx) {
                EditSimilarWordsGroupView(group: $similarWordsGroups[idx], onSave: {
                    saveSimilarWords()
                    editingIndex = nil
                }, onDelete: {
                    let id = similarWordsGroups[idx].id
                    similarWordsGroups.removeAll { $0.id == id }
                    saveSimilarWords()
                    editingIndex = nil
                }, selectedThemeColor: selectedThemeColor)
            } else {
                EmptyView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("類似語の設定").font(.headline).foregroundColor(selectedThemeColor)
            Text("似た意味の単語をグループにまとめると、検索が便利になります。")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(selectedThemeColor.opacity(0.08)))
        .padding(.horizontal)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus").font(.system(size: 44)).foregroundColor(selectedThemeColor.opacity(0.6))
            Text("類似語グループがありません").foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleWordSelection(_ word: String) {
        onSelectWord?(word)
        presentationMode.wrappedValue.dismiss()
    }
}

// Row view with single edit button; add/delete of words is handled in the edit modal
struct SimilarWordsGroupRow: View {
    @Binding var group: SimilarWordsGroup
    let selectedThemeColor: Color
    let onEditGroup: (SimilarWordsGroup) -> Void
    let onTapWord: (String) -> Void
    let onGroupChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name).font(.headline).foregroundColor(selectedThemeColor)
                    Text("\(group.words.count) 個の単語").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { onEditGroup(group) }) {
                    Image(systemName: "pencil").padding(8).background(Circle().fill(selectedThemeColor.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))

            if !group.words.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(group.words.enumerated()), id: \.offset) { index, word in
                        HStack {
                            Button(action: { onTapWord(word) }) {
                                HStack { Text(word).foregroundColor(.primary); Spacer() }
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                if let i = group.words.firstIndex(of: word) {
                                    group.words.remove(at: i)
                                    onGroupChanged()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }
}

// Add group modal
struct AddSimilarWordsGroupView: View {
    let onSave: (String, [String]) -> Void
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var words: [String] = []
    @State private var newWord = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("グループ名", text: $name).textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    TextField("単語を追加", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("追加") {
                        let t = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty && !words.contains(t) else { return }
                        words.append(t); newWord = ""
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !words.isEmpty { FlowTagView(tags: words, onRemove: { idx in words.remove(at: idx) }) }
                Spacer()
            }
            .padding()
            .navigationTitle("新しいグループ")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { onSave(name, words); presentationMode.wrappedValue.dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

// Edit modal bound to the actual group
struct EditSimilarWordsGroupView: View {
    @Binding var group: SimilarWordsGroup
    let onSave: (() -> Void)?
    let onDelete: (() -> Void)?
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode

    @State private var groupName: String
    @State private var words: [String]
    @State private var newWord = ""
    @State private var showDeleteAlert = false

    init(group: Binding<SimilarWordsGroup>, onSave: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, selectedThemeColor: Color) {
        self._group = group
        self.onSave = onSave
        self.onDelete = onDelete
        self.selectedThemeColor = selectedThemeColor
        self._groupName = State(initialValue: group.wrappedValue.name)
        self._words = State(initialValue: group.wrappedValue.words)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("グループ名", text: $groupName).textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: groupName) { group.name = $0 }

                HStack {
                    TextField("新しい単語", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("追加") {
                        let t = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty && !words.contains(t) else { return }
                        words.append(t); group.words = words; newWord = ""
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !words.isEmpty { FlowTagView(tags: words, onRemove: { idx in words.remove(at: idx); group.words = words }) }

                Spacer()

                Button(action: { showDeleteAlert = true }) {
                    Text("グループを削除").foregroundColor(.white).frame(maxWidth: .infinity).padding().background(RoundedRectangle(cornerRadius: 10).fill(Color.red))
                }
                .alert(isPresented: $showDeleteAlert) {
                    Alert(title: Text("グループの削除"), message: Text("このグループを削除してよいですか？元に戻せません。"), primaryButton: .destructive(Text("削除")) {
                        onDelete?(); presentationMode.wrappedValue.dismiss()
                    }, secondaryButton: .cancel())
                }
            }
            .padding()
            .navigationTitle("グループを編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { group.name = groupName; group.words = words; onSave?(); presentationMode.wrappedValue.dismiss() }.disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
        .onAppear { groupName = group.name; words = group.words }
    }
}

struct FlowTagView: View {
    let tags: [String]
    let onRemove: (Int) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(Array(tags.enumerated()), id: \.offset) { idx, tag in
                HStack {
                    Text(tag).font(.caption).padding(.horizontal, 8).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray6)))
                    Button(action: { onRemove(idx) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
                }
            }
        }
    }
}

// Small helper add single word screen (kept for compatibility)
struct AddWordToGroupView: View {
    let groupName: String
    let onSave: (String) -> Void
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    @State private var newWord = ""
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextField("新しい単語", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("追加") { onSave(newWord); presentationMode.wrappedValue.dismiss() }.disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

#Preview {
    SimilarWordsSettingsView(similarWordsGroups: .constant([SimilarWordsGroup(name: "会議関連", words: ["会議","ミーティング","打ち合わせ"])]), selectedThemeColor: .constant(.blue))
}
