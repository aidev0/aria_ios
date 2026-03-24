import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var glassesManager = GlassesManager()
    @State private var selectedAgents: Set<AIAgent> = []
    @State private var agentConfigs: [AIAgent: AgentConfig] = [:]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    dashboardButton
                    connectionsSection
                    controlsSection
                    aiAgentsSection
                    Spacer()
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .foregroundColor(.white)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .preferredColorScheme(.dark)
    }

    private var dashboardButton: some View {
        NavigationLink {
            DashboardView(glassesManager: glassesManager, webSocketManager: webSocketManager, selectedAgents: $selectedAgents, agentConfigs: $agentConfigs)
        } label: {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 20) {
                        Image("aria_wf_bb")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                        Image("aria_wf_bb")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                    }
                    .shadow(color: glassesManager.videoStatus == .streaming ? .red.opacity(0.8) : .white.opacity(0.3), radius: 20)

                    // Recording indicator
                    if glassesManager.videoStatus == .streaming {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .shadow(color: .red, radius: 4)
                            .offset(x: 5, y: -5)
                    }
                }
                Text("tap to enter aria")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.black)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .white.opacity(0.1), radius: 10)
        }
    }

    private var connectionsSection: some View {
        VStack(spacing: 8) {
            Text("connections")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                glassesConnectionButton
                aiConnectionButton
            }
        }
    }

    private var glassesConnectionButton: some View {
        Button {
            if glassesManager.connectionStatus == .disconnected {
                glassesManager.connectToGlasses()
            } else {
                glassesManager.disconnectFromGlasses()
            }
        } label: {
            let isConnected = glassesManager.connectionStatus == .connected
            VStack(spacing: 4) {
                Image(systemName: "eyeglasses")
                    .font(.title2)
                    .foregroundColor(isConnected ? .green : .white)
                Text(glassesManager.connectionStatus == .disconnected ? "connect glasses" : "disconnect")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(isConnected ? Color.green.opacity(0.2) : Color(white: 0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isConnected ? Color.green : Color.clear, lineWidth: 2)
            )
            .shadow(color: isConnected ? Color.green.opacity(0.5) : Color.clear, radius: 8)
        }
    }

    private var aiConnectionButton: some View {
        Button {
            if webSocketManager.status == .disconnected {
                webSocketManager.connect()
            } else {
                webSocketManager.disconnect()
            }
        } label: {
            let isConnected = webSocketManager.status == .connected
            VStack(spacing: 4) {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundColor(isConnected ? .cyan : .white)
                Text(webSocketManager.status == .disconnected ? "connect to ai" : "disconnect")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(isConnected ? Color.cyan.opacity(0.2) : Color(white: 0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isConnected ? Color.cyan : Color.clear, lineWidth: 2)
            )
            .shadow(color: isConnected ? Color.cyan.opacity(0.5) : Color.clear, radius: 8)
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 8) {
            Text("controls")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                videoControlButton
                audioControlButton
                speakerControlButton
            }
        }
    }

    private var videoControlButton: some View {
        let isActive = glassesManager.videoStatus == .streaming
        return Button {
            if glassesManager.videoStatus == .stopped {
                glassesManager.startVideo()
                webSocketManager.sendCommand(action: "video_start")
            } else {
                glassesManager.stopVideo()
                webSocketManager.sendCommand(action: "video_stop")
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundColor(isActive ? .white : .gray)
                    Text(isActive ? "rec" : "see")
                        .font(.caption)
                        .foregroundColor(isActive ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isActive ? Color.red : Color(white: 0.15))
                .cornerRadius(12)

                if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: -8, y: 8)
                }
            }
        }
    }

    private var audioControlButton: some View {
        let isActive = glassesManager.audioStatus == .streaming
        return Button {
            if glassesManager.audioStatus == .stopped {
                glassesManager.startAudio()
                webSocketManager.sendCommand(action: "mic_start")
            } else {
                glassesManager.stopAudio()
                webSocketManager.sendCommand(action: "mic_stop")
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(isActive ? .white : .gray)
                    Text(isActive ? "on" : "listen")
                        .font(.caption)
                        .foregroundColor(isActive ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isActive ? Color.red : Color(white: 0.15))
                .cornerRadius(12)

                if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: -8, y: 8)
                }
            }
        }
    }

    private var speakerControlButton: some View {
        let isActive = glassesManager.speakerStatus == .streaming
        return Button {
            if glassesManager.speakerStatus == .stopped {
                glassesManager.startSpeaker()
                webSocketManager.sendCommand(action: "speaker_start")
            } else {
                glassesManager.stopSpeaker()
                webSocketManager.sendCommand(action: "speaker_stop")
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundColor(isActive ? .white : .gray)
                    Text(isActive ? "on" : "talk")
                        .font(.caption)
                        .foregroundColor(isActive ? .white : .gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isActive ? Color.red : Color(white: 0.15))
                .cornerRadius(12)

                if isActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: -8, y: 8)
                }
            }
        }
    }

    private var aiAgentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ai agents")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            aiAgentsGrid
        }
    }

    private var aiAgentsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(AIAgent.allCases, id: \.self) { agent in
                agentButton(for: agent)
            }
        }
    }

    private func agentButton(for agent: AIAgent) -> some View {
        let isSelected = selectedAgents.contains(agent)
        return Button {
            if isSelected {
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
                Text(agent.displayName)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSelected ? agent.color.opacity(0.3) : Color(white: 0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? agent.color : Color.clear, lineWidth: 2)
            )
        }
    }

}


#Preview {
    ContentView()
}
