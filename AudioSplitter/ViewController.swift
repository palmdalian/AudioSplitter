//
//  ViewController.swift
//  AudioSplitter
//
//  Created by Michael Hand on 8/4/18.
//  Copyright © 2018 Michael Hand. All rights reserved.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    @IBOutlet weak var processButton: NSButton?
    @IBOutlet weak var inputField: NSTextField?
    @IBOutlet weak var destinationField: NSTextField?
    @IBOutlet weak var detectionSelector: NSPopUpButton?
    @IBOutlet weak var splitSelector: NSPopUpButton?
    var selectedPath: URL?
    var selectedDestination: URL?


    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func inputButtonPressed(sender: NSButton) {
        if let url = NSOpenPanel().selectUrl {
            self.inputField?.stringValue = url.path
            self.selectedPath = url
        }
        if selectedPath != nil && selectedDestination != nil{
            self.processButton?.isEnabled = true
        }
    }
    
    @IBAction func destinationButtonPressed(sender: NSButton) {
        if let url = NSOpenPanel().selectDirectoryURL {
            self.destinationField?.stringValue = url.path
            self.selectedDestination = url
        }
        if selectedPath != nil && selectedDestination != nil{
            self.processButton?.isEnabled = true
        }
    }
    
    @IBAction func processButtonPressed(sender: NSButton) {
        if selectedPath != nil && selectedDestination != nil{
            processFiles(inputURL: selectedPath!, outputDirectory: selectedDestination!, detectionType: (self.detectionSelector?.titleOfSelectedItem)!, trimType: (self.splitSelector?.titleOfSelectedItem)!)
        }
    }

}

