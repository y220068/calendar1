//
//  SimilarWordsSettingsView.swift
//  calendar1
//
//  Created by 小野華凜 on 2025/05/10.
//

// このファイルは「類似語（同じ意味の単語）グループを管理する画面」を提供します。
// 初心者向け説明：
// - 似た意味を持つ単語をグループ化しておくと、検索時にまとめて探せます（例: 会議, ミーティング など）。
// - グループの追加・編集・削除、グループに単語を追加・削除できます

import SwiftUI

// SimilarWordsSettingsView: 類似語グループの一覧と管理（追加・編集・削除）を行う画面
struct SimilarWordsSettingsView: View {
    @Binding var similarWordsGroups: [SimilarWordsGroup]
    @Binding var selectedThemeColor: Color
    var onSelectWord: ((String) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode

    @State private var showAddGroup = false
    @State private var editingGroup: SimilarWordsGroup? = nil

    // 保存ヘルパー: シングルトンに反映して永続化
    private func saveSimilarWords() {
        SimilarWordsManager.shared.similarWordsGroups = similarWordsGroups
        SimilarWordsManager.shared.saveSimilarWords()
    }

    var body: some View {
        NavigationView {
            VStack {
                // 説明ボックス: この画面が何をするところかを簡単に説明
                VStack(alignment: .leading, spacing: 6) {
                    Text("類似語の設定")
                        .font(.headline)
                        .foregroundColor(selectedThemeColor)

                    Text("グループを編集すると名前変更・単語追加・削除、グループ削除ができます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(selectedThemeColor.opacity(0.08)))
                .padding(.horizontal)

                // グループ一覧（なければ案内を表示）
                if similarWordsGroups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 44))
                            .foregroundColor(selectedThemeColor.opacity(0.6))

                        Text("類似語グループがありません")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(similarWordsGroups.indices, id: \.self) { i in
                            SimilarWordsGroupRow(
                                group: $similarWordsGroups[i],
                                selectedThemeColor: selectedThemeColor,
                                onEdit: { g in
                                    editingGroup = g
                            }, onTapWord: { w in
                                onSelectWord?(w)
                                presentationMode.wrappedValue.dismiss()
                            }, onGroupChanged: {
                                saveSimilarWords()
                            })
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { idx in similarWordsGroups.remove(at: idx) }
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
                ToolbarItem(placement: .navigationBarLeading) { Button("閉じる") { presentationMode.wrappedValue.dismiss() }.foregroundColor(selectedThemeColor) }
                ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showAddGroup = true }) { HStack { Image(systemName: "plus"); Text("グループを追加") } }.foregroundColor(selectedThemeColor) }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            AddSimilarWordsGroupView(onSave: { name, words in
                let g = SimilarWordsGroup(name: name, words: words)
                similarWordsGroups.append(g)
                saveSimilarWords()
            }, selectedThemeColor: selectedThemeColor)
        }
        .sheet(item: $editingGroup) { group in
            EditSimilarWordsGroupView(group: group, onSave: { updated in
                if let idx = similarWordsGroups.firstIndex(where: { $0.id == updated.id }) {
                    similarWordsGroups[idx] = updated
                }
                saveSimilarWords()
                editingGroup = nil
            }, onDelete: {
                similarWordsGroups.removeAll(where: { $0.id == group.id })
                saveSimilarWords()
                editingGroup = nil
            }, selectedThemeColor: selectedThemeColor)
        }
    }
}

// 以下はグループモデルとサブビュー（行、追加フォーム、編集フォーム、単語追加フォーム）です。
// それぞれ簡単に何をするかをコメントしています。

// SimilarWordsGroup: グループのデータ構造（id, 名前, 単語リスト）
struct SimilarWordsGroup: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var words: [String]

    init(id: String = UUID().uuidString, name: String, words: [String]) {
        self.id = id
        self.name = name
        self.words = words
    }
}

// SimilarWordsGroupRow: グループごとに表示される行。グループ名、単語一覧、編集/削除/追加操作を提供
struct SimilarWordsGroupRow: View {
    @Binding var group: SimilarWordsGroup
    let selectedThemeColor: Color
    let onEdit: (SimilarWordsGroup) -> Void
    let onTapWord: (String) -> Void
    let onGroupChanged: () -> Void

