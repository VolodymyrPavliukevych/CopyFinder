//
//  Result.swift
//  Outbyte
//
//  Created by Volodymyr Pavliukevych on 12/15/18.
//  Copyright © 2018 Volodymyr Pavliukevych. All rights reserved.
//

import Foundation

import Foundation

public typealias ResultCompletion<T> = (_ result: Result<T>) -> Void
enum ResultError: Error {
    case noValueNoErrorCase
}
public enum Result<T> {
    case positive(value: T)
    case negative(error: Error)
    
    public var error: Error? {
        switch self {
        case let .negative(error):
            return error
        default:
            return nil
        }
    }
    
    public var value: T? {
        switch self {
        case let .positive(value):
            return value
        default:
            return nil
        }
    }
    
    public init(value: T?, error: Error?) {
        if let value = value {
            self = .positive(value: value)
        } else {
            self = .negative(error: error ?? ResultError.noValueNoErrorCase)
        }
    }
    
    public func combining<R>(otherResult: Result<R>) -> Result<(T, R)> {
        switch self {
        case let .positive(value):
            switch otherResult {
            case let .positive(otherValue):
                return .positive(value: (value, otherValue))
            case let .negative(error):
                return error.toResult()
            }
        case let .negative(error):
            return error.toResult()
        }
    }
}

extension Error {
    public func toResult<T>() -> Result<T> {
        return .negative(error: self)
    }
}

extension Result where T == Void {
    public static var positive: Result<T> {
        return .positive(value: ())
    }
}

extension Result {
    public var empty: Result<Void> {
        switch self {
        case let .negative(error):
            return error.toResult()
        case .positive:
            return .positive
        }
    }
    
    public func onPositive(_ handler: (_ value: T) -> Void) {
        switch self {
        case .positive(let value):
            handler(value)
        default:
            break
        }
    }
    
    public func onNegative(_ handler: (_ error: Error) -> Void) {
        switch self {
        case .negative(let error):
            handler(error)
        default:
            break
        }
    }
    
    public func map<R>(_ transform: (T) throws -> R) -> Result<R> {
        do {
            switch self {
            case .positive(let value):
                return .positive(value: try transform(value))
            case .negative(let error):
                return error.toResult()
            }
        } catch {
            return error.toResult()
        }
    }
}
