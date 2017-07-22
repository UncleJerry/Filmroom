//
//  Extension.swift
//  Filmroom
//
//  Created by 周建明 on 2017/7/22.
//  Copyright © 2017年 Uncle Jerry. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func ErrorAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: "Alright", style: .default, handler: nil)
        alertController.addAction(defaultAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
}
