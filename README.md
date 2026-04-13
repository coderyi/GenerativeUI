# GenerativeUI


GenerativeUI 是一个面向 iOS 的生成式 UI 运行时。它把一段 JSON UI 描述，或LLM生成后的 UI 描述，解码、校验并渲染为原生界面，同时把用户输入、按钮点击等交互以约定的事件结构回传给宿主 App。

这个项目适合用在聊天式界面、AI 助手、动态运营卡片、表单补全、轻量工作流等场景：服务端或 LLM 决定“展示什么”，客户端负责渲染和接收交互。

## 特性

- 原生 UIKit 渲染：支持整页 `screen` 和可嵌入的 `view`
- Schema 校验：在渲染前检查版本、组件类型、必填属性、绑定状态等
- 状态与事件：输入变化和动作触发会生成 `InteractionEnvelope`
- LLM 无关：通过 `LLMProvider` 接入不同模型服务或你自己的后端
- 内置常用展示、输入、布局和容器组件，可通过注册表继续扩展

## 环境要求

- iOS 15.0+
- Swift 5
- UIKit
- CocoaPods

## 安装

在 `Podfile` 中添加：

```ruby
pod 'GenerativeUI'
```

然后执行：

```bash
pod install
```

## 快速开始

### 1. 准备一段 UI JSON

```json
{
  "schemaVersion": "0.1",
  "view": {
    "id": "hello_card",
    "components": [
      {
        "id": "title",
        "type": "text",
        "props": {
          "text": "Hello GenerativeUI",
          "style": "headline"
        }
      },
      {
        "id": "confirm",
        "type": "button",
        "props": {
          "label": "确定",
          "style": "primary"
        },
        "action": {
          "id": "demo.confirm"
        }
      }
    ]
  }
}
```

顶层内容可以是：

- `screen`：页面级 UI，会渲染为 `UIViewController`
- `view`：局部 UI，会渲染为可嵌入的 `GenerativeViewRenderer`

### 2. 渲染并处理事件

```swift
import GenerativeUI

let runtime = GenerativeUIRuntime()

let result = runtime.build(from: jsonString) { envelope in
    switch envelope.eventType {
    case .valueChanged:
        print("state changed:", envelope.state)
    case .actionTriggered:
        print("action:", envelope.actionId ?? "")
    }
}

switch result {
case .screen(let viewController):
    navigationController?.pushViewController(viewController, animated: true)

case .view(let renderer):
    renderer.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(renderer)
    NSLayoutConstraint.activate([
        renderer.topAnchor.constraint(equalTo: containerView.topAnchor),
        renderer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        renderer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        renderer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])

case .failure(let fallbackViewController):
    present(fallbackViewController, animated: true)
}
```

`InteractionEnvelope` 会携带事件来源、动作或状态信息，宿主 App 可以据此发起请求、导航、弹窗或执行后续流程。

## 接入LLM

GenerativeUI 不直接依赖特定 LLM SDK。接入模型服务时，通常需要实现 `LLMProvider`，把框架传入的消息转发给自己的模型服务，并返回模型输出的文本。

```swift
import GenerativeUI

struct MyLLMProvider: LLMProvider {
    func sendMessages(_ messages: [LLMMessage]) async throws -> String {
        // 在这里调用模型服务或你自己的后端服务。
        // 返回文本应包含符合 GenerativeUI schema 的 JSON。
        return "..."
    }
}

let provider = MyLLMProvider()
let systemPrompt = "请参考 Example 中的 ChatSystemPrompt，提供足够明确的 schema 约束。"
let service = GenerativeUILLMService(
    provider: provider,
    systemPrompt: systemPrompt
)

runtime.generateAndRender(
    service: service,
    message: "生成一个酒店预订表单",
    onEvent: { envelope in
        print(envelope)
    },
    completion: { result in
        // 与 runtime.build 的 RenderResult 处理方式一致
    }
)
```

`GenerativeUILLMService` 会完成：调用模型、提取 JSON、修正常见格式问题、解码、校验，并在失败时按策略重试。系统提示词由宿主 App 提供，示例工程中的 `ChatSystemPrompt` 可以作为参考。

## Schema 简介

当前支持的 schema 版本是 `0.1`。在该版本中，一份文档包含 `screen` 或 `view` 其中之一。

```json
{
  "schemaVersion": "0.1",
  "view": {
    "id": "example",
    "components": [
      {
        "id": "title",
        "type": "text",
        "props": {
          "text": "示例内容"
        }
      }
    ]
  }
}
```

核心规则：

- 每个组件需要唯一 `id`
- 交互组件通过 `binding` 读写 `state`
- 动作组件通过 `action.id` 把操作交给宿主 App
- 容器组件可以包含子组件，适合组合复杂布局

## 示例工程

仓库包含一个 Example App，演示了本地 JSON 渲染、嵌入式卡片、Sheet 展示和聊天式生成 UI。

```bash
cd Example
pod install
open GenerativeUI.xcworkspace
```

本地 JSON 演示不依赖模型服务。部分示例会访问网络。聊天式生成 UI 需要你配置自己的模型 API Key 和 `LLMProvider`，请不要把真实密钥提交到公开仓库。



## License

GenerativeUI 使用 MIT License。详见 [LICENSE](LICENSE)。
