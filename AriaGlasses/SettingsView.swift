import SwiftUI

struct SettingsView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject var webSocketManager: WebSocketManager
    @Binding var selectedAgents: Set<AIAgent>
    @Binding var agentConfigs: [AIAgent: AgentConfig]

    @AppStorage("serverURL") private var serverURL = "ws://localhost:8888/glasses"
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    @State private var configuringAgent: AIAgent? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ai agents (6 dev pipeline agents)
                VStack(alignment: .leading, spacing: 12) {
                    Text("development agents")
                        .font(.caption)
                        .foregroundColor(.gray)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(AIAgent.allCases, id: \.self) { agent in
                            let config = agentConfigs[agent] ?? AgentConfig()
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
                                    Text(agent.displayName)
                                        .font(.system(size: 9))
                                        .lineLimit(1)
                                    Text(config.model.displayName)
                                        .font(.system(size: 7))
                                        .foregroundColor(config.model.color)
                                }
                                .foregroundColor(selectedAgents.contains(agent) ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(selectedAgents.contains(agent) ? agent.color.opacity(0.3) : Color(white: 0.15))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedAgents.contains(agent) ? agent.color : Color.clear, lineWidth: 2)
                                )
                            }
                            .contextMenu {
                                Button {
                                    configuringAgent = agent
                                } label: {
                                    Label("Configure Model & CLI", systemImage: "gearshape")
                                }
                            }
                        }
                    }

                    Text("Long press an agent to configure its model & CLI")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                // agent configs summary
                if !selectedAgents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("agent configurations")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(Array(selectedAgents).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { agent in
                            let config = agentConfigs[agent] ?? AgentConfig()
                            Button {
                                configuringAgent = agent
                            } label: {
                                HStack {
                                    Image(systemName: agent.icon)
                                        .foregroundColor(agent.color)
                                        .frame(width: 24)
                                    Text(agent.displayName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(config.model.displayName)
                                            .font(.caption2)
                                            .foregroundColor(config.model.color)
                                        if config.useCli {
                                            Text(config.cli.displayName)
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .background(Color(white: 0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }

                // status
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        SettingsStatusCell(title: "glasses", value: glassesManager.connectionStatus.rawValue.lowercased(), isActive: glassesManager.connectionStatus == .connected)
                        SettingsStatusCell(title: "kernel", value: webSocketManager.status.rawValue.lowercased(), isActive: webSocketManager.status == .connected)
                        SettingsStatusCell(title: "session", value: glassesManager.sessionStatus.rawValue.lowercased(), isActive: glassesManager.sessionStatus == .active)
                    }
                }
                .cornerRadius(12)

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

                // connections
                VStack(alignment: .leading, spacing: 12) {
                    Text("connections")
                        .font(.caption)
                        .foregroundColor(.gray)

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
                                Text(glassesManager.connectionStatus == .disconnected ? "connect" : "disconnect")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(glassesManager.connectionStatus == .connected ? Color.green.opacity(0.3) : Color(white: 0.15))
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
                                Text(webSocketManager.status == .disconnected ? "kernel" : "disconnect")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(webSocketManager.status == .connected ? Color.green.opacity(0.3) : Color(white: 0.15))
                            .cornerRadius(12)
                        }
                    }
                }

                // connection settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("connection settings")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("kernel url")
                            Spacer()
                        }
                        .padding()
                        .background(Color(white: 0.1))

                        TextField("ws://localhost:8888/glasses", text: $serverURL)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .padding()
                            .background(Color(white: 0.08))
                    }
                    .cornerRadius(12)

                    Toggle(isOn: $autoConnect) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            Text("auto connect")
                        }
                    }
                    .padding()
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                }

                // preferences
                VStack(alignment: .leading, spacing: 12) {
                    Text("preferences")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Toggle(isOn: $hapticFeedback) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("haptic feedback")
                        }
                    }
                    .padding()
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                }

                // about
                VStack(alignment: .leading, spacing: 12) {
                    Text("about")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(spacing: 0) {
                        SettingsRow(icon: "info.circle", iconColor: .blue, title: "version", value: "2.0.0")
                        Divider().background(Color(white: 0.2))
                        SettingsRow(icon: "swift", iconColor: .orange, title: "build", value: "2026.03.23")
                        Divider().background(Color(white: 0.2))
                        SettingsRow(icon: "person.fill", iconColor: .green, title: "developer", value: "aria team")
                    }
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color.black)
        .foregroundColor(.white)
        .navigationTitle("connections")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $configuringAgent) { agent in
            AgentConfigSheet(
                agent: agent,
                config: Binding(
                    get: { agentConfigs[agent] ?? AgentConfig() },
                    set: { agentConfigs[agent] = $0 }
                ),
                onSave: { config in
                    agentConfigs[agent] = config
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
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct SettingsStatusCell: View {
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
    NavigationView {
        SettingsView(
            glassesManager: GlassesManager(),
            webSocketManager: WebSocketManager(),
            selectedAgents: .constant([]),
            agentConfigs: .constant([:])
        )
    }
}
