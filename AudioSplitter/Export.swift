//
//  Export.swift
//  AudioSplitter
//
//  Created by Michael Hand on 8/5/18.
//  Copyright © 2018 Michael Hand. All rights reserved.
//

import Foundation

func runFFMPEG(input: URL, output: URL, inPoint:Double, outPoint:Double){
    let process = Process()
    process.executableURL = URL(fileURLWithPath:"/usr/local/bin/ffmpeg")
    process.arguments = ["-y", "-v", "quiet", "-i", input.path, "-ss", String(inPoint), "-to", String(outPoint), "-c", "copy", output.path]
    process.terminationHandler = { (process) in
//        print("\nFinished: \(output.path)")
    }
    do {
//        print("Exporting \(output.path)")
        try process.run()
    } catch {}
}
