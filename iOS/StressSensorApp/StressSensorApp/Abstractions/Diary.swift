//
//  Diary.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 01/04/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import PromiseKit

enum DiaryError: Error {
    case notLoaded, unknown
}

class Diary {

    struct Entry: Codable {
        var date: Date
        var notes: String

        init?(notes: String?, date: Date) {
            guard let notes = notes, notes.count > 0 else { return nil }
            self.notes = notes
            self.date = date
        }
    }

    struct Content: Codable {
        fileprivate(set) var entries = [Entry]()
    }

    private(set) static var content = Content()
    private(set) static var loaded = false

    static var entries: [Entry] { return content.entries }

    static func load() -> Promise<Void> {
        return firstly {
            loadFromDisk()
        }.recover { _ in
            loadFromRemote()
        }.done {
            self.content = $0
            self.loaded = true
            self.save()
        }
    }

    static func log(_ entry: Entry) throws {
        guard loaded else { throw DiaryError.notLoaded }
        content.entries.append(entry)
        save()
    }

    private static func save() {
        try? content.toFile(Constants.diaryPath)
    }

    private static func loadFromDisk() -> Promise<Content> {
        print("Diary.loadFromDisk()")
        return Promise().compactMap { Content.fromFile(Constants.diaryPath) }
    }

    private static func loadFromRemote() -> Promise<Content>  {
        print("Diary.loadFromRemote()")
        return ModelLogger.pullDiary().map { Content(entries: $0) }
    }
}
