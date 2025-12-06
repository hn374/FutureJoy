//
//  Item.swift
//  Forward
//
//  Created by Hoang Nguyen on 12/5/25.
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
