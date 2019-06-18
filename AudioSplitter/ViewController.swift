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
    @IBOutlet weak var progressBar: NSProgressIndicator?
    var selectedPath: URL?
    var selectedDestination: URL?


    override func viewDidLoad() {
        super.viewDidLoad()
        setDefaultSettings()
        self.progressBar?.stopAnimation(nil)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func setDefaultSettings() {
        if UserDefaults.standard.string(forKey: "dbThreshold") == nil{
            UserDefaults.standard.set(-20, forKey: "dbThreshold")
        }
        if UserDefaults.standard.string(forKey: "minimumSilence") == nil{
            UserDefaults.standard.set(0.7, forKey: "minimumSilence")
        }
        if UserDefaults.standard.string(forKey: "minimumSound") == nil{
            UserDefaults.standard.set(0.3, forKey: "minimumSound")
        }
        if UserDefaults.standard.string(forKey: "headAdjust") == nil{
            UserDefaults.standard.set(0.1, forKey: "headAdjust")
        }
        if UserDefaults.standard.string(forKey: "tailAdjust") == nil{
            UserDefaults.standard.set(0.7, forKey: "tailAdjust")
        }
        if UserDefaults.standard.string(forKey: "sampleNumber") == nil{
            UserDefaults.standard.set(100, forKey: "sampleNumber")
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
        setDefaultSettings()
        guard let selectedPath = selectedPath,
            let selectedDestination = selectedDestination,
            let detectionType = self.detectionSelector?.titleOfSelectedItem,
            let trimType = self.splitSelector?.titleOfSelectedItem else{
                return
                
        }
        self.processButton?.isEnabled = false
        self.progressBar?.startAnimation(nil)
        processFiles(inputURL: selectedPath, outputDirectory: selectedDestination, detectionType: detectionType, trimType: trimType, block: {
            DispatchQueue.main.async {
                self.processButton?.isEnabled = true
                self.progressBar?.stopAnimation(nil)
            }
        })
    }
    
    @IBAction func advancedDropdownToggled(sender: NSButton) {
        guard let window = view.window else{
            return
        }
        if sender.state.rawValue == 1{
            // Expand the window
            self.view.frame = NSRect.init(x: 0, y: 0, width: 480, height: 290)
            let contentSize = self.view.frame.size
            let newWindowSize = self.view.window?.frameRect(forContentRect: NSRect(origin: window.frame.origin, size: contentSize))
            window.animator().setFrame(newWindowSize!, display: false)
        } else{
            // Close the window
            self.view.frame = NSRect.init(x: 0, y: 0, width: 480, height: 140)
            let contentSize = self.view.frame.size
            let newWindowSize = self.view.window?.frameRect(forContentRect: NSRect(origin: window.frame.origin, size: contentSize))
            window.animator().setFrame(newWindowSize!, display: false)
        }
    }

}

