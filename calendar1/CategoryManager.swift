// CategoryManager.swift
// Manage event categories (add/edit/delete) and persist them in UserDefaults

import Foundation

struct Category: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var isEnabled: Bool

    init(id: String = UUID().uuidString, name: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
    }
}

// Old format for migration: no isEnabled
private struct CategoryOld: Identifiable, Codable {
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
    }

    func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: categoriesKey)
            // Ensure any observers (SwiftUI views) are notified about changes.
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
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

        let decoder = JSONDecoder()
        do {
            // Try new format first (with isEnabled)
            categories = try decoder.decode([Category].self, from: data)
            return
        } catch {
            // Try old format without isEnabled and migrate
            do {
                let old = try decoder.decode([CategoryOld].self, from: data)
                categories = old.map { Category(id: $0.id, name: $0.name, isEnabled: true) }
                // Save migrated format back
                saveCategories()
                return
            } catch {
                print("Failed to load categories (both new and old formats): \(error)")
                categories = []
            }
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

    // Return a set of enabled category IDs for filtering events.
    // This helper is used by ContentView to decide which categories are visible.
    static func enabledCategoryIDs() -> Set<String> {
        return Set(CategoryManager.shared.categories.filter { $0.isEnabled }.map { $0.id })
    }
}
