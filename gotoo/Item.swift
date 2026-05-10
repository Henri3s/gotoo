//
//  Item.swift
//  gotoo
//
//  Created by Henri on 2026/5/10.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
