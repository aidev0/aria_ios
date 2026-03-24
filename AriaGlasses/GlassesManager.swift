import Foundation
import UIKit
import MWDATCore
import MWDATCamera

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

enum SpeakerStatus: String {
    case stopped = "Stopped"
    case streaming = "Streaming"
}

@MainActor
class GlassesManager: ObservableObject {
    @Published var connectionStatus: GlassesConnectionStatus = .disconnected
    @Published var sessionStatus: SessionStatus = .idle
    @Published var videoStatus: VideoStatus = .stopped
    @Published var audioStatus: AudioStatus = .stopped
    @Published var speakerStatus: SpeakerStatus = .stopped
    @Published var musicVolume: Float = 1.0
    @Published var isAISpeaking: Bool = false
    @Published var currentFrame: UIImage?

    private var frameCallback: ((String) -> Void)?
    private var audioCallback: ((String) -> Void)?

    private let normalMusicVolume: Float = 1.0
    private let duckedMusicVolume: Float = 0.3

    // Meta Wearables SDK
    private var wearables: WearablesInterface!
    private var streamSession: StreamSession?
    private var deviceSelector: AutoDeviceSelector?
    private var registrationTask: Task<Void, Never>?
    private var deviceStreamTask: Task<Void, Never>?
    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?

    init() {
        setupWearables()
    }

    private func setupWearables() {
        wearables = Wearables.shared
        print("[GlassesManager] setupWearables called")

        registrationTask = Task {
            for await state in wearables.registrationStateStream() {
                print("[GlassesManager] Registration state changed: \(state)")
                await MainActor.run {
                    switch state {
                    case .registered:
                        print("[GlassesManager] State: registered - setting connected")
                        self.connectionStatus = .connected
                        self.setupDeviceStream()
                    case .registering:
                        print("[GlassesManager] State: registering - setting connecting")
                        self.connectionStatus = .connecting
                    case .unavailable:
                        print("[GlassesManager] State: unavailable - setting disconnected")
                        self.connectionStatus = .disconnected
                    case .available:
                        print("[GlassesManager] State: available - ready to connect")
                        self.connectionStatus = .disconnected
                    @unknown default:
                        print("[GlassesManager] State: unknown - setting disconnected")
                        self.connectionStatus = .disconnected
                    }
                }
            }
        }
    }

    private func setupDeviceStream() {
        deviceStreamTask?.cancel()
        print("[GlassesManager] setupDeviceStream called")
        deviceStreamTask = Task {
            for await devices in wearables.devicesStream() {
                print("[GlassesManager] Devices updated: \(devices.count) device(s)")
                for deviceId in devices {
                    print("[GlassesManager] Device ID: \(deviceId)")
                }
                if !devices.isEmpty {
                    await MainActor.run {
                        self.sessionStatus = .active
                    }
                }
            }
        }
    }

    func setFrameCallback(_ callback: @escaping (String) -> Void) {
        self.frameCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (String) -> Void) {
        self.audioCallback = callback
    }

    func connectToGlasses() {
        guard connectionStatus == .disconnected else {
            print("[GlassesManager] connectToGlasses ignored - already \(connectionStatus)")
            return
        }
        print("[GlassesManager] connectToGlasses - starting registration")
        connectionStatus = .scanning

        do {
            try wearables.startRegistration()
            print("[GlassesManager] startRegistration() called successfully")
        } catch {
            print("[GlassesManager] Error starting registration: \(error)")
            connectionStatus = .disconnected
        }
    }

    func disconnectFromGlasses() {
        stopVideo()
        endSession()

        do {
            try wearables.startUnregistration()
        } catch {
            print("Error unregistering: \(error)")
        }
        connectionStatus = .disconnected
    }

    func startSession() {
        guard connectionStatus == .connected, sessionStatus == .idle else { return }
        sessionStatus = .active
    }

    func endSession() {
        stopVideo()
        stopAudio()
        stopSpeaker()
        sessionStatus = .idle
    }

    func startVideo() {
        guard videoStatus == .stopped else {
            print("[GlassesManager] startVideo ignored - already \(videoStatus)")
            return
        }
        print("[GlassesManager] startVideo called")

        Task {
            do {
                print("[GlassesManager] Checking camera permission...")
                let status = try await wearables.checkPermissionStatus(.camera)
                print("[GlassesManager] Camera permission status: \(status)")
                if status != .granted {
                    print("[GlassesManager] Requesting camera permission...")
                    let requestStatus = try await wearables.requestPermission(.camera)
                    print("[GlassesManager] Camera permission request result: \(requestStatus)")
                    if requestStatus != .granted {
                        print("[GlassesManager] Camera permission denied")
                        return
                    }
                }

                print("[GlassesManager] Setting up stream session...")
                await setupStreamSession()
                print("[GlassesManager] Starting stream session...")
                await streamSession?.start()
                print("[GlassesManager] Stream session started")
                await MainActor.run {
                    self.videoStatus = .streaming
                }
            } catch {
                print("[GlassesManager] Error starting video: \(error)")
            }
        }
    }

    private func setupStreamSession() async {
        deviceSelector = AutoDeviceSelector(wearables: wearables)

        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .low,
            frameRate: 24
        )

        streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector!)

        // Listen for video frames
        print("[GlassesManager] Setting up video frame listener")
        videoFrameListenerToken = streamSession?.videoFramePublisher.listen { [weak self] videoFrame in
            print("[GlassesManager] Received video frame")
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let image = videoFrame.makeUIImage() {
                    print("[GlassesManager] Frame converted to UIImage: \(image.size)")
                    self.currentFrame = image
                    // Convert to base64 and send via callback
                    if let jpegData = image.jpegData(compressionQuality: 0.7) {
                        let base64String = jpegData.base64EncodedString()
                        self.frameCallback?(base64String)
                        // Post notification for DashboardView
                        NotificationCenter.default.post(name: .frameReceived, object: nil, userInfo: ["frame": base64String])
                    }
                } else {
                    print("[GlassesManager] Failed to convert frame to UIImage")
                }
            }
        }

        // Listen for state changes
        stateListenerToken = streamSession?.statePublisher.listen { [weak self] state in
            print("[GlassesManager] Stream state changed: \(state)")
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .streaming:
                    print("[GlassesManager] Stream is now streaming")
                    self.videoStatus = .streaming
                case .stopped:
                    print("[GlassesManager] Stream stopped")
                    self.videoStatus = .stopped
                    self.currentFrame = nil
                default:
                    print("[GlassesManager] Stream state: \(state)")
                    break
                }
            }
        }

        // Listen for errors
        errorListenerToken = streamSession?.errorPublisher.listen { error in
            Task { @MainActor in
                print("Stream error: \(error)")
            }
        }
    }

    func stopVideo() {
        Task {
            await streamSession?.stop()
        }
        videoStatus = .stopped
        currentFrame = nil
    }

    func startAudio() {
        guard audioStatus == .stopped else { return }
        audioStatus = .streaming
    }

    func stopAudio() {
        audioStatus = .stopped
    }

    func startSpeaker() {
        guard speakerStatus == .stopped else { return }
        speakerStatus = .streaming
    }

    func stopSpeaker() {
        speakerStatus = .stopped
    }

    // MARK: - AI Speaking / Music Ducking

    func onAISpeakingStarted() {
        isAISpeaking = true
        musicVolume = duckedMusicVolume
    }

    func onAISpeakingStopped() {
        isAISpeaking = false
        musicVolume = normalMusicVolume
    }

    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }
}
