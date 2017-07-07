/*****************************************************************************
 *
 * FILE:	SQLiteDB.swift
 * DESCRIPTION:	SQLite3: SQLiteDB Primitive Class
 * DATE:	Wed, Jul  5 2017
 * UPDATED:	Thu, Jul  6 2017
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * COPYRIGHT:	(c) 2017 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 *   ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 *   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *   PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
 *   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *   INTERRUPTION)  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 *   THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $Id$
 *
 *****************************************************************************/

import SQLite3
import Foundation

public final class SQLiteDB
{
  public enum Storage
  {
    case memory
    case temporary
    case uri(String)
  }

  // https://sqlite.org/pragma.html
  public enum JournalMode: Int
  {
    case off = 0
    case wal = 1
    case delete = 2
    case truncate = 3
    case persist = 4
    case memory = 5
  }

  public static let shared: SQLiteDB = SQLiteDB()

  public internal(set) var fileURL: URL? = nil
  public internal(set) var filename: String? = nil

  var handle: OpaquePointer? = nil

  let queue = DispatchQueue(label: "queue.SQLiteDB", attributes: [])

  let dateFormatter = DateFormatter()

  init() {
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  }

  deinit {
    close()
  }
}

extension SQLiteDB.Storage: CustomStringConvertible
{
  public var description: String {
    switch self {
      case .memory:
        return ":memory:"
      case .temporary:
        return ""
      case .uri(let URI):
        return URI
    }
  }
}

extension SQLiteDB.JournalMode
{
  func pragma() -> String {
    var mode = "OFF"
    switch self {
      case .off:
        mode = "OFF"
      case .wal:
        mode = "WAL"
      case .delete:
        mode = "DELETE"
      case .truncate:
        mode = "TRUNCATE"
      case .persist:
        mode = "PERSIST"
      case .memory:
        mode = "MEMORY"
    }
    return "PRAGMA journal_mode = \(mode);"
  }
}

// MARK: - Open/Close Functions
extension SQLiteDB
{
  // http://sqlite.org/c3ref/open.html
  public func open(storage: Storage = .memory, mode: JournalMode? = nil, readonly: Bool = false) -> Bool {
    let flags = readonly
              ? SQLITE_OPEN_READONLY
              : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    let retval = sqlite3_open_v2(storage.description, &handle, flags | SQLITE_OPEN_FULLMUTEX, nil)
    if !readonly && retval == SQLITE_OK, let mode = mode {
      let pragma = mode.pragma()
      self.execute(pragma)
    }
    return (retval == SQLITE_OK)
  }

  public func open(_ filename: String, mode: JournalMode? = nil, readonly: Bool = false) -> Bool {
    var retval: Bool = false

    if let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      let fileURL = documentURL.appendingPathComponent(filename)
      retval = self.open(storage: .uri(fileURL.absoluteString), mode: mode, readonly: readonly)
      if retval {
        self.fileURL = fileURL
        self.filename = filename
      }
    }
    return retval
  }

  public func close() {
    if let handle = self.handle {
      sqlite3_close(handle)
    }
    self.handle = nil
    self.fileURL = nil
    self.filename = nil
  }
}

extension SQLiteDB
{
  @discardableResult func check(_ resultCode: Int32) throws -> Int32 {
    guard let error = SQLiteResult(errorCode: resultCode, handle: handle!)
          else { return resultCode }
    throw error
  }
}

public enum SQLiteResult: Error
{
  static let successCodes: Set = [ SQLITE_OK, SQLITE_ROW, SQLITE_DONE ]

  case error(message: String, code: Int32)

  init?(errorCode: Int32, handle: OpaquePointer) {
    guard !SQLiteResult.successCodes.contains(errorCode) else { return nil }

    let message = String(cString: sqlite3_errmsg(handle))
    self = .error(message: message, code: errorCode)
  }
}
