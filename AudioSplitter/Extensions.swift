//
//  Extensions.swift
//  AudioSplitter
//
//  Created by Michael Hand on 8/5/18.
//  Copyright © 2018 Michael Hand. All rights reserved.
//

import Foundation
import Cocoa

extension NSOpenPanel {
    var selectUrl: URL? {
        title = "Select File or Directory"
        allowsMultipleSelection = false
        canChooseDirectories = true
        canChooseFiles = true
        canCreateDirectories = true
        allowedFileTypes = ["m4a","mp4","wav","mp3", "mov", "WAV", "aif", "AIFF"]
        return runModal() == .OK ? urls.first : nil
    }
    var selectDirectoryURL: URL? {
        title = "Select Directory"
        allowsMultipleSelection = false
        canChooseDirectories = true
        canChooseFiles = false
        canCreateDirectories = true
        return runModal() == .OK ? urls.first : nil
    }
}
