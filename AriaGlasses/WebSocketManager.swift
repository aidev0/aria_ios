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
    private let serverURL = URL(string: "ws://localhost:8000/glasses")!

    func connect() {
        guard status == .disconnected else { return }
        status = .connecting

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: serverURL)
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
        } else if type == "transcript" {
            let text = json["text"] as? String ?? ""
            let speaker = json["speaker"] as? String ?? "ai"
            let isAI = json["isAI"] as? Bool ?? true
            NotificationCenter.default.post(name: .transcriptReceived, object: nil, userInfo: ["text": text, "speaker": speaker, "isAI": isAI])
        }
    }
}

extension Notification.Name {
    static let glassesCommand = Notification.Name("glassesCommand")
    static let aiSpeaking = Notification.Name("aiSpeaking")
    static let desktopFrameReceived = Notification.Name("desktopFrameReceived")
    static let transcriptReceived = Notification.Name("transcriptReceived")
}
