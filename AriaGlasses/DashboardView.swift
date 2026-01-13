import SwiftUI

enum AIAgent: String, CaseIterable {
    case developer = "developer"
    case research = "research"
    case computerUse = "cui"
    case translator = "translator"
    case todo = "todo"
    case calendar = "calendar"
    case luma = "luma"
    case persona = "persona"

    var icon: String {
        switch self {
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .research: return "magnifyingglass"
        case .computerUse: return "desktopcomputer"
        case .translator: return "globe"
        case .todo: return "checklist"
        case .calendar: return "calendar"
        case .luma: return "sparkle"
        case .persona: return "person.circle"
        }
    }

    var color: Color {
        switch self {
        case .developer: return .purple
        case .research: return .blue
        case .computerUse: return .orange
        case .translator: return .green
        case .todo: return .yellow
        case .calendar: return .red
        case .luma: return .cyan
        case .persona: return .pink
        }
    }
}

struct TranscriptEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let speaker: String
    let text: String
    let isAI: Bool
}

struct DashboardView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject var webSocketManager: WebSocketManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedAgents: Set<AIAgent> = []
    @State private var viewingAgent: AIAgent? = nil
    @State private var transcript: [TranscriptEntry] = []
    @State private var userInput: String = ""
    @State private var currentFrame: String? = nil
    @State private var desktopFrame: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // video and transcript side by side
                    HStack(alignment: .top, spacing: 12) {
                        // video feed
                        videoSection
                            .frame(maxWidth: .infinity)

                        // transcript
                        transcriptSection
                            .frame(maxWidth: .infinity)
                    }

                    // ai agents
                    agentSelector

                    // agent preview (only show when viewing an agent)
                    if viewingAgent != nil {
                        agentPreviewSection
                    }
                }
                .padding()
            }

            // input fixed at bottom
            inputSection
                .padding()
                .background(Color.black)
        }
        .background(Color.black)
        .navigationTitle("aria")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
    }

    // MARK: - video section

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

    // MARK: - agent preview section

    private var agentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("active agents")
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

            if let agent = viewingAgent {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.1))
                        .aspectRatio(16/9, contentMode: .fit)

                    agentPreviewContent(for: agent)
                }
            }
        }
    }

    @ViewBuilder
    private func agentPreviewContent(for agent: AIAgent) -> some View {
        switch agent {
        case .developer:
            developerPreview
        case .research:
            researchPreview
        case .computerUse:
            computerUsePreview
        case .translator:
            translatorPreview
        case .todo:
            todoPreview
        case .calendar:
            calendarPreview
        case .luma:
            lumaPreview
        case .persona:
            personaPreview
        }
    }

    private var developerPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 36))
                .foregroundColor(.purple.opacity(0.7))
            Text("developer")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.purple)
            Text("waiting for code output...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var researchPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.blue.opacity(0.7))
            Text("research")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            Text("waiting for research results...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var computerUsePreview: some View {
        Group {
            if let frame = desktopFrame,
               let imageData = Data(base64Encoded: frame),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 36))
                        .foregroundColor(.orange.opacity(0.7))
                    Text("cui")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    Text("waiting for desktop stream...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private var translatorPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 36))
                .foregroundColor(.green.opacity(0.7))
            Text("translator")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
            Text("waiting for translation...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var todoPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundColor(.yellow.opacity(0.7))
            Text("todo")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.yellow)
            Text("waiting for tasks...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var calendarPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundColor(.red.opacity(0.7))
            Text("calendar")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.red)
            Text("waiting for schedule...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var lumaPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 36))
                .foregroundColor(.cyan.opacity(0.7))
            Text("luma")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.cyan)
            Text("waiting for events...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var personaPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle")
                .font(.system(size: 36))
                .foregroundColor(.pink.opacity(0.7))
            Text("persona")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.pink)
            Text("waiting for persona...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    // MARK: - agent selector

    private var agentSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ai agents")
                .font(.caption)
                .foregroundColor(.gray)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(AIAgent.allCases, id: \.self) { agent in
                    AgentButtonWithLongPress(
                        agent: agent,
                        isSelected: selectedAgents.contains(agent),
                        onTap: {
                            // tap toggles selection
                            if selectedAgents.contains(agent) {
                                selectedAgents.remove(agent)
                                if viewingAgent == agent {
                                    viewingAgent = selectedAgents.first
                                }
                                webSocketManager.sendCommand(action: "agent_deselect_\(agent.rawValue.replacingOccurrences(of: " ", with: "_"))")
                            } else {
                                selectedAgents.insert(agent)
                                viewingAgent = agent
                                webSocketManager.sendCommand(action: "agent_select_\(agent.rawValue.replacingOccurrences(of: " ", with: "_"))")
                            }
                        },
                        onLongPress: {
                            // long press switches preview to this agent (and selects if not selected)
                            if !selectedAgents.contains(agent) {
                                selectedAgents.insert(agent)
                                webSocketManager.sendCommand(action: "agent_select_\(agent.rawValue.replacingOccurrences(of: " ", with: "_"))")
                            }
                            viewingAgent = agent
                        }
                    )
                }
            }
        }
    }

    // MARK: - transcript section

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
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - input section

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

    // MARK: - actions

    private func sendMessage() {
        guard !userInput.isEmpty else { return }
        let entry = TranscriptEntry(timestamp: Date(), speaker: "you", text: userInput, isAI: false)
        transcript.append(entry)
        let agents = selectedAgents.map { $0.rawValue }
        webSocketManager.send(message: [
            "type": "chat",
            "agents": agents,
            "text": userInput
        ])
        userInput = ""
    }
}

// MARK: - supporting views

struct AgentButton: View {
    let agent: AIAgent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: agent.icon)
                    .font(.system(size: 18))
                Text(agent.rawValue)
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

struct AgentButtonWithLongPress: View {
    let agent: AIAgent
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: agent.icon)
                .font(.system(size: 18))
            Text(agent.rawValue)
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
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            onLongPress()
        }
    }
}

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

struct QuickActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(white: 0.2))
                .cornerRadius(16)
        }
    }
}

// MARK: - notifications

extension Notification.Name {
    static let frameReceived = Notification.Name("frameReceived")
}
