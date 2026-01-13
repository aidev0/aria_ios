import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var glassesManager = GlassesManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // dashboard button at top
                    NavigationLink {
                        DashboardView(glassesManager: glassesManager, webSocketManager: webSocketManager)
                    } label: {
                        VStack(spacing: 8) {
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 50)
                            Text("click to enjoy aria glasses")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(white: 0.25), lineWidth: 1)
                        )
                    }

                    // status table - 3 cols x 2 rows
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            StatusCell(title: "glasses", value: glassesManager.connectionStatus.rawValue.lowercased(), isActive: glassesManager.connectionStatus == .connected)
                            StatusCell(title: "kernel", value: webSocketManager.status.rawValue.lowercased(), isActive: webSocketManager.status == .connected)
                            StatusCell(title: "session", value: glassesManager.sessionStatus.rawValue.lowercased(), isActive: glassesManager.sessionStatus == .active)
                        }
                        HStack(spacing: 2) {
                            StatusCell(title: "video", value: glassesManager.videoStatus.rawValue.lowercased(), isActive: glassesManager.videoStatus == .streaming)
                            StatusCell(title: "audio", value: glassesManager.audioStatus.rawValue.lowercased(), isActive: glassesManager.audioStatus == .streaming)
                            StatusCell(title: "music", value: glassesManager.musicStatus.rawValue.lowercased(), isActive: glassesManager.musicStatus == .playing)
                        }
                    }
                    .cornerRadius(12)

                    // connections
                    VStack(spacing: 8) {
                        Text("connections")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            Button {
                                if glassesManager.connectionStatus == .disconnected {
                                    glassesManager.connectToGlasses()
                                } else {
                                    glassesManager.disconnectFromGlasses()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "eyeglasses")
                                        .font(.title2)
                                    Text(glassesManager.connectionStatus == .disconnected ? "connect to glasses" : "disconnect")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(Color(white: 0.15))
                                .cornerRadius(12)
                            }

                            Button {
                                if webSocketManager.status == .disconnected {
                                    webSocketManager.connect()
                                } else {
                                    webSocketManager.disconnect()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "network")
                                        .font(.title2)
                                    Text(webSocketManager.status == .disconnected ? "connect to kernel" : "disconnect")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(Color(white: 0.15))
                                .cornerRadius(12)
                            }
                        }
                    }

                    // controls
                    VStack(spacing: 8) {
                        Text("controls")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // session button
                        Button {
                            if glassesManager.sessionStatus == .idle {
                                glassesManager.startSession()
                                webSocketManager.sendCommand(action: "session_start")
                            } else {
                                glassesManager.endSession()
                                webSocketManager.sendCommand(action: "session_end")
                            }
                        } label: {
                            HStack {
                                Image(systemName: glassesManager.sessionStatus == .idle ? "play.fill" : "stop.fill")
                                Text(glassesManager.sessionStatus == .idle ? "start session" : "end session")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(white: 0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(glassesManager.connectionStatus != .connected || webSocketManager.status != .connected)
                        .opacity(glassesManager.connectionStatus != .connected || webSocketManager.status != .connected ? 0.5 : 1)

                        // stream buttons
                        HStack(spacing: 12) {
                            Button {
                                if glassesManager.videoStatus == .stopped {
                                    glassesManager.startVideo()
                                    webSocketManager.sendCommand(action: "video_start")
                                } else {
                                    glassesManager.stopVideo()
                                    webSocketManager.sendCommand(action: "video_stop")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: glassesManager.videoStatus == .stopped ? "video.fill" : "video.slash.fill")
                                        .font(.title2)
                                    Text(glassesManager.videoStatus == .stopped ? "video" : "stop")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(glassesManager.videoStatus == .streaming ? Color.purple : Color(white: 0.15))
                                .cornerRadius(12)
                            }
                            .disabled(glassesManager.sessionStatus != .active)
                            .opacity(glassesManager.sessionStatus != .active ? 0.5 : 1)

                            Button {
                                if glassesManager.audioStatus == .stopped {
                                    glassesManager.startAudio()
                                    webSocketManager.sendCommand(action: "audio_start")
                                } else {
                                    glassesManager.stopAudio()
                                    webSocketManager.sendCommand(action: "audio_stop")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: glassesManager.audioStatus == .stopped ? "waveform" : "waveform.slash")
                                        .font(.title2)
                                    Text(glassesManager.audioStatus == .stopped ? "audio" : "stop")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(glassesManager.audioStatus == .streaming ? Color.orange : Color(white: 0.15))
                                .cornerRadius(12)
                            }
                            .disabled(glassesManager.sessionStatus != .active)
                            .opacity(glassesManager.sessionStatus != .active ? 0.5 : 1)

                            Button {
                                if glassesManager.musicStatus == .stopped {
                                    glassesManager.startMusic()
                                    webSocketManager.sendCommand(action: "music_start")
                                } else {
                                    glassesManager.stopMusic()
                                    webSocketManager.sendCommand(action: "music_stop")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: glassesManager.musicStatus == .stopped ? "music.note" : "music.note.slash")
                                        .font(.title2)
                                    Text(glassesManager.musicStatus == .stopped ? "music" : "stop")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(glassesManager.musicStatus == .playing ? Color.pink : Color(white: 0.15))
                                .cornerRadius(12)
                            }
                            .disabled(glassesManager.sessionStatus != .active)
                            .opacity(glassesManager.sessionStatus != .active ? 0.5 : 1)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .background(Color.black)
            .foregroundColor(.white)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                glassesManager.setFrameCallback { base64Data in
                    webSocketManager.sendFrame(base64Data: base64Data)
                }
                glassesManager.setAudioCallback { base64Data in
                    webSocketManager.sendAudio(base64Data: base64Data)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSpeaking)) { notification in
                if let action = notification.userInfo?["action"] as? String {
                    if action == "start" {
                        glassesManager.onAISpeakingStarted()
                    } else if action == "stop" {
                        glassesManager.onAISpeakingStopped()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Status Cell

struct StatusCell: View {
    let title: String
    let value: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isActive ? Color.green.opacity(0.2) : Color(white: 0.1))
        .foregroundColor(isActive ? .green : .white)
    }
}

#Preview {
    ContentView()
}
