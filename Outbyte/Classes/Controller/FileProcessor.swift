//
//  FileProcessor.swift
//  Outbyte
//
//  Created by Volodymyr Pavliukevych on 12/15/18.
//  Copyright © 2018 Volodymyr Pavliukevych. All rights reserved.
//

import Foundation

protocol FileProcessor {
    func launch(progress: ProgressHandler?, callback: @escaping  ResultCompletion<[[FileDescriptor]]>)
    func abort(completion: @escaping ResultCompletion<Void>)
}

class Processor {
    var model: Model
    init() throws {
        try self.model = Model()
    }
}

extension Processor: FileProcessor {
    func launch(progress: ProgressHandler?, callback: @escaping ResultCompletion<[[FileDescriptor]]>) {
        model.searchCopies(level: .index, progress: progress) { [weak self] (indexResult) in
            guard let wSelf = self else { return }
            
            indexResult.onNegative { callback($0.toResult()) }
            indexResult.onPositive { _ in
                wSelf.model.searchCopies(level: .height, progress: progress, callback: { (heightResult) in
                    heightResult.onNegative { callback($0.toResult()) }
                    heightResult.onPositive { _ in
                        wSelf.model.searchCopies(level: .full, progress: progress, callback: { (fullResult) in
                            fullResult.onNegative { callback($0.toResult()) }
                            fullResult.onPositive { callback(.positive(value: $0)) }
                            wSelf.model.isInProgress = false
                        })
                    }
                })
            }
        }
    }
    
    func abort(completion: @escaping ResultCompletion<Void>) {
            model.isInProgress = false
    }
    
}
