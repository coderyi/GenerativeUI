import UIKit
import GenerativeUI

/// Chat interface where users type natural language prompts and receive
/// LLM-generated ViewSpec cards rendered as interactive bubbles.
final class ChatViewController: UIViewController {

    // MARK: - Dependencies

    private let runtime = GenerativeUIRuntime()
    private let llmService: GenerativeUILLMService
    private let weatherService = WeatherService()
    private let githubTrendingService = GitHubTrendingService()

    // MARK: - State

    private var messages: [ChatMessage] = []
    private var isSending = false

    // MARK: - Suggestion Data

    private struct Suggestion {
        let displayText: String
        let promptText: String
    }

    private let suggestions: [Suggestion] = [
        // Real-time data demos
        Suggestion(
            displayText: "上海天气",
            promptText: "上海天气"
        ),
        Suggestion(
            displayText: "GitHub 热门仓库",
            promptText: "github 热门仓库"
        ),
        // LLM-generated UI demos
        Suggestion(
            displayText: "酒店预订卡片",
            promptText: "生成一个酒店预订卡片，包含酒店图片、名称、价格和预订按钮"
        ),
        Suggestion(
            displayText: "商品详情",
            promptText: "生成一个带标签页的商品详情，分为描述、规格和评价三个页签"
        ),
Suggestion(
            displayText: "待办清单",
            promptText: "生成一个带复选框的待办清单，包含多个待办事项和清空按钮"
        ),
        Suggestion(
            displayText: "日程安排",
            promptText: "生成一个日程安排组件，包含日期选择器和时间选择器"
        ),
    ]

