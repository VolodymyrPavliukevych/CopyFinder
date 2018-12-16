//
//  Model.swift
//  Outbyte
//
//  Created by Volodymyr Pavliukevych on 12/15/18.
//  Copyright © 2018 Volodymyr Pavliukevych. All rights reserved.
//

import Foundation
import AppKit

typealias ProgressHandler = (_ value: Double, _ found: [FileDescriptor], _ level: SearchLevel) -> Void
// To store information for eatch file.
class FileDescriptor {
    let path: String
    let name: String
    let size: Int
    let icon: NSImage?
    var id: Int {
        return path.hashValue
    }
    static let smallHashOfFileSize: Int = 10240
    
    // At first, we calc only small hash for first 0..<1024 bytes
    // search for copies.
    var smallHash: String
    // If we found copy, resolve deepper copies.
    var fullHash: String?
    init?(path: String, property: [URLResourceKey : Any], smallHash: String, fullHash: String? = nil) {
        self.path = path
        self.smallHash = smallHash
        self.fullHash = fullHash
        
        guard let name = property[.localizedNameKey] as? String, let size = property[.fileSizeKey] as? Int, let icon = property[.effectiveIconKey] as? NSImage else {
          return nil
        }

        self.name = name
        self.size = size
        self.icon = icon
    }
    
    func hash(for level: SearchLevel) throws -> String {
        switch level {
        case .height:
            return smallHash
        case .full:
            if let fullHash = fullHash {
                return fullHash
            }
            let full = try Hasher.calc(for: path, size: Int.max).small
            self.fullHash = full
            return full
        case .index:
            return smallHash
        }
    }
}

enum ModelError: Error {
    case folderNotFound
    case fileNotFound
    case homeFolderNotFound
    case searchIsInProgress
    case abort
}

enum SearchLevel: CaseIterable {
    case index
    case height
    case full
}

class Model {
    
    var descriptions = [FileDescriptor]()
    let path: String
    var progressHandler: ProgressHandler? = nil
    var isInProgress = false
    init() throws {
        guard let homeFolder = NSHomeDirectoryForUser(NSUserName()) else {
            throw ModelError.homeFolderNotFound
        }
        self.path = homeFolder
    }
    
    init(folder path: String) {
        self.path = path
    }
    
    private func index(progress: ProgressHandler?, callback: @escaping ResultCompletion<[[FileDescriptor]]>) {
        guard !isInProgress else {
            callback(.negative(error: ModelError.searchIsInProgress))
            return
        }
        isInProgress = true

        guard let url = URL(string: self.path) else {
            callback(.negative(error: ModelError.folderNotFound))
            return
        }
        let requiredAttributes: [URLResourceKey] = [.localizedNameKey, .effectiveIconKey, .typeIdentifierKey, .contentModificationDateKey, .fileSizeKey, .isDirectoryKey, .isPackageKey]
        
        let enumerator = FileManager.default.enumerator(at: url,
                                                        includingPropertiesForKeys: requiredAttributes,
                                                        options: .skipsHiddenFiles,
                                                        errorHandler: nil)
        guard let folderEnumerator = enumerator else {
            callback(.negative(error: ModelError.folderNotFound))
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let wSelf = self else { return }
            for file in folderEnumerator {
                if !wSelf.isInProgress {
                    callback(.negative(error: ModelError.abort))
                    return
                }
                guard let fileURL = file as? NSURL, let filePath = fileURL.path else { continue }
                let property = try! fileURL.resourceValues(forKeys: requiredAttributes)

                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) else { continue }
                guard isDirectory.boolValue == false else { continue }
                guard let hash = try? Hasher.calc(for: filePath, size: FileDescriptor.smallHashOfFileSize) else { continue }
                
                guard let file = FileDescriptor(path: filePath,
                                                property: property,
                                                smallHash: hash.small,
                                                fullHash: hash.full) else { continue }
                
                progress?(1.0, [file], .index)
                wSelf.descriptions.append(file)
            }
            callback(.positive(value: [wSelf.descriptions]))
        }
    }
    
    func searchCopies(level: SearchLevel, progress: ProgressHandler?, callback: @escaping ResultCompletion<[[FileDescriptor]]>) {
        guard level != .index else {
            self.descriptions.removeAll()
            index(progress: progress, callback: callback)
            return
        }
        
        var result = [[FileDescriptor]]()
        let progressStep = 100.0 / Double(descriptions.count)
        do {
            while self.descriptions.count != 0 {
                // Check is in progress
                if !self.isInProgress {
                    callback(.negative(error: ModelError.abort))
                    return
                }

                guard let description = self.descriptions.first else { continue }
                let currnetHash = try description.hash(for: level)
                // Search for copies in that deep level
                let copies = try self.descriptions.enumerated().filter({ (file: (offset: Int, element: FileDescriptor)) -> Bool in
                    return try file.element.hash(for: level) == currnetHash && file.element.id != description.id
                })
                // If copies found, add to progress and result
                if copies.count > 1 {
                    result.append(copies.map { $0.element })
                    let step = 100.0 - (progressStep * Double(self.descriptions.count))
                    progress?(step, copies.map { $0.element }.filter { $0.fullHash != nil }, level)
                }
                
                let indexes = copies.map { $0.offset }.sorted().reversed()
                // Remove myself
                self.descriptions.remove(at: 0)
                // Remove founded copies
                for index in indexes {
                    self.descriptions.remove(at: index)
                }
            }
        } catch {
            callback(.negative(error: error))
        }
        callback(.positive(value:result))
    }
}
