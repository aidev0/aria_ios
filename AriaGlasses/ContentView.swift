import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var glassesManager = GlassesManager()
    @State private var selectedAgents: Set<AIAgent> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // dashboard button at top
                    NavigationLink {
                        DashboardView(glassesManager: glassesManager, webSocketManager: webSocketManager, selectedAgents: $selectedAgents)
                    } label: {
                        VStack(spacing: 8) {
                            Image(glassesManager.videoStatus == .streaming ? "aria_wf_bb" : "aria_wf_bb_nodot")
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
                            StatusCell(title: "ai", value: webSocketManager.status.rawValue.lowercased(), isActive: webSocketManager.status == .connected)
                            StatusCell(title: "session", value: glassesManager.sessionStatus.rawValue.lowercased(), isActive: glassesManager.sessionStatus == .active)
                        }
                        HStack(spacing: 2) {
                            StatusCell(title: "see", value: glassesManager.videoStatus.rawValue.lowercased(), isActive: glassesManager.videoStatus == .streaming)
                            StatusCell(title: "listen", value: glassesManager.audioStatus.rawValue.lowercased(), isActive: glassesManager.audioStatus == .streaming)
                            StatusCell(title: "talk", value: glassesManager.speakerStatus.rawValue.lowercased(), isActive: glassesManager.speakerStatus == .streaming)
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
                                        .foregroundColor(glassesManager.connectionStatus == .connected ? .green : .white)
                                    Text(glassesManager.connectionStatus == .disconnected ? "connect glasses" : "disconnect")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(glassesManager.connectionStatus == .connected ? Color.green.opacity(0.2) : Color(white: 0.15))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(glassesManager.connectionStatus == .connected ? Color.green : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: glassesManager.connectionStatus == .connected ? Color.green.opacity(0.5) : Color.clear, radius: 8)
                            }

                            Button {
                                if webSocketManager.status == .disconnected {
                                    webSocketManager.connect()
                                } else {
                                    webSocketManager.disconnect()
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title2)
                                        .foregroundColor(webSocketManager.status == .connected ? .cyan : .white)
                                    Text(webSocketManager.status == .disconnected ? "connect ai" : "disconnect")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(webSocketManager.status == .connected ? Color.cyan.opacity(0.2) : Color(white: 0.15))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(webSocketManager.status == .connected ? Color.cyan : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: webSocketManager.status == .connected ? Color.cyan.opacity(0.5) : Color.clear, radius: 8)
                            }
                        }
                    }

                    // controls
                    VStack(spacing: 8) {
                        Text("controls")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

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
                                    Image(systemName: glassesManager.videoStatus == .stopped ? "video.fill" : "video.fill")
                                        .font(.title2)
                                    Text(glassesManager.videoStatus == .stopped ? "see" : "stop")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(glassesManager.videoStatus == .streaming ? Color.purple : Color(white: 0.15))
                                .cornerRadius(12)
                            }

                            Button {
                                if glassesManager.audioStatus == .stopped {
                                    glassesManager.startAudio()
                                    webSocketManager.sendCommand(action: "mic_start")
                                } else {
                                    glassesManager.stopAudio()
                                    webSocketManager.sendCommand(action: "mic_stop")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: glassesManager.audioStatus == .stopped ? "mic.fill" : "mic.fill")
                                        .font(.title2)
                                    Text(glassesManager.audioStatus == .stopped ? "listen" : "stop")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(glassesManager.audioStatus == .streaming ? Color.orange : Color(white: 0.15))
                                .cornerRadius(12)
                            }

                            Button {
                                if glassesManager.speakerStatus == .stopped {
                                    glassesManager.startSpeaker()
                                    webSocketManager.sendCommand(action: "speaker_start")
                                } else {
                                    glassesManager.stopSpeaker()
                                    webSocketManager.sendCommand(action: "speaker_stop")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: glassesManager.speakerStatus == .stopped ? "speaker.wave.2.fill" : "speaker.wave.2.fill")
                                        .font(.title2)
                                    Text(glassesManager.speakerStatus == .stopped ? "talk" : "stop")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(glassesManager.speakerStatus == .streaming ? Color.pink : Color(white: 0.15))
                                .cornerRadius(12)
                            }
                        }
                    }

                    // ai agents
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ai agents")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(AIAgent.allCases, id: \.self) { agent in
                                Button {
                                    if selectedAgents.contains(agent) {
                                        selectedAgents.remove(agent)
                                        webSocketManager.sendCommand(action: "agent_deselect_\(agent.rawValue)")
                                    } else {
                                        selectedAgents.insert(agent)
                                        webSocketManager.sendCommand(action: "agent_select_\(agent.rawValue)")
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: agent.icon)
                                            .font(.system(size: 18))
                                        Text(agent.rawValue)
                                            .font(.system(size: 9))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .foregroundColor(selectedAgents.contains(agent) ? .white : .gray)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(selectedAgents.contains(agent) ? agent.color.opacity(0.3) : Color(white: 0.15))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedAgents.contains(agent) ? agent.color : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
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
