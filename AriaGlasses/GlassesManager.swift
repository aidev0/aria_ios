import Foundation
import UIKit

enum GlassesConnectionStatus: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning"
    case connecting = "Connecting"
    case connected = "Connected"
}

enum SessionStatus: String {
    case idle = "Idle"
    case active = "Active"
}

enum VideoStatus: String {
    case stopped = "Stopped"
    case streaming = "Streaming"
}

enum AudioStatus: String {
    case stopped = "Stopped"
    case streaming = "Streaming"
}

enum MusicStatus: String {
    case stopped = "Stopped"
    case playing = "Playing"
}

@MainActor
class GlassesManager: ObservableObject {
    @Published var connectionStatus: GlassesConnectionStatus = .disconnected
    @Published var sessionStatus: SessionStatus = .idle
    @Published var videoStatus: VideoStatus = .stopped
    @Published var audioStatus: AudioStatus = .stopped
    @Published var musicStatus: MusicStatus = .stopped
    @Published var musicVolume: Float = 1.0
    @Published var isAISpeaking: Bool = false

    private var frameCallback: ((String) -> Void)?
    private var audioCallback: ((String) -> Void)?

    private let normalMusicVolume: Float = 1.0
    private let duckedMusicVolume: Float = 0.3

    // TODO: Add Meta Wearables SDK manager
    // private var wearablesManager: WearablesManager?

    func setFrameCallback(_ callback: @escaping (String) -> Void) {
        self.frameCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (String) -> Void) {
        self.audioCallback = callback
    }

    func connectToGlasses() {
        guard connectionStatus == .disconnected else { return }
        connectionStatus = .scanning

        // TODO: Implement with Meta Wearables SDK
        // wearablesManager = WearablesManager()
        // wearablesManager?.delegate = self
        // wearablesManager?.startScanning()
    }

    func disconnectFromGlasses() {
        stopVideo()
        endSession()
        // TODO: wearablesManager?.disconnect()
        connectionStatus = .disconnected
    }

    func startSession() {
        guard connectionStatus == .connected, sessionStatus == .idle else { return }
        // TODO: Start session with glasses
        sessionStatus = .active
    }

    func endSession() {
        stopVideo()
        stopAudio()
        stopMusic()
        // TODO: End session with glasses
        sessionStatus = .idle
    }

    func startVideo() {
        guard sessionStatus == .active, videoStatus == .stopped else { return }
        // TODO: Start video stream from glasses
        // wearablesManager?.startVideoStream { [weak self] frame in
        //     if let jpegData = frame.jpegData(compressionQuality: 0.7) {
        //         self?.frameCallback?(jpegData.base64EncodedString())
        //     }
        // }
        videoStatus = .streaming
    }

    func stopVideo() {
        // TODO: Stop video stream
        // wearablesManager?.stopVideoStream()
        videoStatus = .stopped
    }

    func startAudio() {
        guard sessionStatus == .active, audioStatus == .stopped else { return }
        // TODO: Start audio stream from glasses
        // wearablesManager?.startAudioStream { [weak self] audioData in
        //     self?.audioCallback?(audioData.base64EncodedString())
        // }
        audioStatus = .streaming
    }

    func stopAudio() {
        // TODO: Stop audio stream
        // wearablesManager?.stopAudioStream()
        audioStatus = .stopped
    }

    func startMusic() {
        guard sessionStatus == .active, musicStatus == .stopped else { return }
        musicStatus = .playing
    }

    func stopMusic() {
        musicStatus = .stopped
    }

    // MARK: - AI Speaking / Music Ducking

    func onAISpeakingStarted() {
        isAISpeaking = true
        musicVolume = duckedMusicVolume
        // TODO: Apply volume to audio player
    }

    func onAISpeakingStopped() {
        isAISpeaking = false
        musicVolume = normalMusicVolume
        // TODO: Apply volume to audio player
    }

    // MARK: - Meta Wearables SDK Delegate Methods

    func onGlassesFound() {
        connectionStatus = .connecting
    }

    func onGlassesConnected() {
        connectionStatus = .connected
    }

    func onGlassesDisconnected() {
        connectionStatus = .disconnected
        sessionStatus = .idle
        videoStatus = .stopped
        audioStatus = .stopped
        musicStatus = .stopped
    }

    func onFrameReceived(_ jpegData: Data) {
        frameCallback?(jpegData.base64EncodedString())
    }

    func onAudioReceived(_ audioData: Data) {
        audioCallback?(audioData.base64EncodedString())
    }
}
