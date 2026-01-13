import SwiftUI

struct SettingsView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject var webSocketManager: WebSocketManager
    @Binding var selectedAgents: Set<AIAgent>

    @AppStorage("serverURL") private var serverURL = "ws://localhost:8000/glasses"
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ai agents
                VStack(alignment: .leading, spacing: 12) {
                    Text("ai agents")
                        .font(.caption)
                        .foregroundColor(.gray)

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

                        TextField("ws://localhost:8000/glasses", text: $serverURL)
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
                        SettingsRow(icon: "info.circle", iconColor: .blue, title: "version", value: "1.0.0")
                        Divider().background(Color(white: 0.2))
                        SettingsRow(icon: "swift", iconColor: .orange, title: "build", value: "2026.01.10")
                        Divider().background(Color(white: 0.2))
                        SettingsRow(icon: "person.fill", iconColor: .green, title: "developer", value: "aria team")
                    }
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                }

                // links
                VStack(alignment: .leading, spacing: 12) {
                    Text("links")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(spacing: 0) {
                        Button {
                            // open docs
                        } label: {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("documentation")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }

                        Divider().background(Color(white: 0.2))

                        Button {
                            // open github
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                Text("source code")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }

                        Divider().background(Color(white: 0.2))

                        Button {
                            // open support
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text("support")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("connections")
                    .font(.headline)
                    .foregroundColor(.white)
            }
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
        SettingsView(glassesManager: GlassesManager(), webSocketManager: WebSocketManager(), selectedAgents: .constant([]))
    }
}
