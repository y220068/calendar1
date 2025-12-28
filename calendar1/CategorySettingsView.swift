// CategorySettingsView.swift
// UI to add/edit/delete categories managed by CategoryManager

import SwiftUI

struct CategorySettingsView: View {
    @Binding var categories: [Category]
    @Binding var selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode

    @State private var showAdd = false
    @State private var editingIndex: Int? = nil

    private func save() {
        CategoryManager.shared.categories = categories
        CategoryManager.shared.saveCategories()
    }

    var body: some View {
        NavigationView {
            VStack {
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
                    List {
                        ForEach(categories.indices, id: \.self) { idx in
                            HStack {
                                // Category name on the left
                                Text(categories[idx].name)
                                    .lineLimit(1)

                                Spacer()

                                // Toggle on the right to make on/off immediately visible
                                // Show a visible label so the toggle is easier to spot in the UI
                                Toggle("表示", isOn: Binding(get: { categories[idx].isEnabled }, set: { newVal in
                                    // Create updated category and propagate change via manager so observers are notified
                                    var updated = categories[idx]
                                    updated.isEnabled = newVal
                                    // Update shared manager (this will save and notify observers)
                                    CategoryManager.shared.updateCategory(updated)
                                    // Keep local binding array in sync
                                    categories[idx] = updated
                                }))
                                .toggleStyle(SwitchToggleStyle(tint: selectedThemeColor))
                                .padding(.trailing, 8)

                                // Edit button
                                Button(action: { editingIndex = idx }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 8)

                                // Delete button
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
                        .onDelete { offsets in
                            offsets.forEach { categories.remove(at: $0) }
                            save()
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                Spacer()
            }
            .navigationTitle("カテゴリ設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(selectedThemeColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showAdd = true }) { Image(systemName: "plus") }
                            .foregroundColor(selectedThemeColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddCategoryView(onSave: { name in
                let cat = Category(name: name)
                categories.append(cat)
                save()
            }, selectedThemeColor: selectedThemeColor)
        }
        .sheet(item: Binding(get: { editingIndex == nil ? nil : categories[editingIndex!] }, set: { _ in editingIndex = nil })) { cat in
            // Find index again
            let idx = categories.firstIndex(where: { $0.id == cat.id })
            if let idx = idx {
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

struct AddCategoryView: View {
    let onSave: (String) -> Void
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextField("カテゴリ名", text: $name).textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
            }
            .padding()
            .navigationTitle("新しいカテゴリ")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { onSave(name); presentationMode.wrappedValue.dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

struct EditCategoryView: View {
    @Binding var category: Category
    let onSave: (() -> Void)?
    let onDelete: (() -> Void)?
    let selectedThemeColor: Color
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String = ""
    @State private var showDeleteAlert = false

    init(category: Binding<Category>, onSave: (() -> Void)? = nil, onDelete: (() -> Void)? = nil, selectedThemeColor: Color) {
        self._category = category
        self.onSave = onSave
        self.onDelete = onDelete
        self.selectedThemeColor = selectedThemeColor
        self._name = State(initialValue: category.wrappedValue.name)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextField("カテゴリ名", text: $name).textFieldStyle(RoundedBorderTextFieldStyle())

                Spacer()

                Button(action: { showDeleteAlert = true }) {
                    Text("カテゴリを削除").foregroundColor(.white).frame(maxWidth: .infinity).padding().background(RoundedRectangle(cornerRadius: 10).fill(Color.red))
                }
                .alert(isPresented: $showDeleteAlert) {
                    Alert(title: Text("カテゴリを削除"), message: Text("このカテゴリを削除しますか？"), primaryButton: .destructive(Text("削除")) {
                        onDelete?()
                        presentationMode.wrappedValue.dismiss()
                    }, secondaryButton: .cancel())
                }
            }
            .padding()
            .navigationTitle("カテゴリを編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { category.name = name; onSave?(); presentationMode.wrappedValue.dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}

#Preview {
    CategorySettingsView(categories: .constant([Category(name: "仕事"), Category(name: "プライベート")] ), selectedThemeColor: .constant(.blue))
}
