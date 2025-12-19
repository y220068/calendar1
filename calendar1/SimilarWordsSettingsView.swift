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

// SimilarWordsSettingsView: 類義語グループの設定画面
// - グループ一覧の表示、グループの追加・編集・削除を行います。
// - 画面からの変更は `SimilarWordsManager.shared` を通じて永続化（JSON ファイルまたは UserDefaults）されます。
// - グループ内の単語をタップすると検索ワードとして親画面に渡すことができます（onSelectWord）。

// SimilarWordsSettingsView: 類似語グループの一覧と管理（追加・編集・削除）を行う画面
struct SimilarWordsSettingsView: View {
    @Binding var similarWordsGroups: [SimilarWordsGroup]
    @Binding var selectedThemeColor: Color
    var onSelectWord: ((String) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode

    @State private var newGroupName = ""
    @State private var newWord = ""
    @State private var showAddGroup = false
    @State private var editingGroup: SimilarWordsGroup? = nil
    @State private var editingWord = ""
    @State private var showEditWord = false

    // 保存ヘルパー: シングルトンに反映して永続化
    private func saveSimilarWords() {
        SimilarWordsManager.shared.similarWordsGroups = similarWordsGroups
        SimilarWordsManager.shared.saveSimilarWords()
    }

    var body: some View {
        NavigationView {
            VStack {
                // 説明ボックス: この画面が何をするところかを簡単に説明
                VStack(alignment: .leading, spacing: 8) {
                    Text("類似語の設定")
                        .font(.headline)
                        .foregroundColor(selectedThemeColor)

                    Text("似た意味の単語をグループにまとめると、検索が便利になります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(selectedThemeColor.opacity(0.1)))
                .padding(.horizontal)

                // グループ一覧（なければ案内を表示）
                if similarWordsGroups.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(selectedThemeColor.opacity(0.5))

                        Text("類似語グループがありません")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Text("「+ グループを追加」ボタンで新しいグループを作成してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(similarWordsGroups.indices, id: \.self) { index in
                            SimilarWordsGroupRow(
                                group: $similarWordsGroups[index],
                                selectedThemeColor: selectedThemeColor,
                                onEditGroup: { group in editingGroup = group },
                                onDeleteGroup: {
                                    similarWordsGroups.remove(at: index)
                                    saveSimilarWords()
                                },
                                onTapWord: { word in handleWordSelection(word) },
                                onGroupChanged: { saveSimilarWords() }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { /* 行全体をタップしても何もしない */ }
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                Spacer()
            }
            .navigationTitle("類似語設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(selectedThemeColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("+ グループを追加") { showAddGroup = true }
                        .foregroundColor(selectedThemeColor)
                }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            AddSimilarWordsGroupView(onSave: { groupName, words in
                let newGroup = SimilarWordsGroup(id: UUID().uuidString, name: groupName, words: words)
                similarWordsGroups.append(newGroup)
                saveSimilarWords()
            }, selectedThemeColor: selectedThemeColor)
        }
        .sheet(item: $editingGroup) { group in
            EditSimilarWordsGroupView(group: group, onSave: { updatedGroup in
                if let index = similarWordsGroups.firstIndex(where: { $0.id == updatedGroup.id }) {
                    similarWordsGroups[index] = updatedGroup
                    saveSimilarWords()
                }
            }, selectedThemeColor: selectedThemeColor)
        }
    }
}

// 以下はグループモデルとサブビュー（行、追加フォーム、編集フォーム、単語追加フォーム）です。
// それぞれ簡単に何をするかをコメントしています。

// SimilarWordsGroup: グループのデータ構造（id, 名前, 単語リスト）
struct SimilarWordsGroup: Identifiable, Codable {
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
    let onEditGroup: (SimilarWordsGroup) -> Void
    let onDeleteGroup: () -> Void
    let onTapWord: (String) -> Void
    let onGroupChanged: () -> Void

    @State private var isExpanded = false
    @State private var newWord = ""
    @State private var showAddWord = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー（グループ名と操作ボタン）
            ZStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name).font(.headline).fontWeight(.bold).foregroundColor(selectedThemeColor)
                        Text("\(group.words.count)個の単語").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: selectedThemeColor.opacity(0.1), radius: 2, x: 0, y: 1))
                .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
            .overlay(
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: { showAddWord = true }) { Image(systemName: "plus").font(.caption).foregroundColor(selectedThemeColor).padding(6).background(Circle().fill(selectedThemeColor.opacity(0.1))) }
                        Button(action: { onEditGroup(group) }) { Image(systemName: "pencil").font(.caption).foregroundColor(selectedThemeColor).padding(6).background(Circle().fill(selectedThemeColor.opacity(0.1))) }
                        Button(action: { onDeleteGroup() }) { Image(systemName: "trash").font(.caption).foregroundColor(.red).padding(6).background(Circle().fill(Color.red.opacity(0.1))) }
                    }
                    .padding(.trailing, 16)
                }
            )

            // 単語一覧（個別に削除できる）
            if !group.words.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(group.words.enumerated()), id: \.offset) { index, word in
                        HStack(spacing: 8) {
                            Button(action: { onTapWord(word) }) {
                                HStack { Text(word).font(.body).foregroundColor(.primary); Spacer() }.contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(maxWidth: .infinity)

                            Button(action: {
                                if let firstIndex = group.words.firstIndex(of: word) {
                                    group.words.remove(at: firstIndex)
                                    onGroupChanged()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(selectedThemeColor.opacity(0.05)))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture { /* 防御的に何もしない */ }
        .sheet(isPresented: $showAddWord) {
            AddWordToGroupView(groupName: group.name, onSave: { word in if !word.isEmpty && !group.words.contains(word) { group.words.append(word); onGroupChanged() } }, selectedThemeColor: selectedThemeColor)
        }
    }
}

// AddSimilarWordsGroupView: 新しいグループを作るための画面（モーダル）
struct AddSimilarWordsGroupView: View {
    let onSave: (String, [String]) -> Void
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode

    @State private var groupName = ""
    @State private var words: [String] = []
    @State private var newWord = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("グループ名").font(.headline).foregroundColor(selectedThemeColor)
                    TextField("例: 会議関連", text: $groupName).textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("単語を追加").font(.headline).foregroundColor(selectedThemeColor)
                    HStack {
                        TextField("例: 会議", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("追加") { if !newWord.isEmpty && !words.contains(newWord) { words.append(newWord); newWord = "" } }
                            .foregroundColor(selectedThemeColor).disabled(newWord.isEmpty)
                    }
                }

                if !words.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("追加された単語").font(.headline).foregroundColor(selectedThemeColor)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(words.indices, id: \.self) { index in
                                HStack {
                                    Text(words[index]).font(.caption).foregroundColor(.primary)
                                    Button(action: { words.remove(at: index) }) { Image(systemName: "xmark").font(.caption2).foregroundColor(.red) }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(selectedThemeColor.opacity(0.1)))
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("新しいグループ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { if !groupName.isEmpty { onSave(groupName, words); presentationMode.wrappedValue.dismiss() } }.foregroundColor(selectedThemeColor).disabled(groupName.isEmpty) }
            }
        }
    }
}

// EditSimilarWordsGroupView: 既存グループを編集する画面（モーダル）
struct EditSimilarWordsGroupView: View {
    let group: SimilarWordsGroup
    let onSave: (SimilarWordsGroup) -> Void
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode

    @State private var groupName: String
    @State private var words: [String]
    @State private var newWord = ""

    init(group: SimilarWordsGroup, onSave: @escaping (SimilarWordsGroup) -> Void, selectedThemeColor: Color) {
        self.group = group
        self.onSave = onSave
        self.selectedThemeColor = selectedThemeColor
        self._groupName = State(initialValue: group.name)
        self._words = State(initialValue: group.words)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("グループ名").font(.headline).foregroundColor(selectedThemeColor)
                    TextField("グループ名", text: $groupName).textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("単語を追加").font(.headline).foregroundColor(selectedThemeColor)
                    HStack {
                        TextField("新しい単語", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("追加") { if !newWord.isEmpty && !words.contains(newWord) { words.append(newWord); newWord = "" } }
                            .foregroundColor(selectedThemeColor).disabled(newWord.isEmpty)
                    }
                }

                if !words.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("単語一覧").font(.headline).foregroundColor(selectedThemeColor)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                                HStack { Text(word).font(.caption).foregroundColor(.primary); Button(action: { if let firstIndex = words.firstIndex(of: word) { words.remove(at: firstIndex) } }) { Image(systemName: "xmark").font(.caption2).foregroundColor(.red) } }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(selectedThemeColor.opacity(0.1)))
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("グループを編集")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { let updatedGroup = SimilarWordsGroup(id: group.id, name: groupName, words: words); onSave(updatedGroup); presentationMode.wrappedValue.dismiss() }.foregroundColor(selectedThemeColor).disabled(groupName.isEmpty) }
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
            VStack(spacing: 20) {
                Text("「\(groupName)」グループに単語を追加").font(.headline).foregroundColor(selectedThemeColor)
                TextField("新しい単語", text: $newWord).textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
            }
            .padding()
            .navigationTitle("単語を追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("追加") { onSave(newWord); presentationMode.wrappedValue.dismiss() }.foregroundColor(selectedThemeColor).disabled(newWord.isEmpty) }
            }
        }
    }
}

private extension SimilarWordsSettingsView {
    func handleWordSelection(_ word: String) {
        onSelectWord?(word)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    SimilarWordsSettingsView(similarWordsGroups: .constant([SimilarWordsGroup(name: "会議関連", words: ["会議", "ミーティング", "打ち合わせ"])]), selectedThemeColor: .constant(.blue))
}
