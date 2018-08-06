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

func findSound(channelData: UnsafeMutablePointer<Float>, sampleCount: Int, sampleRate: Double, detectionType: String) -> [(Double, Double)]{
    // TODO Put these settings somewhere user accessible
    let dBThreshold: Float = -20.0
    let sampleNumber = 100
    let minimumSilenceLength  = 0.7
    let minimumSoundLength = 0.2
    let headAdjust = 0.10
    let tailAdjust = 0.3
    
    var soundList = [(Double, Double)]()
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
        
        
        // Silence
        if amplitude < dBThreshold{
            if silenceStart < 0 {
                silenceStart = currentTime
            }
            if silenceLength > minimumSilenceLength && foundSound && soundLength > minimumSoundLength{
                foundSound = false
                soundLength = 0.0
                soundList.append((soundStart, currentTime))
            }
            silenceLength += sampleLength
        } else{
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
//        print("Sample number \(i+slice.count), Max \(sampleCount)")
//        print("Percent done \(Float(i+slice.count)/Float(sampleCount) * 100.0)")
    }
    if foundSound && soundLength > minimumSoundLength && silenceStart > soundStart{
        soundList.append((soundStart, silenceStart))
    }
    
    for i in 0..<soundList.count{
        var (head, tail) = soundList[i]
        head -= headAdjust
        tail += tailAdjust
    }
    
    for i in stride(from: soundList.count-1, to: 1, by: -1){
        var (_, prevTail) = soundList[i-1]
        let (head, tail) = soundList[i]
        if prevTail > head {
            prevTail = tail
            soundList.remove(at: i)
        }
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
        let (firstHead, _) = soundList.first!
        let (_, lastTail) = soundList.last!
        soundList = [(firstHead, lastTail)]
    }
    
    let ext = inputURL.pathExtension
    let name = inputURL.deletingPathExtension().lastPathComponent
    for (i, (inPoint, outPoint)) in soundList.enumerated(){
        let outputPath = outputDirectory.appendingPathComponent("\(name)_\(i).\(ext)")
        runFFMPEG(input: inputURL, output: outputPath, inPoint: inPoint, outPoint: outPoint)
    }
//    print(soundList)
    
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




//func readSamplesToData(url: URL){
//    let asset = AVAsset.init(url: url)
//    do{
//        let reader = try AVAssetReader.init(asset: asset)
//        let aTracks = asset.tracks(withMediaType: .audio)
//        guard let aTrack = aTracks.first else{
//            print("NO AUDIO TRACK")
//            return
//        }
//        let settings = [AVFormatIDKey: kAudioFormatLinearPCM]
//        let trackOutput = AVAssetReaderTrackOutput.init(track: aTrack, outputSettings: settings)
//        reader.add(trackOutput)
//        reader.startReading()
//        var sample = trackOutput.copyNextSampleBuffer()
//        var data = Data()
//
//
//
//        while(sample != nil){
//            var blockBuffer : CMBlockBuffer?
//            var audioBufferList = AudioBufferList()
//            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample!, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, 0, &blockBuffer)
//            let buffers = UnsafeBufferPointer<AudioBuffer>(start: &audioBufferList.mBuffers, count: Int(audioBufferList.mNumberBuffers))
//
//            for audioBuffer in buffers {
//                let frame = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self)
//                data.append(frame!, count: Int(audioBuffer.mDataByteSize))
//            }
//            sample = trackOutput.copyNextSampleBuffer()
//        }
//        let out = URL.init(fileURLWithPath: "/Users/mhand/Desktop/TestClip/out.wav")
//        try data.write(to: out)
//    } catch{
//        print ("PROBLEM READING PACKETS")
//    }
//}


//func arrayFromFloatData(_ audioFile: AVAudioFile) -> ([[Float]]?){
//    // Lots of this taken from AudioKit
//    let format = audioFile.processingFormat
//    let channelCount = Int(format.channelCount)
//    let frameCount = UInt32(audioFile.length)
//
//    guard let buffer = AVAudioPCMBuffer.init(pcmFormat: format, frameCapacity: frameCount) else{
//        print("Couldn't create PCM Buffer FOR \(audioFile.url.path)")
//        return nil
//    }
//
//    do{
//        try audioFile.read(into: buffer)
//    } catch{
//        print ("PROBLEM READING FILE INTO BUFFER FOR \(audioFile.url.path)")
//    }
//
//    let frameLength = UInt32(buffer.frameLength)
//    let stride = buffer.stride
//
//    // Preallocate our Array so we're not constantly thrashing while resizing as we append.
//    var floatData = Array(repeating: [Float].init(repeating: 0, count: Int(frameLength)), count: channelCount)
//
//    guard let bufferFloats = buffer.floatChannelData else{
//        print("PROBLEM WITH THE FLOATS  FOR \(audioFile.url.path)")
//        return nil
//    }
//
//    // Loop across our channels...
//    for channel in 0..<channelCount {
//        // Make sure we go through all of the frames...
//        for sampleIndex in 0..<Int(frameLength) {
//            floatData[channel][sampleIndex] = (bufferFloats[channel][sampleIndex * stride])
//        }
//    }
//    return floatData
//}
