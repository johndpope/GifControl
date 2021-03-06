//
//  ContentView.swift
//  GifControl
//
//  Created by Bryan Wang on 8/1/20.
//  Copyright © 2020 Bryan Wang. All rights reserved.
//

import SwiftUI
import StoreKit
import MediaPlayer

struct ContentView: View {
    @State private var selection = 0
    @State private var musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    @State private var currentSong = Song(id: "", name: "", artistName: "", artworkURL: "")
    let audioEngine = AVAudioEngine()
    var savedBuff: [Float] = []
    var count: Int = 0
    let speechSampleRate: Int = 16000
    
    // configs to avoid future bugs:
    let nMels: Int = 32
    let fftSize: Int = 512
    
    // 20 ms aka 320 samples at 16kHz
    let hopLength: Int = 320
    
    func startRecording() throws {
        let queue = DispatchQueue(label: "ProcessorQueue")
        let stft = CircularShortTimeFourierTransform(windowLength: fftSize, hop: hopLength, fftSizeOf: fftSize, sampleRate: speechSampleRate, nMels: nMels)
        guard let filePathModel: String = Bundle.main.path(forResource: "traced_tc_4", ofType: "pt") else {
            return }
        let model = TorchModule(fileAtPath: filePathModel)!
        let modelProcessor = ModelProcessor(model: model, stft: stft, nMels: nMels)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetoothA2DP])
        try audioSession.setPreferredSampleRate(Double(speechSampleRate))

//          want a 10 ms hop (160 samples for a SR of 16000)
        
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0 )
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else{
            print("couldn't initialize AVAudioConverter")
            return
        }
        
        var count = 0
        var value = 0
        
        inputNode.installTap(onBus: 0, bufferSize: 160, format: inputFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            count += 1
            print("in callback", count)
            if let tail = buffer.floatChannelData?[0] {
//                    print("appending raw samples: ", Int(buffer.frameLength))
                modelProcessor.stft.appendData(tail, withSamples: Int(buffer.frameLength))
            }
            queue.async {
                while true {
                    value = modelProcessor.processNewValue()
//                        DispatchQueue.main.async{
//                            self.currentText = String(value)
//                        }
                    // value 8 is go TODO: put these in the config
                    if (value == 1) {
                        DispatchQueue.main.async{
                            print("go")
                            self.musicPlayer.play()
                        }
                    }
                    // value 5 is stop
                    else if (value == 6) {
                        DispatchQueue.main.async{
                            print("stop")
                            self.musicPlayer.stop()
                        }
                    }
                    // prev 3 (traced_tc_3)
                    else if (value == 4) {
                        DispatchQueue.main.async{
                        }
                    }
                    // prev 7
                    else if (value == 8) {
                        DispatchQueue.main.async{
                        }
                    }
                    // prev 6
                    else if (value == 7) {
                        DispatchQueue.main.async{
                        }
                    }
                    else if (value == 3) {
                        DispatchQueue.main.async{
                        }
                    }
                }
            }
        }

        audioEngine.prepare()
        print("done preparing the engine")

        try audioEngine.start()
    }
 
    var body: some View {
//        TabView(selection: $selection){
//            PlayerView(musicPlayer: self.$musicPlayer, currentSong: self.$currentSong, isPlaying: $viewModel.isPlaying)
//                .tag(0)
//                .tabItem {
//                    VStack {
//                        Image(systemName: "music.note")
//                        Text("Player")
//                    }
//                }
//            SongView(musicPlayer: self.$musicPlayer, currentSong: self.$currentSong)
//                .tag(1)
//                .tabItem {
//                    VStack {
//                        Image(systemName: "magnifyingglass")
//                        Text("Search")
//                    }
//                }
//        }.accentColor(.pink)
        Text("black eyed peas")
        .onAppear() {
            SKCloudServiceController.requestAuthorization { (status) in
                if status == .authorized {
                    print(AppleMusicAPI().searchAppleMusic("Lil Mosey"))
                }
            }
            self.musicPlayer.setQueue(with: ["1469642295"])
            self.musicPlayer.play()
            do {
//                self.testfunc()
                try self.startRecording()
            }
            catch {
                print("cannot record")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