    // MARK: - UI Elements

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorStyle = .none
        tv.allowsSelection = false
        tv.keyboardDismissMode = .interactive
        tv.estimatedRowHeight = 60
        tv.rowHeight = UITableView.automaticDimension
        return tv
    }()

    private let suggestionsBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        return v
    }()

    private let suggestionsBarSeparator: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .separator
        return v
    }()

    private lazy var suggestionsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(SuggestionChipCell.self, forCellWithReuseIdentifier: SuggestionChipCell.reuseIdentifier)
        return cv
    }()

    private let inputBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        return v
    }()

    private let inputField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "描述你想要的界面..."
        field.borderStyle = .roundedRect
        field.returnKeyType = .send
        field.font = .systemFont(ofSize: 16)
        return field
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("发送", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return button
    }()

    /// Separator line at top of input bar.
    private let inputBarSeparator: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .separator
        return v
    }()

    /// Bottom constraint of the input bar, adjusted for keyboard.
    private var inputBarBottomConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle

    init() {
        // Replace with your own API key before running the chat demo.
        let apiKey = ""
        let provider = DefaultLLMProvider(apiKey: apiKey)
        self.llmService = GenerativeUILLMService(
            provider: provider,
            systemPrompt: ChatSystemPrompt.text
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chat 生成 UI"
        view.backgroundColor = .systemBackground

        setupTableView()
        setupSuggestionsBar()
        setupInputBar()
        setupKeyboardObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.reuseIdentifier)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupSuggestionsBar() {
        suggestionsBar.addSubview(suggestionsBarSeparator)
        suggestionsBar.addSubview(suggestionsCollectionView)
        view.addSubview(suggestionsBar)

        NSLayoutConstraint.activate([
            // Suggestions bar position: tableView → suggestionsBar → inputBar (connected in setupInputBar)
            suggestionsBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: suggestionsBar.topAnchor),
            suggestionsBar.heightAnchor.constraint(equalToConstant: 52),

            // Top separator
            suggestionsBarSeparator.topAnchor.constraint(equalTo: suggestionsBar.topAnchor),
            suggestionsBarSeparator.leadingAnchor.constraint(equalTo: suggestionsBar.leadingAnchor),
            suggestionsBarSeparator.trailingAnchor.constraint(equalTo: suggestionsBar.trailingAnchor),
            suggestionsBarSeparator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // CollectionView fills the bar with vertical padding
            suggestionsCollectionView.topAnchor.constraint(equalTo: suggestionsBar.topAnchor, constant: 8),
            suggestionsCollectionView.leadingAnchor.constraint(equalTo: suggestionsBar.leadingAnchor),
            suggestionsCollectionView.trailingAnchor.constraint(equalTo: suggestionsBar.trailingAnchor),
            suggestionsCollectionView.bottomAnchor.constraint(equalTo: suggestionsBar.bottomAnchor, constant: -8),
        ])
    }

    private func setupInputBar() {
        inputField.delegate = self
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        inputBar.addSubview(inputBarSeparator)
        inputBar.addSubview(inputField)
        inputBar.addSubview(sendButton)
        view.addSubview(inputBar)

        inputBarBottomConstraint = inputBar.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )

        NSLayoutConstraint.activate([
            // Input bar position
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarBottomConstraint,

            // suggestionsBar → inputBar (completes the constraint chain from setupSuggestionsBar)
            suggestionsBar.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            // Separator
            inputBarSeparator.topAnchor.constraint(equalTo: inputBar.topAnchor),
            inputBarSeparator.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor),
            inputBarSeparator.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor),
            inputBarSeparator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // Input field
            inputField.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: 8),
            inputField.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 12),
            inputField.bottomAnchor.constraint(equalTo: inputBar.bottomAnchor, constant: -8),

            // Send button
            sendButton.leadingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        let keyboardHeight = view.frame.maxY - endFrame.minY
        let safeBottom = view.safeAreaInsets.bottom
        let offset = max(keyboardHeight - safeBottom, 0)

        inputBarBottomConstraint.constant = -offset

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16),
            animations: { self.view.layoutIfNeeded() }
        )

        // Scroll to bottom when keyboard appears
        if keyboardHeight > 0 {
            scrollToBottom(animated: true)
        }
    }

    // MARK: - Send Message

    @objc private func sendTapped() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        inputField.text = ""
        send(text)
    }

    private func send(_ text: String) {
        guard !isSending else { return }

        // 1. Append user message
        let userMessage = ChatMessage.user(text)
        appendMessage(userMessage)

        // 2. Append loading placeholder
        let loadingMessage = ChatMessage.loading()
        appendMessage(loadingMessage)

        // 3. Disable input while waiting
        setSendingState(true)

        // 4. Check if this is a weather query — handle locally without LLM
        if let city = extractWeatherCity(from: text) {
            fetchWeather(city: city)
            return
        }

        // 5. Check if this is a GitHub Trending query
        if isGitHubTrendingIntent(text) {
            fetchGitHubTrending()
            return
        }

        // 6. Call LLM via framework pipeline (extract + fix + decode + validate + retry)
        Task { [weak self] in
            guard let self else { return }

            do {
                let document = try await self.llmService.generate(message: text)
                await MainActor.run {
                    let content = self.buildMessage(from: document)
                    self.replaceLastMessage(with: content)
                    self.setSendingState(false)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage.assistantText("请求失败：\(error.localizedDescription)")
                    self.replaceLastMessage(with: errorMessage)
                    self.setSendingState(false)
                }
            }
        }
    }

    // MARK: - Response Parsing

    /// Converts a RenderResult into a ChatMessage. Must be called on the main thread.
    private func chatMessage(from result: GenerativeUIRuntime.RenderResult, fallbackText: String) -> ChatMessage {
        switch result {
        case .view(let renderer):
            return ChatMessage.assistantView(renderer)
        case .screen, .failure:
            return ChatMessage.assistantText(fallbackText)
        }
    }

    /// Builds a ChatMessage from a decoded document. Must be called on the main thread.
    private func buildMessage(from document: GenerativeUIDocument) -> ChatMessage {
        let result = runtime.build(from: document) { [weak self] envelope in
            DispatchQueue.main.async { self?.handleEvent(envelope) }
        }
        return chatMessage(from: result, fallbackText: "生成的 UI 类型不支持在聊天中展示")
    }

    /// Builds a ChatMessage from a raw JSON string (used by weather/github local services).
    /// Must be called on the main thread.
    private func buildMessage(from jsonString: String) -> ChatMessage {
        let result = runtime.build(from: jsonString) { [weak self] envelope in
            DispatchQueue.main.async { self?.handleEvent(envelope) }
        }
        return chatMessage(from: result, fallbackText: jsonString)
    }

    // MARK: - Weather

    /// Extracts a city name from weather queries like "上海天气", "深圳的天气", "Tokyo weather".
    /// Returns nil if the input is not a weather query.
    private func extractWeatherCity(from text: String) -> String? {
        let patterns = [
            "([\\u{4e00}-\\u{9fa5}a-zA-Z\\u{00B7}]+)的?天气",
            "([a-zA-Z\\s]+?)\\s*weather"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let city = String(text[range]).trimmingCharacters(in: .whitespaces)
            if !city.isEmpty { return city }
        }
        return nil
    }

    /// Fetches real-time weather data and renders it as a ViewSpec card.
    private func fetchWeather(city: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await self.weatherService.fetch(city: city)
                let jsonString = self.weatherService.buildSpec(from: data)
                guard !jsonString.isEmpty else { throw WeatherError.parseFailed }
                await MainActor.run {
                    let message = self.buildMessage(from: jsonString)
                    self.replaceLastMessage(with: message)
                    self.setSendingState(false)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage.assistantText("获取天气失败：\(error.localizedDescription)")
                    self.replaceLastMessage(with: errorMessage)
                    self.setSendingState(false)
                }
            }
        }
    }

    // MARK: - GitHub Trending

    /// Returns true if the input looks like a GitHub trending query.
    private func isGitHubTrendingIntent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let keywords = ["github trending", "热门仓库", "热门项目",
                        "github 热门", "github热门", "trending repos", "github 排名", "github排名"]
        return keywords.contains(where: { lowered.contains($0) })
    }

    /// Fetches GitHub trending repos (week + month) and renders as a tabbed ViewSpec card.
    private func fetchGitHubTrending() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let jsonString = try await self.githubTrendingService.fetchAndBuildSpec()
                guard !jsonString.isEmpty, jsonString != "{}" else {
                    throw GitHubTrendingError.decodingFailed
                }
                await MainActor.run {
                    let message = self.buildMessage(from: jsonString)
                    self.replaceLastMessage(with: message)
                    self.setSendingState(false)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage.assistantText("获取 GitHub 热门仓库失败：\(error.localizedDescription)")
                    self.replaceLastMessage(with: errorMessage)
                    self.setSendingState(false)
                }
            }
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ envelope: InteractionEnvelope) {
        print("--- Chat Event ---")
        print("Type: \(envelope.eventType.rawValue)")
        print("Component: \(envelope.componentId)")
        if let actionId = envelope.actionId {
            print("Action: \(actionId)")
        }
        if let binding = envelope.binding, let value = envelope.value {
            print("Binding: \(binding) = \(value)")
        }
        print("State: \(envelope.state)")
        print("------------------")

        if envelope.eventType == .valueChanged {
            // Interactive cards are embedded in auto-sized table cells.
            // When inner content changes, force the table view to recalculate
            // the bubble height immediately instead of waiting for a later
            // global relayout such as device rotation.
            tableView.beginUpdates()
            tableView.endUpdates()
        }

        if envelope.eventType == .actionTriggered, let actionId = envelope.actionId {
            let stateDesc = envelope.state.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            showAlert(title: "动作触发", message: "action: \(actionId)\nstate: \(stateDesc)")
        }
    }

    // MARK: - Message List Management

    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.performBatchUpdates {
            tableView.insertRows(at: [indexPath], with: .fade)
        } completion: { [weak self] _ in
            self?.scrollToBottom(animated: true)
        }
    }

    /// Replaces the last message (typically the loading placeholder) with actual content.
    private func replaceLastMessage(with message: ChatMessage) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1] = message
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.performBatchUpdates {
            tableView.reloadRows(at: [indexPath], with: .fade)
        } completion: { [weak self] _ in
            self?.scrollToBottom(animated: true)
        }
    }

    private func scrollToBottom(animated: Bool) {
        let rowCount = tableView.numberOfRows(inSection: 0)
        guard rowCount > 0 else { return }
        let indexPath = IndexPath(row: rowCount - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    private func setSendingState(_ sending: Bool) {
        isSending = sending
        inputField.isEnabled = !sending
        sendButton.isEnabled = !sending
        suggestionsCollectionView.isUserInteractionEnabled = !sending
        suggestionsCollectionView.alpha = sending ? 0.5 : 1.0
    }

    // MARK: - Utility

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ChatBubbleCell.reuseIdentifier,
            for: indexPath
        ) as! ChatBubbleCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {}

// MARK: - UITextFieldDelegate

extension ChatViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

// MARK: - UICollectionViewDataSource

extension ChatViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        suggestions.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SuggestionChipCell.reuseIdentifier,
            for: indexPath
        ) as! SuggestionChipCell
        cell.configure(with: suggestions[indexPath.item].displayText)
        return cell
    }
}

// MARK: - UICollectionViewDelegate & FlowLayout

extension ChatViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isSending else { return }
        let prompt = suggestions[indexPath.item].promptText
        inputField.text = ""
        send(prompt)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = suggestions[indexPath.item].displayText
        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let horizontalPadding: CGFloat = 32 // 16pt each side
        return CGSize(width: ceil(textWidth + horizontalPadding), height: 36)
    }
}

// MARK: - SuggestionChipCell

private final class SuggestionChipCell: UICollectionViewCell {

    static let reuseIdentifier = "SuggestionChipCell"

    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .label
        l.textAlignment = .center
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .systemGray6
        contentView.layer.cornerRadius = 18
        contentView.layer.masksToBounds = true

        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with text: String) {
        label.text = text
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? .systemGray5 : .systemGray6
        }
    }
}
