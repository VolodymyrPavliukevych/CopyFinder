//
//  Hasher.swift
//  Outbyte
//
//  Created by Volodymyr Pavliukevych on 12/15/18.
//  Copyright © 2018 Volodymyr Pavliukevych. All rights reserved.
//

import Foundation
import CommonCrypto

//https://stackoverflow.com/questions/2722943/is-calculating-an-md5-hash-less-cpu-intensive-than-sha-family-functions
/*
 openssl speed md5 sha256
 Doing md5 for 3s on 16 size blocks: 2684944 md5's in 3.00s
 Doing md5 for 3s on 64 size blocks: 1657264 md5's in 3.00s
 Doing md5 for 3s on 256 size blocks: 746919 md5's in 3.00s
 Doing md5 for 3s on 1024 size blocks: 234931 md5's in 2.99s
 Doing md5 for 3s on 8192 size blocks: 32161 md5's in 2.98s
 Doing sha256 for 3s on 16 size blocks: 1014604 sha256's in 2.99s
 Doing sha256 for 3s on 64 size blocks: 529318 sha256's in 2.98s
 Doing sha256 for 3s on 256 size blocks: 216470 sha256's in 2.98s
 Doing sha256 for 3s on 1024 size blocks: 64928 sha256's in 2.99s
 Doing sha256 for 3s on 8192 size blocks: 8690 sha256's in 2.99s
 LibreSSL 2.6.4
 built on: date not available
 options:bn(64,64) rc4(ptr,int) des(idx,cisc,16,int) aes(partial) blowfish(idx)
 compiler: information not available
 The 'numbers' are in 1000s of bytes per second processed.
 type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes
 md5              14319.70k    35354.97k    63737.09k    80457.97k    88410.37k
 sha256            5429.32k    11367.90k    18596.08k    22236.21k    23808.86k
 */

class Hasher {
    static func calc(for path: String, size: Int) throws -> (small: String, full: String?) {
        guard FileManager.default.fileExists(atPath: path) else { throw ModelError.fileNotFound }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let fileSize = attributes[.size] as? Int else { throw ModelError.fileNotFound }
        guard let handler = FileHandle(forReadingAtPath: path) else { throw ModelError.fileNotFound }
        var sizeLength = (fileSize <= size ? fileSize : size)
        var smallHash = "\(fileSize)"
        let bufferSize = 1024 * 1024 * 10
        while sizeLength > 0 {
            let data = handler.readData(ofLength: bufferSize)
            smallHash += data.md5
            sizeLength -= bufferSize
        }
        handler.closeFile()
        return (smallHash, (fileSize <= size ? smallHash : nil))
    }
}

extension Data {
    var md5 : String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ =  self.withUnsafeBytes { bytes in
            CC_MD5(bytes, CC_LONG(self.count), &digest)
        }
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        return digestHex
    }
}
