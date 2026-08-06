//
//  clashmiWidgetBundle.swift
//  clashmiWidget
//
//  Created by user on 2026/1/19.
//

import WidgetKit
import SwiftUI

@main
struct clashmiWidgetBundle: WidgetBundle {
    var body: some Widget {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            clashmiWidgetControl()
        } else {
            clashmiStatusWidget()
        }
        #else
        clashmiStatusWidget()
        #endif
    }
}
