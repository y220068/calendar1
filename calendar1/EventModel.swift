// EventModel.swift
// Shared Event model used across views and managers

import Foundation

struct Event: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    var categoryID: String?

    init(id: UUID = UUID(), title: String, startTime: Date, endTime: Date, categoryID: String? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.categoryID = categoryID
    }
}
