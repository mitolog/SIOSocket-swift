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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.inverted = false
        
        let nib = UINib(nibName: "Cell", bundle: nil)
        self.tableView.registerNib(nib, forCellReuseIdentifier: "Cell")
        
        /* SIOSocket code below */

        if self.socket != nil {
            self.socket.close()
        }
        
        SIOSocket.socketWithHost("http://192.168.43.234:8080", response: { (_socket) -> Void in
            self.socket = _socket
            
            self.socket.onConnect = { [weak self] in
                print("connected")
                self!.socket.emit("connected", args: [self!.userName])
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

