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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.red
        TPEventBus.shared.register(eventType: TPTestEvent.self, observer: self, selector: #selector(self.onTestEvent(event:)))
    }
    
    @objc func onTestEvent(event: TPTestEvent) {
        print("Swift event: \(event.name)")
    }
    
}
