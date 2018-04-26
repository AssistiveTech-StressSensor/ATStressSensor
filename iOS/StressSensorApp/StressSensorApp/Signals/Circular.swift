//
//  Circular.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 20/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

class Circular<T> {

    private var auxArray: Array<T>
    private(set) var head: Int
    private(set) var count: Int
    private let placeholder: T
    let capacity: Int

    // [x][x][x][x][x][ ][ ][ ][ ]
    //                 ^----- head

    var isEmpty: Bool {
        return count == 0
    }

    var isFull: Bool {
        return count == capacity
    }

    var first: T? {
        if isEmpty { return nil }
        return self[0]
    }

    var last: T? {
        if isEmpty { return nil }
        return self[count-1]
    }

    init(capacity: Int, placeholder: T) {
        if capacity < 1 {
            fatalError("Capacity must be at least 1")
        }
        auxArray = Array<T>(repeating: placeholder, count: capacity)
        head = 0
        count = 0
        self.capacity = capacity
        self.placeholder = placeholder
    }

    func toArray() -> Array<T> {
        if isEmpty { return [] }
        let leftSlice = head > 0 ? Array(auxArray[0..<head]) : []
        if isFull {
            let rightSlice = Array(auxArray[head..<capacity])
            return rightSlice + leftSlice
        } else {
            return leftSlice
        }
    }

    subscript(index: Int) -> T {
        return element(at: index)
    }

    func element(at index: Int) -> T {
        if index < 0 || index >= count {
            fatalError("Index out of bounds")
        }
        return auxArray[index % capacity]
    }

    func push(_ element: T) {
        auxArray[head] = element
        head = (head + 1) % capacity
        count = min(count+1, capacity)
    }
}