    @State private var showAddWord = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name).font(.headline).foregroundColor(selectedThemeColor)
                    Text("\(group.words.count) 個の単語").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { onEdit(group) }) {
                    Image(systemName: "pencil").padding(8).background(Circle().fill(selectedThemeColor.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))

            // 単語一覧（個別に削除できる）
            if !group.words.isEmpty {
                InlineTagListView(tags: group.words, onTap: { w in onTapWord(w) })
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showAddWord) {
            AddWordToGroupView(groupName: group.name, onSave: { w in
                let trimmed = w.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty && !group.words.contains(trimmed) else { return }
                group.words.append(trimmed)
                onGroupChanged()
            }, selectedThemeColor: selectedThemeColor)
        }
    }
}

// Inline small tag list
struct InlineTagListView: View {
    let tags: [String]
    let onTap: (String) -> Void

    var body: some View {
        let maxShow = 6
        HStack(spacing: 6) {
            ForEach(Array(tags.prefix(maxShow)).indices, id: \.self) { idx in
                let tag = tags[idx]
                Button(action: { onTap(tag) }) {
                    Text(tag).font(.caption2).padding(.horizontal, 8).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray6)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            if tags.count > maxShow {
                Text("+\(tags.count - maxShow)").font(.caption2).foregroundColor(.secondary).padding(.leading, 4)
            }
            Spacer()
        }
    }
}

// AddSimilarWordsGroupView: 新しいグループを作るための画面（モーダル）
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
                        words.append(t)
                        newWord = ""
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

// EditSimilarWordsGroupView: 既存グループを編集する画面（モーダル）
struct EditSimilarWordsGroupView: View {
    let group: SimilarWordsGroup
    let onSave: (SimilarWordsGroup) -> Void
    let onDelete: (() -> Void)?
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode

    @State private var name: String
    @State private var words: [String]
    @State private var newWord = ""
    @State private var showDeleteAlert = false

    init(group: SimilarWordsGroup, onSave: @escaping (SimilarWordsGroup) -> Void, onDelete: (() -> Void)? = nil, selectedThemeColor: Color) {
        self.group = group
        self.onSave = onSave
        self.onDelete = onDelete
        self.selectedThemeColor = selectedThemeColor
        self._name = State(initialValue: group.name)
        self._words = State(initialValue: group.words)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("グループ名", text: $name).textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    TextField("単語を追加", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("追加") {
                        let t = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty && !words.contains(t) else { return }
                        words.append(t)
                        newWord = ""
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !words.isEmpty { FlowTagView(tags: words, onRemove: { idx in words.remove(at: idx) }) }
                Spacer()
                Button(action: { showDeleteAlert = true }) {
                    Text("グループを削除").foregroundColor(.white).frame(maxWidth: .infinity).padding().background(RoundedRectangle(cornerRadius: 10).fill(Color.red))
                }
                .padding(.horizontal)
                .alert(isPresented: $showDeleteAlert) {
                    Alert(title: Text("グループの削除"), message: Text("このグループを削除してよいですか？元に戻せません。"), primaryButton: .destructive(Text("削除")) {
                        onDelete?()
                        presentationMode.wrappedValue.dismiss()
                    }, secondaryButton: .cancel())
                }
            }
            .padding()
            .navigationTitle("グループを編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { let updated = SimilarWordsGroup(id: group.id, name: name, words: words); onSave(updated); presentationMode.wrappedValue.dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

// FlowTagView used in add/edit screens
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

// AddWordToGroupView: 単語を一つだけグループに追加するための小さな画面
struct AddWordToGroupView: View {
    let groupName: String
    let onSave: (String) -> Void
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    @State private var newWord = ""
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text("")
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
    SimilarWordsSettingsView(similarWordsGroups: .constant([SimilarWordsGroup(name: "会議関連", words: ["会議","打ち合わせ","ミーティング"])]), selectedThemeColor: .constant(.blue))
}
