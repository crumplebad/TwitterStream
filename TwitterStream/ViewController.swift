//
//  ViewController.swift
//  TwitterStream
//
//  Created by Jay Gaonkar on 9/12/17.
//  Copyright © 2017 iJay. All rights reserved.
//

import UIKit
import OAuthSwift
import SwiftyJSON
import TwitterAPI
import Accounts

let MAX_TWEETS = 5

class ViewController: UIViewController, UITableViewDataSource, UISearchBarDelegate {

    @IBOutlet weak var filterBar: UISearchBar!
    @IBOutlet weak var tweetTable: UITableView!
    var refershControl: UIRefreshControl = UIRefreshControl()
    var tweetArray = [String]()
    var streamingRequest: StreamingRequest?//weak var does not work

    
    override func viewDidLoad() {
        super.viewDidLoad()
        tweetTable.rowHeight = UITableViewAutomaticDimension
        tweetTable.estimatedRowHeight = 44
        tweetTable.addSubview(refershControl)
        refershControl.addTarget(self, action:#selector(ViewController.refreshTweets), for:.valueChanged)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweetArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TweetTableViewCell", for: indexPath) as! TweetTableViewCell
        cell.tweetLabel?.text = tweetArray[indexPath.row]

        return cell
    }

    func refreshTweets() {
        guard let filterText = filterBar.text else { return }
        
        if filterText != "" {
            animateRefresh(true)
            clearTable()
            authenticateWithTwitter(andFilter: filterText)
        } else {
            showErrorAlert("Enter filter string")
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        refreshTweets()
    }
    
    func authenticateWithTwitter(andFilter: String) {
        let accountStore = ACAccountStore()
        let accountType = accountStore.accountType(withAccountTypeIdentifier: ACAccountTypeIdentifierTwitter)
        accountStore.requestAccessToAccounts(with: accountType, options: nil) {[unowned self] (granted, error) in
            if !granted {
                self.showErrorAlert("Twitter Stream does not have access to your Twitter Account. Go to iOS Settings and provide access.")
                
                return
            }
            
            let accounts = accountStore.accounts(with: accountType) as! [ACAccount]
            guard let account = accounts.first else {
                self.showErrorAlert("There are no Twitter accounts configured. You can add or create a Twitter account in Settings.")
                
                return
            }
            self.getTweets(forAccount: account, filterText: andFilter)
            
        }
    }
    
    func getTweets(forAccount: ACAccount,  filterText: String) {
        let accountClient = AccountClient(account: forAccount)
        var filterString = filterText.replacingOccurrences(of: " ", with: "%20")
        filterString = filterString.replacingOccurrences(of: ",", with: "%2C")
            
        streamingRequest = accountClient
            .streaming("https://stream.twitter.com/1.1/statuses/filter.json?track=\(filterString)")
            
            .progress({(data: Data) -> Void in
                let json = JSON(data: data)
                let tweetStr = json["text"].stringValue
                if (self.tweetArray.count) < MAX_TWEETS {
//                          self?.tweetArray.append(tweetStr)///oldest on top
                    self.tweetArray.insert(tweetStr, at: 0)//newest on top
                }
                if (self.tweetArray.count) == MAX_TWEETS {
                    self.stopStreamRequest()
                    DispatchQueue.main.async {
                        self.tweetTable.reloadData()
                        self.animateRefresh(false)
                    }
                }
            })
            
            .completion({(responseData: Data?, response: URLResponse?, error: NSError?) -> Void in
                DispatchQueue.main.async {
                    self.animateRefresh(false)
                    if error != nil {
                        if !(error?.description.contains("cancelled"))! {
                            self.clearTable()
                            self.showErrorAlert((error?.description)!)
                        }
                    }
                }
            })
            .start()
    }
    
    //Reason this is done outside is: stopping stream control can be given to the user instead of limiting it to a fixed nukmber say 5
    func stopStreamRequest() {
        _ = streamingRequest?.stop()
        streamingRequest = nil
    }
    
    func showErrorAlert(_ errorStr:String) {
        let alert = UIAlertController(title: "Message", message: errorStr, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (alert: UIAlertAction!) in
            self.animateRefresh(false)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func animateRefresh(_ state:Bool) {
        if state && !refershControl.isRefreshing {
            refershControl.beginRefreshing()
            tweetTable.setContentOffset(CGPoint(x: 0, y: -44), animated: true)
        } else {
            refershControl.endRefreshing()
            tweetTable.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        }
    }
    
    func clearTable() {
        tweetArray = []
        tweetTable.reloadData()
    }
}
