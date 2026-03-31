import Foundation

enum WebSocketStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
}

@MainActor
class WebSocketManager: ObservableObject {
    @Published var status: WebSocketStatus = .disconnected

    private var webSocket: URLSessionWebSocketTask?

    var serverBaseURL: String {
        get { UserDefaults.standard.string(forKey: "serverBaseURL") ?? "https://aria-ai-backend-27308708253a.herokuapp.com" }
        set { UserDefaults.standard.set(newValue, forKey: "serverBaseURL") }
    }

    private var wsBaseURL: String {
        serverBaseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
    }

    var apiBaseURL: String { serverBaseURL }

    var accessToken: String?

    func connect() {
        guard status == .disconnected else { return }
        status = .connecting

        var urlString = "\(wsBaseURL)/glasses"
        if let token = accessToken, !token.isEmpty {
            urlString += "?token=\(token)"
        }
        guard let url = URL(string: urlString) else {
            status = .disconnected
            return
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        status = .connected
        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        status = .disconnected
    }

    func sendCommand(action: String) {
        send(message: ["type": "command", "action": action])
    }

    func sendFrame(base64Data: String) {
        send(message: ["type": "frame", "data": base64Data])
    }

    func sendAudio(base64Data: String) {
        send(message: ["type": "audio", "data": base64Data])
    }

    func send(message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }

    // MARK: - Agent Config Persistence (REST API → MongoDB)

    func saveAgentConfig(agentType: String, model: String, cli: String, useCli: Bool, ttsProvider: String = "elevenlabs", sttProvider: String = "whisper") {
        guard let url = URL(string: "\(apiBaseURL)/agents/\(agentType)/config") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "cli": cli,
            "use_cli": useCli,
            "tts_provider": ttsProvider,
            "stt_provider": sttProvider
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Save agent config error: \(error)")
            }
        }.resume()
    }

    func loadAgentConfigs(completion: @escaping ([String: [String: Any]]) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)/agents/configs/all") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let configs = json["configs"] as? [[String: Any]] else {
                completion([:])
                return
            }

            var result: [String: [String: Any]] = [:]
            for config in configs {
                if let agentType = config["agent_type"] as? String {
                    result[agentType] = config
                }
            }
            completion(result)
        }.resume()
    }

    // MARK: - Receive

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handleMessage(text)
                    }
                    self.receiveMessage()
                case .failure:
                    self.status = .disconnected
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        let action = json["action"] as? String ?? ""

        if type == "command" {
            NotificationCenter.default.post(name: .glassesCommand, object: nil, userInfo: ["action": action])
        } else if type == "ai_speaking" {
            NotificationCenter.default.post(name: .aiSpeaking, object: nil, userInfo: ["action": action])
        } else if type == "desktop_frame", let frameData = json["data"] as? String {
            NotificationCenter.default.post(name: .desktopFrameReceived, object: nil, userInfo: ["frame": frameData])
        } else if type == "transcript" || type == "transcription" {
            let text = json["text"] as? String ?? ""
            let sessionId = json["session_id"] as? String ?? ""
            let speaker = json["speaker"] as? String ?? "user"
            let segments = json["segments"] as? [[String: Any]] ?? []
            // User voice transcription from STT
            NotificationCenter.default.post(
                name: .userTranscriptionReceived,
                object: nil,
                userInfo: [
                    "text": text,
                    "session_id": sessionId,
                    "speaker": speaker,
                    "segments": segments
                ]
            )
            // Also post legacy notification for backward compat
            NotificationCenter.default.post(name: .transcriptReceived, object: nil, userInfo: ["text": text, "speaker": speaker, "isAI": false])
        } else if type == "ai_response" {
            let responseText = json["text"] as? String ?? ""
            NotificationCenter.default.post(name: .aiResponseReceived, object: nil, userInfo: ["response": responseText])
        }
    }
}

extension Notification.Name {
    static let glassesCommand = Notification.Name("glassesCommand")
    static let aiSpeaking = Notification.Name("aiSpeaking")
    static let desktopFrameReceived = Notification.Name("desktopFrameReceived")
    static let transcriptReceived = Notification.Name("transcriptReceived")
    static let userTranscriptionReceived = Notification.Name("userTranscriptionReceived")
    // aiResponseReceived is defined in DashboardView.swift
}
