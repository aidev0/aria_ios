import SwiftUI

// MARK: - Dev Pipeline Agents (6 agents, always active)

enum AIAgent: String, CaseIterable, Codable, Identifiable {
    case planner = "planner"
    case planReviewer = "plan_reviewer"
    case developer = "developer"
    case tester = "tester"
    case codeReviewer = "code_reviewer"
    case deployer = "deployer"
    case reporter = "reporter"
    case orchestrator = "orchestrator"
    case speechToText = "speech_to_text"
    case textToSpeech = "text_to_speech"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planner: return "Planner"
        case .developer: return "Developer"
        case .tester: return "Tester"
        case .planReviewer: return "Plan Reviewer"
        case .codeReviewer: return "Reviewer"
        case .deployer: return "Deployer"
        case .reporter: return "Reporter"
        case .orchestrator: return "Orchestrator"
        case .speechToText: return "STT"
        case .textToSpeech: return "TTS"
        }
    }

    var icon: String {
        switch self {
        case .planner: return "list.clipboard"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .tester: return "flask"
        case .planReviewer: return "checklist"
        case .codeReviewer: return "magnifyingglass"
        case .deployer: return "arrow.up.circle"
        case .reporter: return "chart.bar"
        case .orchestrator: return "cpu"
        case .speechToText: return "waveform"
        case .textToSpeech: return "speaker.wave.3"
        }
    }

    var color: Color {
        switch self {
        case .planner: return .purple
        case .developer: return .blue
        case .tester: return .green
        case .planReviewer: return .teal
        case .codeReviewer: return .orange
        case .deployer: return .pink
        case .reporter: return .cyan
        case .orchestrator: return .yellow
        case .speechToText: return .indigo
        case .textToSpeech: return .mint
        }
    }

    var waitingText: String {
        switch self {
        case .planner: return "waiting for plan..."
        case .developer: return "waiting for code..."
        case .tester: return "waiting for tests..."
        case .planReviewer: return "waiting for plan review..."
        case .codeReviewer: return "waiting for review..."
        case .deployer: return "waiting for deploy..."
        case .reporter: return "waiting for report..."
        case .orchestrator: return "waiting to orchestrate..."
        case .speechToText: return "waiting for audio..."
        case .textToSpeech: return "waiting for text..."
        }
    }

    var isDevAgent: Bool {
        switch self {
        case .orchestrator, .speechToText, .textToSpeech: return false
        default: return true
        }
    }

    var defaultConfig: AgentConfig {
        switch self {
        case .planner:
            return AgentConfig(model: .claude, cli: .claude, useCli: true)
        case .planReviewer:
            return AgentConfig(model: .openai, cli: .codex, useCli: true)
        case .developer:
            return AgentConfig(model: .claude, cli: .claude, useCli: true)
        case .tester:
            return AgentConfig(model: .gemini, cli: .gemini, useCli: true)
        case .codeReviewer:
            return AgentConfig(model: .openai, cli: .codex, useCli: true)
        case .deployer:
            return AgentConfig(model: .claude, cli: .claude, useCli: true)
        case .reporter:
            return AgentConfig(model: .claude, cli: .none, useCli: false)
        case .orchestrator:
            return AgentConfig(model: .claude, cli: .none, useCli: false)
        case .speechToText:
            return AgentConfig(sttProvider: .whisper)
        case .textToSpeech:
            return AgentConfig(ttsProvider: .elevenlabs)
        }
    }
}

// MARK: - Model & CLI options

enum LLMModel: String, CaseIterable, Codable {
    case claude = "claude"
    case gemini = "gemini"
    case openai = "openai"

    var displayName: String {
        switch self {
        case .claude: return "Claude Opus 4.6"
        case .gemini: return "Gemini 3.1 Pro"
        case .openai: return "GPT-5.4"
        }
    }

    var color: Color {
        switch self {
        case .claude: return .orange
        case .gemini: return .blue
        case .openai: return .green
        }
    }
}

enum CLITool: String, CaseIterable, Codable {
    case none = "none"
    case claude = "claude"
    case gemini = "gemini"
    case codex = "codex"

    var displayName: String {
        switch self {
        case .none: return "API Only"
        case .claude: return "Claude Code"
        case .gemini: return "Gemini CLI"
        case .codex: return "Codex CLI"
        }
    }
}

enum TTSProvider: String, CaseIterable, Codable {
    case elevenlabs = "elevenlabs"
    case openaiTTS = "openai_tts"

