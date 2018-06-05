/*****************************************************************************
 *
 * FILE:	SQLiteDB.swift
 * DESCRIPTION:	SQLite3: SQLiteDB Primitive Class
 * DATE:	Wed, Jul  5 2017
 * UPDATED:	Tue, Jun  5 2018
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		http://www.MagickWorX.COM/
 * COPYRIGHT:	(c) 2017-2018 阿部康一／Kouichi ABE (WALL), All rights reserved.
 * LICENSE:
 *
 *  Copyright (c) 2017-2018 Kouichi ABE (WALL) <kouichi@MagickWorX.COM>,
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
  public enum Synchronous: Int
  {
    case off = 0
    case normal = 1
    case full = 2
    case extra = 3
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

//  public static let shared: SQLiteDB = SQLiteDB()

  public internal(set) var fileURL: URL? = nil
  public internal(set) var filename: String? = nil

  var handle: OpaquePointer? = nil

  let queue = DispatchQueue(label: "SerialQueue.SQLiteDB", attributes: [])

  public internal(set) lazy var dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return df
  }()

  public init() {
    queue.setSpecific(key: SQLiteDB.queueKey, value: queueContext)
  }

  deinit {
    close()
  }


  /*
   * MARK: - Synchronize
   */
  fileprivate static let queueKey = DispatchSpecificKey<Int>()
  fileprivate lazy var queueContext: Int = unsafeBitCast(self, to: Int.self)

  func sync<T>(_ block: @escaping () throws -> T) rethrows -> T {
    var success: T?
    var failure: Error?

    let box: () -> Void = {
      do {
        success = try block()
      }
      catch let error {
        failure = error
      }
    }
    if DispatchQueue.getSpecific(key: SQLiteDB.queueKey) == queueContext {
      box()
    }
    else {
      queue.sync(execute: box)
    }
    if let failure = failure {
      try { () -> Void in throw failure }()
    }
    return success!
  }

  /*
   * MARK: - Handlers
   */
  // See https://sqlite.org/c3ref/busy_timeout.html
  public var busyTimeout: Double = 0 { // seconds
    didSet {
      sqlite3_busy_timeout(handle, Int32(busyTimeout * 1_000)) // milliseconds
    }
  }

  fileprivate typealias BusyHandler = @convention(block) (Int32) -> Int32
  fileprivate var busyHandler: BusyHandler? = nil

  // See https://sqlite.org/c3ref/busy_handler.html
  public func busyHandler(_ callback: ((_ tries: Int) -> Bool)?) {
    guard let callback = callback else {
      sqlite3_busy_handler(handle, nil, nil)
      busyHandler = nil
      return
    }

    let box: BusyHandler = { callback(Int($0)) ? 1 : 0 }
    sqlite3_busy_handler(handle, { callback, tries in
      unsafeBitCast(callback, to: BusyHandler.self)(tries)
    }, unsafeBitCast(box, to: UnsafeMutableRawPointer.self))
    busyHandler = box
  }
}

extension SQLiteDB.Storage: CustomStringConvertible
{
  public var description: String {
    switch self {
      case .memory:       return ":memory:"
      case .temporary:    return ""
      case .uri(let URI): return URI
    }
  }
}

extension SQLiteDB.Synchronous
{
  func pragma() -> String {
    var mode = "OFF"
    switch self {
      case .off:    mode = "OFF"
      case .normal: mode = "NORMAL"
      case .full:   mode = "FULL"
      case .extra:  mode = "EXTRA"
    }
    return "PRAGMA synchronous = \(mode);"
  }
}

extension SQLiteDB.JournalMode
{
  func pragma() -> String {
    var mode = "OFF"
    switch self {
      case .off:      mode = "OFF"
      case .wal:      mode = "WAL"
      case .delete:   mode = "DELETE"
      case .truncate: mode = "TRUNCATE"
      case .persist:  mode = "PERSIST"
      case .memory:   mode = "MEMORY"
    }
    return "PRAGMA journal_mode = \(mode);"
  }
}

// MARK: - Open/Close Functions
extension SQLiteDB
{
  // http://sqlite.org/c3ref/open.html
  public func open(storage: Storage = .memory, journal mode: JournalMode? = nil, sync: Synchronous? = nil, readonly: Bool = false) -> Bool {
    let flags = readonly
              ? SQLITE_OPEN_READONLY
              : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    let retval = sqlite3_open_v2(storage.description, &handle, flags | SQLITE_OPEN_FULLMUTEX, nil)
    if !readonly && retval == SQLITE_OK {
      if let mode = mode {
        let pragma = mode.pragma()
        self.execute(pragma)
      }
      if let sync = sync {
        let pragma = sync.pragma()
        self.execute(pragma)
      }
    }
    return (retval == SQLITE_OK)
  }

  public func open(_ filename: String, journal mode: JournalMode? = nil, sync: Synchronous? = nil, readonly: Bool = false) -> Bool {
    var retval: Bool = false

    if let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      let fileURL = documentURL.appendingPathComponent(filename)
      retval = self.open(fileURL, journal: mode, sync: sync, readonly: readonly)
    }
    return retval
  }

  public func open(_ fileURL: URL, journal mode: JournalMode? = nil, sync: Synchronous? = nil, readonly: Bool = false) -> Bool {
    let retval = self.open(storage: .uri(fileURL.absoluteString), journal: mode, sync: sync, readonly: readonly)
    if retval {
      self.fileURL  = fileURL
      self.filename = fileURL.lastPathComponent
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
