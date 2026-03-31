import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var glassesManager = GlassesManager()
    @State private var agentConfigs: [AIAgent: AgentConfig] = [:]
    @State private var configuringAgent: AIAgent? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User info bar
                    if let user = authManager.user {
                        HStack {
                            Text(user.firstName ?? user.email)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            Button {
                                authManager.signOut()
                            } label: {
                                Text("sign out")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 4)
                    }

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
                // Pass auth token to WebSocket manager
                webSocketManager.accessToken = authManager.accessToken

                glassesManager.setFrameCallback { base64Data in
                    webSocketManager.sendFrame(base64Data: base64Data)
                }
                glassesManager.setAudioCallback { [weak glassesManager] base64Data in
                    // Only send audio to backend when using Whisper, not Apple Speech
                    guard glassesManager?.sttProvider != "apple" else { return }
                    webSocketManager.sendAudio(base64Data: base64Data)
                }
                // Apple Speech on-device transcription callback
                glassesManager.setTranscriptionCallback { text, isFinal in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Ignore empty or very short results (likely noise)
                    guard trimmed.count > 3 else { return }
                    // Update local transcript (partial updates replace last entry)
                    NotificationCenter.default.post(
                        name: .transcriptReceived,
                        object: nil,
                        userInfo: ["text": text, "speaker": "you", "isAI": false, "isFinal": isFinal]
                    )
                    // Only send final results to server
                    if isFinal {
                        webSocketManager.send(message: [
                            "type": "transcription",
                            "text": text,
                            "source": "apple_speech",
                        ])
                    }
                }
                // Load saved agent configs from MongoDB
                webSocketManager.loadAgentConfigs { configs in
                    Task { @MainActor in
                        for (agentType, configData) in configs {
                            guard let agent = AIAgent(rawValue: agentType) else { continue }
                            var config = agent.defaultConfig
                            if let model = configData["model"] as? String,
                               let llm = LLMModel(rawValue: model) {
                                config.model = llm
                            }
                            if let cli = configData["cli"] as? String,
                               let tool = CLITool(rawValue: cli) {
                                config.cli = tool
                            }
                            if let useCli = configData["use_cli"] as? Bool {
                                config.useCli = useCli
                            }
                            if let tts = configData["tts_provider"] as? String,
                               let provider = TTSProvider(rawValue: tts) {
                                config.ttsProvider = provider
                            }
                            if let stt = configData["stt_provider"] as? String,
                               let provider = STTProvider(rawValue: stt) {
                                config.sttProvider = provider
                            }
                            agentConfigs[agent] = config
                        }
                    }
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
        .sheet(item: $configuringAgent) { agent in
            AgentConfigSheet(
                agent: agent,
                config: Binding(
                    get: { agentConfigs[agent] ?? agent.defaultConfig },
                    set: { agentConfigs[agent] = $0 }
                ),
                onSave: { config in
                    agentConfigs[agent] = config
                    webSocketManager.saveAgentConfig(
                        agentType: agent.rawValue,
                        model: config.model.rawValue,
                        cli: config.cli.rawValue,
                        useCli: config.useCli,
                        ttsProvider: config.ttsProvider.rawValue,
                        sttProvider: config.sttProvider.rawValue
                    )
                    configuringAgent = nil
                }
            )
        }
    }

    private var dashboardButton: some View {
        NavigationLink {
            DashboardView(glassesManager: glassesManager, webSocketManager: webSocketManager, agentConfigs: $agentConfigs)
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Image("aria_logo_body")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                    Image("aria_logo_dot")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(glassesManager.videoStatus == .streaming ? .red : .white)
                        .shadow(color: glassesManager.videoStatus == .streaming ? .red : .clear, radius: 6)
                }
                .frame(height: 70)
                Text("tap to enter aria experience")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
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
                Text(glassesManager.connectionStatus == .disconnected ? "connect to meta glasses" : "disconnect")
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
                Text(webSocketManager.status == .disconnected ? "connect to aria ai" : "disconnect")
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
                    Text(isActive ? "rec" : "camera")
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
                // Set STT provider from config
                let sttConfig = agentConfigs[.speechToText] ?? AIAgent.speechToText.defaultConfig
                glassesManager.sttProvider = sttConfig.sttProvider.rawValue
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
                    Text(isActive ? "on" : "mic")
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
                    Text(isActive ? "on" : "speaker")
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
        let config = agentConfigs[agent] ?? agent.defaultConfig
        return Button {
            configuringAgent = agent
        } label: {
            VStack(spacing: 3) {
            Image(systemName: agent.icon)
                .font(.system(size: 16))
                .foregroundColor(agent.color)
            Text(agent.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            if agent.isDevAgent {
                if config.useCli {
                    Text(config.cli.displayName)
                        .font(.system(size: 7))
                        .foregroundColor(.gray)
                } else {
                    Text(config.model.displayName)
                        .font(.system(size: 7))
                        .foregroundColor(config.model.color)
                }
            } else if agent == .orchestrator {
                Text(config.model.displayName)
                    .font(.system(size: 7))
                    .foregroundColor(config.model.color)
            } else if agent == .textToSpeech {
                Text(config.ttsProvider.displayName)
                    .font(.system(size: 7))
                    .foregroundColor(config.ttsProvider.color)
            } else if agent == .speechToText {
                Text(config.sttProvider.displayName)
                    .font(.system(size: 7))
                    .foregroundColor(config.sttProvider.color)
            }
        }
            .frame(maxWidth: .infinity)
            .frame(height: 65)
            .background(agent.color.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(agent.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}



#Preview {
    ContentView()
}
