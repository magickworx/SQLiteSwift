/*****************************************************************************
 *
 * FILE:	RootViewController.swift
 * DESCRIPTION:	SQLiteSwiftDemo: SQLiteDB View Controller
 * DATE:	Fri, Jul  7 2017
 * UPDATED:	Wed, Nov 29 2017
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
 * $Id: AppDelegate.m,v 1.6 2017/04/12 09:59:00 kouichi Exp $
 *
 *****************************************************************************/

import UIKit
import SQLiteSwift

class RootViewController: BaseViewController
{
  var textView: UITextView = UITextView()
  var tableView: UITableView = UITableView()
  var tableData: [SQLiteFetchResult] = []

  let sentence: String = 
      "CREATE TABLE user(name TEXT, age INTEGER);" + "\n" +
      "INSERT INTO user(name, age) VALUES('Alice',13);" + "\n" +
      "INSERT INTO user(name, age) VALUES('Becky',17);" + "\n" +
      "INSERT INTO user(name, age) VALUES('Charlotte',21);" + "\n" +
      "INSERT INTO user(name, age) VALUES('Diana',15);" + "\n" +
      "INSERT INTO user(name, age) VALUES('Elizabeth',19);"
#if true
  let fetchStatement = "SELECT * FROM user;"
#else
  let fetchStatement = "SELECT * FROM user ORDER BY age;"
#endif

  override func setup() {
    super.setup()

    self.title = "SQLite"
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func loadView() {
    super.loadView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let  width: CGFloat = self.view.bounds.size.width
    let height: CGFloat = self.view.bounds.size.height
    let x: CGFloat = 0.0
    var y: CGFloat = 0.0
    let w: CGFloat = width
    var h: CGFloat = 120.0

    textView.frame = CGRect(x: x, y: y, width: w, height: h)
    textView.font = UIFont.systemFont(ofSize: 12.0)
    textView.text = sentence
    textView.isEditable = false
    self.view.addSubview(textView)

    y += h
    h  = height - y
    tableView.frame = CGRect(x: x, y: y, width: w, height: h)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 48
    tableView.allowsSelection = false
    tableView.separatorStyle = .none
    tableView.contentInsetAdjustmentBehavior = .never
    self.view.addSubview(tableView)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    self.navigationController?.navigationBar.isHidden = false
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    SQLiteDemo()
  }
}

extension RootViewController
{
  func SQLiteDemo() {
    let sqlitedb = SQLiteDB()
    if sqlitedb.open(mode: .off) {
      var lines: [String] = []
      sentence.enumerateLines { line, _ in
        lines.append(line)
      }
      for line in lines {
        sqlitedb.execute(line)
      }

      var result = [SQLiteFetchResult]()
      sqlitedb.execute(fetchStatement, result: &result)
      sqlitedb.close()

      tableData = result
      DispatchQueue.main.async() { [weak self] in
        if let weakSelf = self {
          weakSelf.tableView.reloadData()
        }
      }
    }
  }
}

/*
 * MARK: - UITableViewDataSource
 */
extension RootViewController: UITableViewDataSource
{
  func create_UITableViewCell() -> UITableViewCell {
    let cell: UITableViewCell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
    cell.selectionStyle = .none
    cell.textLabel?.font = UIFont.systemFont(ofSize: 14.0)
    cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14.0)

    return cell
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableData.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = self.create_UITableViewCell()

    let row = indexPath.row
    let result: SQLiteFetchResult = tableData[row]
    cell.textLabel?.text = result["name"]
    cell.detailTextLabel?.text = result["age"]

    return cell
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return fetchStatement
  }
}

/*
 * MARK: - UITableViewDelegate
 */
extension RootViewController: UITableViewDelegate
{
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableViewAutomaticDimension
  }

  func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableViewAutomaticDimension
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
}
