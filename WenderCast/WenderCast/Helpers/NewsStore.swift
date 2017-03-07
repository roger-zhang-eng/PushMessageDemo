/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit

class NewsStore: NSObject {
  static let sharedStore = NewsStore()
  
  var items: [NewsItem] = []
  
  override init() {
    super.init()
    self.loadItemsFromCache()
  }
  
  func addItem(_ newItem: NewsItem) {
    items.insert(newItem, at: 0)
    saveItemsToCache()
  }
}


// MARK: Persistance
extension NewsStore {
  func saveItemsToCache() {
    NSKeyedArchiver.archiveRootObject(items, toFile: itemsCachePath)
  }
  
  func loadItemsFromCache() {
    if let cachedItems = NSKeyedUnarchiver.unarchiveObject(withFile: itemsCachePath) as? [NewsItem] {
      items = cachedItems
    }
  }
  
  var itemsCachePath: String {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsURL.appendingPathComponent("news.dat")
    return fileURL.path
  }
}
