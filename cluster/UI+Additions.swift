//
//  UI+Additions.swift
//  cluster
//
//  Created by Jeff Jackson on 12/28/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import UIKit

extension UIColor {
    
    // Integer RGB initializer
    //
    public convenience init(r: Int, g: Int, b: Int, a: CGFloat = 1.0) {
        self.init(red:CGFloat(r)/255.0, green:CGFloat(g)/255.0, blue:CGFloat(b)/255.0, alpha: a)
    }
}
