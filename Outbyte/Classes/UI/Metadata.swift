//
//  Metadata.swift
//  Outbyte
//
//  Created by Volodymyr Pavliukevych on 12/15/18.
//  Copyright © 2018 Volodymyr Pavliukevych. All rights reserved.
//

import AppKit

struct Metadata: Equatable {
  let name: String
  let size: Int
  let icon: NSImage?
  let path: String
    
    public enum FileOrder: String {
        case Name
        case Path
        case Size
    }
    
    init(fileDescriptor: FileDescriptor) {
        self.name = fileDescriptor.name
        self.size = fileDescriptor.size
        self.icon = fileDescriptor.icon
        self.path = fileDescriptor.path
    }
    
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        return (lhs.path == rhs.path)
    }
}


func itemComparator<T:Comparable>(lhs: T, rhs: T, ascending: Bool) -> Bool {
    return ascending ? (lhs < rhs) : (lhs > rhs)
}

extension Array where Element == Metadata {
    func contentsOrderedBy(_ orderedBy: Metadata.FileOrder, ascending: Bool) -> [Metadata] {
        let sortedFiles: [Metadata]
        switch orderedBy {
        case .Name:
            sortedFiles = self.sorted {
                return itemComparator(lhs:$0.name, rhs: $1.name, ascending:ascending)
            }
        case .Size:
            sortedFiles = self.sorted {
                return itemComparator(lhs:$0.size, rhs: $1.size, ascending: ascending)
            }
        case .Path:
            sortedFiles = self.sorted {
                return itemComparator(lhs:$0.path, rhs: $1.path, ascending:ascending)
            }
        }
        return sortedFiles
    }

}

