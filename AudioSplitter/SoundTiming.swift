//
//  SoundTiming.swift
//  AudioSplitter
//
//  Created by Michael Hand on 8/19/18.
//  Copyright © 2018 Michael Hand. All rights reserved.
//

import Foundation

struct SoundTiming {
    var start: Double
    var end: Double
}

struct XMLTiming : Codable {
    var start: Double
    var end: Double
    var rate: Double
    var path: String
}


