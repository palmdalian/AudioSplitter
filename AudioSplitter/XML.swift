//
//  XML.swift
//  AudioSplitter
//
//  Created by Michael Hand on 6/17/19.
//  Copyright © 2019 Michael Hand. All rights reserved.
//

import Foundation

func buildXML(input: URL, output: URL, timings:[SoundTiming], sampleRate: Double){
    let tmpId = UUID.init()
    let tmpPath = URL(fileURLWithPath:"/tmp/\(tmpId.uuidString).json")
    var xmlTimings = [XMLTiming]()
    for timing in timings{
        let start = round(timing.start * sampleRate)
        let end = round(timing.end * sampleRate)
        let rate = sampleRate
        let xmlTiming = XMLTiming.init(start: start, end: end, rate:rate, path: input.path)
        xmlTimings.append(xmlTiming)
    }
    let encoder = JSONEncoder()
    do {
        let data = try encoder.encode(xmlTimings)
        FileManager.default.createFile(atPath: tmpPath.path, contents: data, attributes: nil)
    } catch {
        fatalError(error.localizedDescription)
    }
    
//
    let process = Process()
    if let url = Bundle.main.url(forResource: "PremiereBuilder", withExtension: nil){
        process.executableURL = url
    } else{
        return
    }
    process.arguments = ["-i", tmpPath.path, "-o", output.path]
    process.terminationHandler = { (process) in
        //        print("\nFinished: \(output.path)")
    }
    do {
        //        print("Exporting \(output.path)")
        try process.run()
    } catch {}
}
