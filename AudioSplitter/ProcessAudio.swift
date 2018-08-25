//
//  Audio.swift
//  AudioSplitter
//
//  Created by Michael Hand on 8/5/18.
//  Copyright © 2018 Michael Hand. All rights reserved.
//

import Foundation
import AVFoundation

func pcmBuffer(_ audioFile: AVAudioFile) -> AVAudioPCMBuffer? {
    // Lots of this taken from AudioKit
    let format = audioFile.processingFormat
    let frameCount = UInt32(audioFile.length)
    
    guard let buffer = AVAudioPCMBuffer.init(pcmFormat: format, frameCapacity: frameCount) else{
        print("Couldn't create PCM Buffer for \(audioFile.url.path)")
        return nil
    }
    
    do{
        try audioFile.read(into: buffer)
    } catch{
        print ("PROBLEM READING FILE INTO BUFFER FOR \(audioFile.url.path)")
    }
    
    return buffer
    
}

func findMax(samples: [Float]) -> Float{
    let cmax = samples.max()
    let cmin = samples.min()
    
    return absMax(cmax: cmax, cmin: cmin)
}

func absMax(cmax:Float?, cmin:Float?) -> Float{
    var maxLev: Float = 0
    // positive max
    maxLev = max(cmax ?? maxLev, maxLev)
    // negative max
    maxLev = -min(abs(cmin ?? -maxLev), -maxLev)
    return 10 * log10(maxLev)
}

func RMS(samples: [Float]) -> Float{
    var sum: Float = 0.0
    let sampleNumber = samples.count
    for i in samples.indices{
        sum += pow(samples[i], 2)
    }
    let divided = (sum / Float(sampleNumber))
    return 10 * log10(divided.squareRoot())
}

func getFloats(pointer:UnsafeMutablePointer<Float>, start:Int, end:Int)->[Float]{
    var floats:[Float] = Array.init(repeating: 0, count: (end - start))
    var i = 0
    for sampleIndex in start..<end {
        floats[i] = pointer[sampleIndex]
        i += 1
    }
    
    return floats
}

func findSound(channelData: UnsafeMutablePointer<Float>, sampleCount: Int, sampleRate: Double, detectionType: String) -> [SoundTiming]{
    let dBThreshold: Float = UserDefaults.standard.float(forKey: "dbThreshold")
    let sampleNumber = UserDefaults.standard.integer(forKey: "sampleNumber")
    let minimumSilenceLength  = UserDefaults.standard.double(forKey: "minimumSilence")
    let minimumSoundLength = UserDefaults.standard.double(forKey: "minimumSound")
    let headAdjust = UserDefaults.standard.double(forKey: "headAdjust")
    let tailAdjust = UserDefaults.standard.double(forKey: "tailAdjust")
    
    var soundList = [SoundTiming]()
    var silenceLength = 0.0
    var silenceStart = -1.0
    var soundStart = -1.0
    var soundLength = 0.0
    var foundSound = false
    
    for i in stride(from: 0, to: sampleCount, by: sampleNumber){
        let end = i+sampleNumber
        var slice = [Float]()
        if end <= sampleCount{
            slice = getFloats(pointer: channelData, start: i, end: end)
        } else{
            slice = getFloats(pointer: channelData, start: i, end: sampleCount)
        }
        let sampleLength = Double(slice.count) / sampleRate
        let currentTime = Double(i) / sampleRate

        
        var amplitude: Float = 0.0
        if detectionType == "RMS"{
            amplitude = RMS(samples: slice)
        } else{
            amplitude = findMax(samples: slice)
        }
        
        
        if amplitude < dBThreshold{ // Sample is silence
            if silenceStart < 0 {
                silenceStart = currentTime
            }
            
            // Silence after enough sound so append to list
            if silenceLength > minimumSilenceLength && foundSound && soundLength > minimumSoundLength{
                foundSound = false
                soundLength = 0.0
                let timing = SoundTiming.init(start: soundStart, end: currentTime-minimumSilenceLength)
                soundList.append(timing)
            }
            silenceLength += sampleLength
        } else{ // Sample is sound
            if !foundSound{
                foundSound = true
                silenceLength = 0.0
                soundStart = currentTime
            }
            if silenceLength > 0 && soundLength > minimumSoundLength{
                silenceStart = -1.0
                silenceLength = 0
            }
            soundLength += sampleLength
        }
    }
    
    if foundSound && soundLength > minimumSoundLength && silenceStart > soundStart{
        let timing = SoundTiming.init(start: soundStart, end: silenceStart)
        soundList.append(timing)
    }
    
    for i in 0..<soundList.count{
        var timing = soundList[i]
        timing.start -= headAdjust
        timing.end += tailAdjust
        soundList[i] = timing
    }
    
    // Combine overlapping timings after head/tail adjust
    for i in stride(from: soundList.count-1, to: 1, by: -1){
        var prevTiming = soundList[i-1]
        let timing = soundList[i]
        if prevTiming.end > timing.start {
            prevTiming.end = timing.end
            soundList.remove(at: i)
            soundList[i-1] = prevTiming
        }
    }
    for timing in soundList{
        print(timing.start, timing.end)
    }
    
    return soundList
}

func processFile(inputURL: URL, outputDirectory: URL, detectionType: String, trimType: String){
    let channel = 0
    guard let audioFile = try? AVAudioFile.init(forReading: inputURL) else{
        print("Couldn't read audio file")
        return
    }

    guard let buffer = pcmBuffer(audioFile) else{
        print("ERROR GETTING FLOATS FOR \(inputURL.path)")
        return
    }
    
    guard let bufferFloats = buffer.floatChannelData else{
        print("PROBLEM WITH THE FLOATS  FOR \(inputURL.path)")
        return
    }

    let channelData = bufferFloats[channel]
    let sampleCount = UInt32(buffer.frameLength)
    
    let sr = audioFile.processingFormat.sampleRate
    var soundList = findSound(channelData: channelData, sampleCount: Int(sampleCount), sampleRate: sr, detectionType: detectionType)
    if trimType == "Trim"{
        // Could speed up by finding first sound, breaking, and then going through the samples in reverse to find the last sound, break
        guard let first = soundList.first else {
            print("MISSING FIRST SAMPLE")
            return
        }
        guard let last = soundList.last else{
            print("MISSING LAST SAMPLE")
            return
        }
        let timing = SoundTiming.init(start: first.start, end: last.end)
        soundList = [timing]
    }
    
    let ext = inputURL.pathExtension
    let name = inputURL.deletingPathExtension().lastPathComponent
    for (i, timing) in soundList.enumerated(){
        let outputPath = outputDirectory.appendingPathComponent("\(name)_\(i).\(ext)")
        runFFMPEG(input: inputURL, output: outputPath, inPoint: timing.start, outPoint: timing.end)
    }    
}

func processFiles(inputURL: URL, outputDirectory: URL, detectionType: String, trimType: String){
    var isDir : ObjCBool = false
    if FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir){
        if isDir.boolValue{
            // TODO loop through all the files
        } else{
            DispatchQueue.global(qos: .background).async {
                processFile(inputURL: inputURL, outputDirectory: outputDirectory, detectionType: detectionType, trimType: trimType)
            }
        }
    } else{
        print("SELECTED FILE DOESN'T EXIST")
    }
    
}
