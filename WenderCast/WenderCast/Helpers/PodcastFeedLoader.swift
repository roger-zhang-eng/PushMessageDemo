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
import SWXMLHash

class PodcastFeedLoader: NSObject {
  static let FeedURL = "https://www.raywenderlich.com/category/podcast/feed"
  
  static func loadFeed(_ completion:@escaping ([PodcastItem]) -> ()) {
    guard let url = URL(string: FeedURL) else { return }
    
    URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
      guard let data = data else { return }
      
      let xmlIndexer = SWXMLHash.config { config in
        config.shouldProcessNamespaces = true
        }.parse(data)
      
      let items = xmlIndexer["rss"]["channel"]["item"]
      
      let feedItems = items.map { (indexer: XMLIndexer) -> PodcastItem in
        let dateString = indexer["pubDate"].element!.text!
        let date = DateParser.dateWithPodcastDateString(dateString)
        return PodcastItem(title: indexer["title"].element!.text!, publishedDate: date!, link: indexer["link"].element!.text!)
      }
      
      completion(feedItems)
      }) .resume()
  }
}
