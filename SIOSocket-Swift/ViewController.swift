//
//  ViewController.swift
//  SIOSocket-Swift
//
//  Created by Yuhei Miyazato on 11/26/15.
//  Copyright © 2015 mitolab. All rights reserved.
//

import UIKit
import SlackTextViewController

class ViewController: SLKTextViewController {

    var chats = [String]()
    var socket:SIOSocket!

    let userName = "mitolog"
    let hostName = "http://172.17.165.124:8080"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.inverted = false
        
        let nib = UINib(nibName: "Cell", bundle: nil)
        self.tableView.registerNib(nib, forCellReuseIdentifier: "Cell")

        if self.socket != nil {
            self.socket.close()
        }
        
        self.socket =
        SIOSocket.socketWithHost(self.hostName, response: { [unowned self] (_socket) -> Void in
            
            if _socket != nil {
                self.socket = _socket
                print("socket preparation success")
            } else {
                print("socket preparation error")
                return
            }
            
            self.socket.onConnect = { [weak self] in
                print("connected")
                self!.socket.emit("connected", args: [self!.userName])
            }
            
            self.socket.onError = { (errorInfo:[String:AnyObject]) in
                print("onError: \(errorInfo)")
            }
            
            self.socket.onReconnectionError = { (errorInfo:[String:AnyObject]) in
                print("reconnectionError: \(errorInfo)")
            }
            
            self.socket.on("publish", callback: { (params:[AnyObject]) -> Void in
                print("publish params: \(params)")
            })
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - SLKTextViewController overrides
    override class func tableViewStyleForCoder(decoder: NSCoder!) -> UITableViewStyle {
        return UITableViewStyle.Plain
    }
    
    override func didPressRightButton(sender: AnyObject!) {
        if let chat = self.textView.text {
            self.chats.append(chat)
            self.tableView.reloadData()
            self.socket.emit("publish", args: [chat])
        }
        super.didPressRightButton(sender)
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell")!
        cell.textLabel?.text = chats[indexPath.row]
        return cell
    }
}

