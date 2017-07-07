/*****************************************************************************
 *
 * FILE:	Execute.swift
 * DESCRIPTION:	SQLite3: Execution Methods for SQLiteDB
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

public typealias SQLiteFetchResult = [String:String]

fileprivate typealias CVoidPointer = UnsafeMutableRawPointer
fileprivate typealias CCharPointer = UnsafeMutablePointer<CChar>
fileprivate typealias CCharHandle  = UnsafeMutablePointer<CCharPointer?>

fileprivate var resultSet = [SQLiteFetchResult]()

fileprivate func
callback(resultVoidPointer: CVoidPointer?, // void *NotUsed 
               columnCount: Int32,         // int argc
                    values: CCharHandle?,  // char **argv     
                   columns: CCharHandle?   // char **azColName
        ) -> Int32
{
  if let values = values, let columns = columns {
    var result: SQLiteFetchResult = [:]
    for i in 0 ..< Int(columnCount) {
      guard let  value = values[i]  else { continue }
      guard let column = columns[i] else { continue }
      let strCol = String(cString: column)
      let strVal = String(cString: value)
      result[strCol] = strVal
    }
    resultSet.append(result)
  }
  return 0 // status ok
}

extension SQLiteDB
{
  @discardableResult
  public func execute(_ SQL: String, result: inout [SQLiteFetchResult]) -> Bool {
    resultSet.removeAll()
    var retval: Int32 = -1
    queue.sync { [weak self] in
      if let weakSelf = self, let handle = weakSelf.handle {
        retval = sqlite3_exec(handle, SQL, callback, nil, nil)
      }
    }
    result = resultSet
    return (retval == SQLITE_OK)
  }
}

extension SQLiteDB
{
  @discardableResult public func execute(_ SQL: String) -> Bool {
    var errmsg: CCharPointer? = nil
    var retval: Int32 = -1
    queue.sync { [weak self] in
      if let weakSelf = self, let handle = weakSelf.handle {
        retval = sqlite3_exec(handle, SQL, nil, nil, &errmsg)
      }
    }
    if retval != SQLITE_OK {
      if let cText = errmsg {
        let mesg = String(cString: cText)
        print("Error: \(mesg)")
      }
      sqlite3_free(errmsg)
    }
    return (retval == SQLITE_OK)
  }
}
