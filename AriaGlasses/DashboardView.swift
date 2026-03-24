import SwiftUI

// MARK: - Dev Pipeline Agents (refactored from 8 to 6)

enum AIAgent: String, CaseIterable, Codable {
    case planner = "planner"
    case developer = "developer"
    case tester = "tester"
    case codeReviewer = "code_reviewer"
    case deployer = "deployer"
    case reporter = "reporter"

    var displayName: String {
        switch self {
        case .planner: return "Planner"
        case .developer: return "Developer"
        case .tester: return "Tester"
        case .codeReviewer: return "Reviewer"
        case .deployer: return "Deployer"
        case .reporter: return "Reporter"
        }
    }

    var icon: String {
        switch self {
        case .planner: return "list.clipboard"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .tester: return "flask"
        case .codeReviewer: return "magnifyingglass"
        case .deployer: return "arrow.up.circle"
        case .reporter: return "chart.bar"
        }
    }

    var color: Color {
        switch self {
        case .planner: return .purple
        case .developer: return .blue
        case .tester: return .green
        case .codeReviewer: return .orange
        case .deployer: return .pink
        case .reporter: return .cyan
        }
    }

    var waitingText: String {
        switch self {
        case .planner: return "waiting for plan..."
        case .developer: return "waiting for code..."
        case .tester: return "waiting for tests..."
        case .codeReviewer: return "waiting for review..."
        case .deployer: return "waiting for deploy..."
        case .reporter: return "waiting for report..."
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

struct AgentConfig: Codable {
    var model: LLMModel = .claude
    var cli: CLITool = .none
    var useCli: Bool = false
}

// MARK: - Data models

struct TranscriptEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let speaker: String
    let text: String
    let isAI: Bool
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject var webSocketManager: WebSocketManager
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedAgents: Set<AIAgent>
    @Binding var agentConfigs: [AIAgent: AgentConfig]

    @State private var transcript: [TranscriptEntry] = []
    @State private var userInput: String = ""
    @State private var currentFrame: String? = nil
    @State private var desktopFrame: String? = nil
    @State private var aiResponses: [String] = []
    @State private var currentResponseIndex: Int = 0
    @State private var configuringAgent: AIAgent? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        videoSection
                            .frame(maxWidth: .infinity)
                        transcriptSection
                            .frame(maxWidth: .infinity)
                    }

                    aiResponseSection

                    if !selectedAgents.isEmpty {
                        agentPreviewSection
                    }
                }
                .padding()
            }

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
        .onReceive(NotificationCenter.default.publisher(for: .desktopFrameReceived)) { notification in
            if let frame = notification.userInfo?["frame"] as? String {
                desktopFrame = frame
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptReceived)) { notification in
            if let text = notification.userInfo?["text"] as? String,
               let speaker = notification.userInfo?["speaker"] as? String,
               let isAI = notification.userInfo?["isAI"] as? Bool {
                let entry = TranscriptEntry(timestamp: Date(), speaker: speaker, text: text, isAI: isAI)
                transcript.append(entry)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiResponseReceived)) { notification in
            if let response = notification.userInfo?["response"] as? String {
                aiResponses.append(response)
                currentResponseIndex = aiResponses.count - 1
            }
        }
        .sheet(item: $configuringAgent) { agent in
            AgentConfigSheet(
                agent: agent,
                config: Binding(
                    get: { agentConfigs[agent] ?? AgentConfig() },
                    set: { agentConfigs[agent] = $0 }
                ),
                onSave: { config in
                    agentConfigs[agent] = config
                    // Send config to backend
                    webSocketManager.send(message: [
                        "type": "agent_config",
                        "agent": agent.rawValue,
                        "model": config.model.rawValue,
                        "cli": config.cli.rawValue,
                        "use_cli": config.useCli
                    ])
                    configuringAgent = nil
                }
            )
        }
    }

    // MARK: - Video section

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("glasses view")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if glassesManager.videoStatus == .streaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("live")
                            .font(.caption2)
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
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text(glassesManager.videoStatus == .streaming ? "waiting for frames..." : "video stopped")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 250)
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

    // MARK: - Agent preview with config

    private var agentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("agents")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(Array(selectedAgents), id: \.self) { agent in
                        Circle()
                            .fill(agent.color)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // Agent cards with config buttons
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(selectedAgents), id: \.self) { agent in
                    let config = agentConfigs[agent] ?? AgentConfig()
                    Button {
                        configuringAgent = agent
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: agent.icon)
                                .font(.system(size: 20))
                                .foregroundColor(agent.color)
                            Text(agent.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text(config.model.displayName)
                                .font(.system(size: 8))
                                .foregroundColor(config.model.color)
                            if config.useCli {
                                Text(config.cli.displayName)
                                    .font(.system(size: 7))
                                    .foregroundColor(.gray)
                            }
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
                .frame(height: 250)
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
        let agents = selectedAgents.map { $0.rawValue }
        webSocketManager.send(message: [
            "type": "command",
            "text": userInput,
            "agents": agents,
        ])
        userInput = ""
    }
}

// MARK: - Agent Config Sheet

extension AIAgent: Identifiable {
    var id: String { rawValue }
}

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

                    // LLM Model
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LLM MODEL")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(LLMModel.allCases, id: \.self) { model in
                            Button {
                                config.model = model
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(model.color)
                                        .frame(width: 10, height: 10)
                                    Text(model.displayName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if config.model == model {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(agent.color)
                                    }
                                }
                                .padding()
                                .background(config.model == model ? agent.color.opacity(0.15) : Color(white: 0.1))
                                .cornerRadius(10)
                            }
                        }
                    }

                    // CLI Tool
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLI TOOL")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(CLITool.allCases, id: \.self) { cli in
                            Button {
                                config.cli = cli
                                config.useCli = cli != .none
                            } label: {
                                HStack {
                                    Text(cli.displayName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if config.cli == cli {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(agent.color)
                                    }
                                }
                                .padding()
                                .background(config.cli == cli ? agent.color.opacity(0.15) : Color(white: 0.1))
                                .cornerRadius(10)
                            }
                        }
                    }

                    // Use CLI toggle
                    Toggle(isOn: $config.useCli) {
                        Text("Use CLI instead of API")
                    }
                    .padding()
                    .background(Color(white: 0.1))
                    .cornerRadius(10)

                    // Save
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
}

// MARK: - Supporting views

struct TranscriptBubble: View {
    let entry: TranscriptEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if entry.isAI {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.speaker)
                        .font(.caption2)
                        .foregroundColor(entry.isAI ? .purple : .blue)
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Text(entry.text)
                    .font(.callout)
                    .foregroundColor(.white)
            }
            Spacer()
            if !entry.isAI {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 20)
            }
        }
        .padding(10)
        .background(entry.isAI ? Color.purple.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

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

// MARK: - Notifications

extension Notification.Name {
    static let frameReceived = Notification.Name("frameReceived")
    static let aiResponseReceived = Notification.Name("aiResponseReceived")
}
