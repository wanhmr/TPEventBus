//
//  AViewController.swift
//  TPEventBus_Example
//
//  Created by Tpphha on 2019/9/19.
//  Copyright © 2019 wanhmr. All rights reserved.
//

import UIKit
import TPEventBus

class AViewController: UIViewController {
    
    var count: Int = 0
    
    @IBOutlet weak var countLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        TPEventSubscriber<TPCountEvent>.subscribe(eventType: TPCountEvent.self).onNext { (event, object) in
            print("A View Controller count did change: \(event.count)")
        }.disposed(by: self)
    }
    
    @IBAction func addAction(_ sender: Any) {
        count += 1
        self.countLabel.text = "\(count)"
        let event = TPCountEvent.init(count: count)
        TPEventBus.shared.post(event: event, object: self)
    }
    
}
