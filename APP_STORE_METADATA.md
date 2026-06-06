# 《楞严》App Store 上架元数据与说明 (App Store Metadata & Descriptions)

> 本文档整理了《楞严》App 上架 App Store Connect 时所需的全部文字内容，采用苹果一贯倡导的“故事化”与“极简审美”风格编写。

---

## 1. 核心属性 (Core Metadata)

### 🏷️ 应用名称 (App Name)
- **中文（简体/繁体）**：`楞嚴` 或 `楞嚴 - 禪意純淨經文閱讀`
- **English**：`LengYan - Zen Scripture Reader`
- *注：建议使用简体/繁体各建本地化，中文名称尽量简练，以凸显端庄。*

### ✍️ 副标题 (Subtitle)
- **限30个字符，重点传达应用的核心调性。**
- **中文**：`無縫長卷，科判法脈` 或 `極简古籍排版与禪意閱讀`
- **English**：`Distraction-Free Zen Reader`

### 📢 宣传文本 (Promotional Text)
- **限170个字符，展示在 App Store 详情页顶部，随时可更新。**
- **中文**：`摒弃一切尘杂，还佛法一份纯净，还您一份安宁。完全本地运行，无广告，无隐私追踪。`
- **English**：`A pure, serene, and local-first scripture reading experience. Zero ads, zero tracking.`

---

## 2. 详细描述 (App Store Description)

*限 4000 字符。建议直接复制下方内容：*

### 中文版本 (Chinese Version)
```
【极简、情感共鸣、隐形技术。】

《楞嚴經》——大乘佛教之精髓，破妄显真之大慧。

《楞严》是一款专为经文阅读与禅修设计的 iOS 原生应用。我们摒弃了所有现代应用的浮躁与嘈杂，不推特，不收集隐私，以苹果级的极简主义与禅宗设计哲学，为您在屏幕中铺开一张安宁的“古籍宣纸”。

【核心设计特征】

🎋 宣纸美学排版
我们为经文量身定制了古典宣纸排版体系。字体大小比例采用黄金分割率，字距与行高经过多轮眼部疲劳测试，在昼夜交替间，给双眼最温柔的呵护。

🧬 纲举目张的科判系统
不同于传统的流水账式阅读，本应用独家支持结构化科判导航。您可以轻松理清章句法脉，从宏观结构到微观字词，了然于胸。

🕊️ 完全纯净，无广告，零隐私收集
本应用不包含任何第三方统计或广告 SDK，完全在本地沙盒运行。您的阅读进度、书签和偏好仅属于您自己，绝不上传云端，给修行留下一片绝对的私密净土。

🎨 零摩擦分享卡片
当您对某句经文心有所感时，可一键将其渲染为极简字画风格的分享卡片，传递法喜，润物无声。

【写在最后】
出家如初，成佛有余。我们以“报恩”的心态打磨这款小而美的应用，愿它能成为您修行路上的一位默契同修。
```

### English Version
```
【Simplicity, resonance, and invisible technology.】

"LengYan" (The Shurangama Sutra) is a premier iOS native application designed for deep scripture reading and Zen meditation. We reject the clutter and noise of modern apps—no accounts, no notifications, and no tracking. We present to you a serene, digital "Xuan Paper" to cultivate your mind.

【Key Design Features】

🎋 Traditional Typography & Aesthetics
Specially tuned spacing, line heights, and margins optimize Chinese character readability. Designed to resemble ancient scriptures, the layout offers a breathable and peaceful reading interface.

🧬 Structured Hierarchy (Sectional Outlines)
Navigate easily using the traditional structured keti (outlines). Instantly grasp the logical flow of the entire scripture from macro themes down to specific paragraphs.

🕊️ 100% Privacy & Local-first
No analytics, no ads, and no tracking SDKs. Your bookmarks and reading states remain strictly in your local sandbox. 

🎨 Zen Cards for Sharing
Render any inspiring passage into an elegant, calligraphic picture card in one click to share the dharma joy.

Wishing you peace and wisdom on your spiritual journey.
```

---

## 3. 搜索关键词 (Keywords)

*限 100 字符，用英文逗号分隔。好的关键词能大幅提升曝光。*

- **中文（简体）**：`楞严经,大佛顶首楞严经,佛经,阅读,禅修,听经,静心,佛教,金刚经,心经,科判,经典,古籍,修心`
- **中文（繁體）**：`楞嚴經,大佛頂首楞嚴經,佛經,閱讀,禪修,聽經,靜心,佛教,金剛經,心經,科判,經典,古籍,修心`
- **English**：`sutra,buddhism,meditation,zen,shurangama,reader,chinese classic,mindfulness,peace,scripture`

---

## 4. 新版本说明 (What's New in This Version)

*用于 v1.0.0 首次发布的描述。*

- **中文**：`1.0.0 首次发布。提供纯净的宣纸排版经文阅读、科判导读、音频播放与一键禅意卡片分享。`
- **English**：`1.0.0 initial release. Featuring elegant traditional layout, outline navigation, audio player, and zen card sharing.`

---

## 5. App Store 截图设计规范 (Screenshots Guide)

为了让截图的视觉品质完美契合 App 的禅意理念，建议遵循以下制作标准：

### 📱 尺寸要求
- **iPhone (6.7" / 6.5")**：对应 iPhone 15/16 Pro Max 尺寸，分辨率 `1290 x 2796`。
- **iPad (12.9" / 13.0")**：对应 iPad Pro 12.9 英寸，分辨率 `2048 x 2732` 或 `2064 x 2752`。

### 🎨 画面构成与配色
- **底色**：使用本应用的特调色——宣纸暖白 (`SutraDesignTokens.shared.color(for: .background)`) 或深黑。
- **文字**：直接在截图上方或下方使用 **Outfit** 或 **Inter** 字体写上极简的说明性文字，颜色使用 `textSecondary`。
- **画面**：可以直接在模拟器上使用以下命令获取高清无外壳截图，然后用设计工具（如 Sketch/Figma）稍作编排：
  ```bash
  # 截取当前运行的模拟器屏幕
  xcrun simctl screenshot screenshot1.png
  ```
