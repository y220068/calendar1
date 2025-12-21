// CategoryManager.swift
// Manage event categories (add/edit/delete) and persist them in UserDefaults

import Foundation

struct Category: Identifiable, Codable, Equatable {
    let id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

final class CategoryManager: ObservableObject {
    static let shared = CategoryManager()

    @Published var categories: [Category] = []

    private let userDefaults = UserDefaults.standard
    private let categoriesKey = "EventCategories"

    private init() {
        loadCategories()
        // If there are no saved categories, seed a few defaults so the feature is visible immediately.
        if categories.isEmpty {
            categories = [Category(name: "仕事"), Category(name: "プライベート"), Category(name: "健康")]
            saveCategories()
        }
    }

    func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: categoriesKey)
        } catch {
            print("Failed to save categories: \(error)")
        }
    }

    private func loadCategories() {
        guard let data = userDefaults.data(forKey: categoriesKey) else {
            // no saved categories -> start empty
            categories = []
            return
        }
        do {
            categories = try JSONDecoder().decode([Category].self, from: data)
        } catch {
            print("Failed to load categories: \(error)")
            categories = []
        }
    }

    func addCategory(name: String) {
        let c = Category(name: name)
        categories.append(c)
        saveCategories()
    }

    func updateCategory(_ category: Category) {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
            saveCategories()
        }
    }

    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
    }

    func name(for id: String?) -> String? {
        guard let id = id else { return nil }
        return categories.first(where: { $0.id == id })?.name
    }

    func idForName(_ name: String) -> String? {
        return categories.first(where: { $0.name == name })?.id
    }
}