    var displayName: String {
        switch self {
        case .elevenlabs: return "ElevenLabs"
        case .openaiTTS: return "OpenAI TTS"
        }
    }

    var color: Color {
        switch self {
        case .elevenlabs: return .mint
        case .openaiTTS: return .green
        }
    }
}

enum STTProvider: String, CaseIterable, Codable {
    case whisper = "whisper"
    case apple = "apple"

    var displayName: String {
        switch self {
        case .whisper: return "Whisper"
        case .apple: return "Apple Speech"
        }
    }

    var color: Color {
        switch self {
        case .whisper: return .indigo
        case .apple: return .blue
        }
    }
}

struct AgentConfig: Codable {
    var model: LLMModel = .claude
    var cli: CLITool = .none
    var useCli: Bool = false
    var ttsProvider: TTSProvider = .elevenlabs
    var sttProvider: STTProvider = .whisper
}

// MARK: - Data models

struct TranscriptEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let speaker: String
    let text: String
    let isAI: Bool

    init(id: UUID = UUID(), timestamp: Date, speaker: String, text: String, isAI: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.speaker = speaker
        self.text = text
        self.isAI = isAI
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject var webSocketManager: WebSocketManager
    @Environment(\.presentationMode) var presentationMode
    @Binding var agentConfigs: [AIAgent: AgentConfig]

    @State private var transcript: [TranscriptEntry] = []
    @State private var userInput: String = ""
    @State private var currentFrame: String? = nil
    @State private var aiResponses: [String] = []
    @State private var currentResponseIndex: Int = 0
    @State private var bottomTab: BottomTab = .aiResponse

    enum BottomTab: String, CaseIterable {
        case aiResponse = "ai response"
        case preview = "preview"
    }

    var body: some View {
        VStack(spacing: 0) {
            topSection
            bottomToggleSection
            Spacer(minLength: 0)
            inputSection
                .padding()
                .background(Color.black)
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("aria")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .frameReceived)) { notification in
            if let frame = notification.userInfo?["frame"] as? String {
                currentFrame = frame
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptReceived)) { notification in
            if let text = notification.userInfo?["text"] as? String,
               let speaker = notification.userInfo?["speaker"] as? String,
               let isAI = notification.userInfo?["isAI"] as? Bool {
                let isFinal = notification.userInfo?["isFinal"] as? Bool ?? true
                if !isFinal, let last = transcript.last, !last.isAI {
                    // Partial result — update the last entry in place, keep same ID
                    transcript[transcript.count - 1] = TranscriptEntry(id: last.id, timestamp: last.timestamp, speaker: speaker, text: text, isAI: isAI)
                } else {
                    transcript.append(TranscriptEntry(timestamp: Date(), speaker: speaker, text: text, isAI: isAI))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiResponseReceived)) { notification in
            if let response = notification.userInfo?["response"] as? String {
                aiResponses.append(response)
                currentResponseIndex = aiResponses.count - 1
            }
        }
    }

    // MARK: - Layout sub-views

    private var topSection: some View {
        HStack(alignment: .top, spacing: 8) {
            videoSection
                .frame(maxWidth: .infinity)
            transcriptSection
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var bottomToggleSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(BottomTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { bottomTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(bottomTab == tab ? Color(white: 0.2) : Color.clear)
                            .foregroundColor(bottomTab == tab ? .white : .gray)
                    }
                }
            }
            .background(Color(white: 0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 12)

            if bottomTab == .aiResponse {
                aiResponseSection
                    .padding(.horizontal)
                    .padding(.top, 8)
            } else {
                desktopPreviewSection
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Video section

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("video")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if glassesManager.videoStatus == .streaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("live")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.1))

                if let frame = currentFrame,
                   let imageData = Data(base64Encoded: frame),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .cornerRadius(12)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                        Text(glassesManager.videoStatus == .streaming ? "waiting..." : "no video")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 300)
            .clipped()
        }
    }

    // MARK: - Desktop Preview section

    private var desktopPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("desktop preview")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.1))

                VStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("desktop stream will appear here")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - AI Response section

    private var aiResponseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ai response")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if aiResponses.count > 1 {
                    Text("\(currentResponseIndex + 1)/\(aiResponses.count)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            ScrollView {
                Text(aiResponses.isEmpty ? "waiting for ai response..." : aiResponses[currentResponseIndex])
                    .font(.callout)
                    .foregroundColor(aiResponses.isEmpty ? .gray : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 100)
            .background(Color(white: 0.1))
            .cornerRadius(12)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < 0, currentResponseIndex < aiResponses.count - 1 {
                            withAnimation { currentResponseIndex += 1 }
                        } else if value.translation.width > 0, currentResponseIndex > 0 {
                            withAnimation { currentResponseIndex -= 1 }
                        }
                    }
            )
        }
    }

    // MARK: - Agent preview (all 6 always active)

    private var agentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("agents")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(AIAgent.allCases) { agent in
                        Circle()
                            .fill(agent.color)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(AIAgent.allCases) { agent in
                    let config = agentConfigs[agent] ?? agent.defaultConfig
                    VStack(spacing: 6) {
                        Image(systemName: agent.icon)
                            .font(.system(size: 20))
                            .foregroundColor(agent.color)
                        Text(agent.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        if agent.isDevAgent {
                            Text(config.model.displayName)
                                .font(.system(size: 8))
                                .foregroundColor(config.model.color)
                            if config.useCli {
                                Text(config.cli.displayName)
                                    .font(.system(size: 7))
                                    .foregroundColor(.gray)
                            }
                        } else if agent == .textToSpeech {
                            Text(config.ttsProvider.displayName)
                                .font(.system(size: 8))
                                .foregroundColor(config.ttsProvider.color)
                        } else if agent == .speechToText {
                            Text(config.sttProvider.displayName)
                                .font(.system(size: 8))
                                .foregroundColor(config.sttProvider.color)
                        }
                        Text(agent.waitingText)
                            .font(.system(size: 7))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(agent.color.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(agent.color.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Transcript section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("transcript")
                .font(.caption)
                .foregroundColor(.gray)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if transcript.isEmpty {
                            Text("transcript will appear here...")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(transcript) { entry in
                                TranscriptBubbleCompact(entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 300)
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .onChange(of: transcript.count) { _ in
                    if let last = transcript.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    // MARK: - Input section

    private var inputSection: some View {
        HStack {
            TextField("ask aria...", text: $userInput)
                .textFieldStyle(.plain)
                .foregroundColor(.white)

            if !userInput.isEmpty {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.15))
        .cornerRadius(22)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !userInput.isEmpty else { return }
        let entry = TranscriptEntry(timestamp: Date(), speaker: "you", text: userInput, isAI: false)
        transcript.append(entry)
        webSocketManager.send(message: [
            "type": "command",
            "text": userInput,
        ])
        userInput = ""
    }
}

// MARK: - Supporting views

struct TranscriptBubbleCompact: View {
    let entry: TranscriptEntry

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: entry.isAI ? "brain.head.profile" : "person.fill")
                .font(.system(size: 10))
                .foregroundColor(entry.isAI ? .purple : .blue)
                .frame(width: 14)
            Text(entry.text)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(entry.isAI ? Color.purple.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Agent Config Sheet

struct AgentConfigSheet: View {
    let agent: AIAgent
    @Binding var config: AgentConfig
    let onSave: (AgentConfig) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: agent.icon)
                            .font(.system(size: 36))
                            .foregroundColor(agent.color)
                        Text(agent.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .padding(.top)

                    if agent.isDevAgent {
                        devAgentConfig
                    } else if agent == .orchestrator {
                        orchestratorConfig
                    } else if agent == .textToSpeech {
                        ttsConfig
                    } else if agent == .speechToText {
                        sttConfig
                    }

                    Button {
                        onSave(config)
                    } label: {
                        Text("Save Configuration")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(agent.color)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Configure \(agent.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Dev Agent Config (CLI vs API toggle + model/CLI selection)

    @State private var showCli: Bool = false

    private var devAgentConfig: some View {
        VStack(spacing: 20) {
            // CLI vs API toggle (just for browsing)
            HStack(spacing: 0) {
                Button {
                    showCli = false
                } label: {
                    Text("API")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(!showCli ? agent.color : Color(white: 0.15))
                        .foregroundColor(!showCli ? .white : .gray)
                }

                Button {
                    showCli = true
                } label: {
                    Text("CLI")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(showCli ? agent.color : Color(white: 0.15))
                        .foregroundColor(showCli ? .white : .gray)
                }
            }
            .cornerRadius(12)
            .onAppear { showCli = config.useCli }

            if showCli {
                // CLI TOOL
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLI TOOL")
                        .font(.caption)
                        .foregroundColor(.gray)

                    ForEach(CLITool.allCases.filter { $0 != .none }, id: \.self) { cli in
                        Button {
                            config.useCli = true
                            config.cli = cli
                        } label: {
                            HStack {
                                Image(systemName: "terminal")
                                    .foregroundColor(agent.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cli.displayName)
                                        .foregroundColor(.white)
                                        .font(.callout)
                                    Text(cliDetail(cli))
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if config.useCli && config.cli == cli {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(agent.color)
                                }
                            }
                            .padding()
                            .background(config.useCli && config.cli == cli ? agent.color.opacity(0.15) : Color(white: 0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            } else {
                // LLM MODEL
                VStack(alignment: .leading, spacing: 8) {
                    Text("LLM MODEL")
                        .font(.caption)
                        .foregroundColor(.gray)

                    ForEach(LLMModel.allCases, id: \.self) { model in
                        Button {
                            config.useCli = false
                            config.cli = .none
                            config.model = model
                        } label: {
                            HStack {
                                Circle().fill(model.color).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .foregroundColor(.white)
                                        .font(.callout)
                                    Text(modelDetail(model))
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if !config.useCli && config.model == model {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(agent.color)
                                }
                            }
                            .padding()
                            .background(!config.useCli && config.model == model ? agent.color.opacity(0.15) : Color(white: 0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    // MARK: - TTS Config

    // MARK: - Orchestrator Config (API only, 3 LLM models)

    private var orchestratorConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LLM MODEL")
                .font(.caption)
                .foregroundColor(.gray)

            ForEach(LLMModel.allCases, id: \.self) { model in
                Button { config.model = model } label: {
                    HStack {
                        Circle().fill(model.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .foregroundColor(.white)
                                .font(.callout)
                            Text(modelDetail(model))
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if config.model == model {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(agent.color)
                        }
                    }
                    .padding()
                    .background(config.model == model ? agent.color.opacity(0.15) : Color(white: 0.1))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - TTS Config

    private var ttsConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TTS PROVIDER")
                .font(.caption)
                .foregroundColor(.gray)

            ForEach(TTSProvider.allCases, id: \.self) { provider in
                Button { config.ttsProvider = provider } label: {
                    HStack {
                        Circle().fill(provider.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .foregroundColor(.white)
                                .font(.callout)
                            Text(ttsDetail(provider))
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if config.ttsProvider == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(agent.color)
                        }
                    }
                    .padding()
                    .background(config.ttsProvider == provider ? agent.color.opacity(0.15) : Color(white: 0.1))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - STT Config

    private var sttConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STT PROVIDER")
                .font(.caption)
                .foregroundColor(.gray)

            ForEach(STTProvider.allCases, id: \.self) { provider in
                Button { config.sttProvider = provider } label: {
                    HStack {
                        Circle().fill(provider.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .foregroundColor(.white)
                                .font(.callout)
                            Text(sttDetail(provider))
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if config.sttProvider == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(agent.color)
                        }
                    }
                    .padding()
                    .background(config.sttProvider == provider ? agent.color.opacity(0.15) : Color(white: 0.1))
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Detail strings

    private func modelDetail(_ model: LLMModel) -> String {
        switch model {
        case .claude: return "claude-opus-4-6 · 1M context · Vision + Tools"
        case .gemini: return "gemini-3.1-pro-preview · 2M context · Multimodal"
        case .openai: return "gpt-5.4 · 1M context · Function calling"
        }
    }

    private func cliDetail(_ cli: CLITool) -> String {
        switch cli {
        case .claude: return "@anthropic-ai/claude-code · Agentic coding"
        case .gemini: return "@google/gemini-cli · Google AI terminal"
        case .codex: return "@openai/codex · Code generation + execution"
        case .none: return ""
        }
    }

    private func ttsDetail(_ provider: TTSProvider) -> String {
        switch provider {
        case .elevenlabs: return "elevenlabs.io · Natural voice synthesis"
        case .openaiTTS: return "openai/tts · High-quality speech generation"
        }
    }

    private func sttDetail(_ provider: STTProvider) -> String {
        switch provider {
        case .whisper: return "openai/whisper · Speech recognition"
        case .apple: return "On-device · Apple Speech framework"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let frameReceived = Notification.Name("frameReceived")
    static let aiResponseReceived = Notification.Name("aiResponseReceived")
}
