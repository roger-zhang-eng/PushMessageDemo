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
import SafariServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    registerForPushNotifications(application)

    UITabBar.appearance().barTintColor = UIColor.themeGreenColor
    UITabBar.appearance().tintColor = UIColor.white
    
    // Check if launched from notification
    // 1
    if let notification = (launchOptions as? [UIApplicationLaunchOptionsKey: AnyObject])?[UIApplicationLaunchOptionsKey.remoteNotification] as? [String: AnyObject] {
      // 2
      let aps = notification["aps"] as! [String: AnyObject]
      createNewNewsItem(aps)
      // 3
      if let tabController = window?.rootViewController as? UITabBarController {
        tabController.selectedIndex = 1
      }
    }
    
    return true
  }
  
  // MARK: Helpers
  func createNewNewsItem(_ notificationDictionary:[String: AnyObject]) -> NewsItem? {
    if let news = notificationDictionary["alert"] as? String,
      let url = notificationDictionary["link_url"] as? String {
        let date = Date()
        
        let newsItem = NewsItem(title: news, date: date, link: url)
        let newsStore = NewsStore.sharedStore
        newsStore.addItem(newsItem)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: NewsFeedTableViewController.RefreshNewsFeedNotification), object: self)
        return newsItem
    }
    return nil
  }
  
  // MARK: Register for push
  func registerForPushNotifications(_ application: UIApplication) {
    let viewAction = UIMutableUserNotificationAction()
    viewAction.identifier = "VIEW_IDENTIFIER"
    viewAction.title = "View"
    viewAction.activationMode = .foreground

    let newsCategory = UIMutableUserNotificationCategory()
    newsCategory.identifier = "NEWS_CATEGORY"
    newsCategory.setActions([viewAction], for: .default)

    let categories: Set<UIUserNotificationCategory> = [newsCategory]

    let notificationSettings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: categories)
    application.registerUserNotificationSettings(notificationSettings)
  }

  func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
    if notificationSettings.types != UIUserNotificationType() {
      application.registerForRemoteNotifications()
    }
  }
  
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenChars = (deviceToken as NSData).bytes.bindMemory(to: CChar.self, capacity: deviceToken.count)
    var tokenString = ""
    
    for i in 0..<deviceToken.count {
      tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
    }
    
    print("Device Token:", tokenString)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register:", error)
  }
  
  // MARK: Handle notifications
  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    let aps = userInfo["aps"] as! [String: AnyObject]
    
    // 1
    if let contentAvaiable = aps["content-available"] as? NSString, contentAvaiable.integerValue == 1 {
      // Refresh Podcast
      // 2
      let podcastStore = PodcastStore.sharedStore
      podcastStore.refreshItems { didLoadNewItems in
        // 3
        completionHandler(didLoadNewItems ? .newData : .noData)
      }
    } else  {
      // News
      // 4
      createNewNewsItem(aps)
      completionHandler(.newData)
    }
  }
  
  // MARK: Handle notification action
  func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
    // 1
    let aps = userInfo["aps"] as! [String: AnyObject]
    
    // 2
    if let newsItem = createNewNewsItem(aps) {
      if let tabController = window?.rootViewController as? UITabBarController {
        tabController.selectedIndex = 1
      }
      
      // 3
      if identifier == "VIEW_IDENTIFIER", let url = URL(string: newsItem.link) {
        let safari = SFSafariViewController(url: url)
        window?.rootViewController?.present(safari, animated: true, completion: nil)
      }
    }
    
    // 4
    completionHandler()
  }
}

