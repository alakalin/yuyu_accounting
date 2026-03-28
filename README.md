# 🌿 yuyu_记账 (YuYu Accounting)

一款基于 Flutter 开发的**纯本地、高颜值** Android 记账应用。采用极简跨界的莫兰迪绿 (Morandi Green) 主题设计，数据完全保存在本地 SQLite 数据库中，无需联网，保护您的绝对隐私。

## ✨ 特色功能 (Features)

- **极简美学**: 全局采用恰到好处的莫兰迪绿色调，结合 Material 3 现代设计规范，带给您清晰纯净的视觉体验。
- **丰富的收支选项**: 内置数十种收支分类（餐饮、交通、薪资、理财、娱乐等）并配以直观的精美图标，记账更便捷。
- **数据可视化**: 提供按「今日」、「本月」、「本年」自由切换的绚丽扇形统计图 (Pie Chart)，直观展示开销占比排序与具体金额。
- **一键分享/导出**: 支持将全部历史账单数据导出为标准 `.csv` 表格文件，可通过微信或其他应用轻松分享，满足二次记账管理需求。
- **纯本地保障**: 基于本地 SQLite 数据库架构，零网络延迟、0 广告干扰、更省电、数据归自己掌控。
- **深度定制**: 自定义了属于您的专有图标与名称启动页（`yuyu_记账`）。

## 🛠️ 技术栈 (Tech Stack)

- **UI 框架**: [Flutter](https://flutter.dev/) (Dart) & Material 3
- **状态管理**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`, `riverpod_annotation`)
- **本地数据库**: [sqflite](https://pub.dev/packages/sqflite)
- **图表渲染**: [fl_chart](https://pub.dev/packages/fl_chart)
- **其他关键工具**: `csv`, `share_plus`, `path_provider`, `intl`, `flutter_launcher_icons`

## 🚀 快速运行 (Getting Started)

确保您的电脑已经配置好 Flutter 开发环境（SDK 版本 >= 3.2.0）。

1. 克隆本项目：
   ```bash
   git clone https://github.com/您的用户名/yuyu_accounting.git
   ```
2. 进入项目目录并安装依赖：
   ```bash
   cd "yuyu_accounting"
   flutter pub get
   ```
3. 在设备上运行（推荐使用 Release 模式体验完整性能）：
   ```bash
   flutter run --release
   ```
4. 打包 Android 安装包：
   ```bash
   flutter build apk --release
   # 打包好的文件位于 build/app/outputs/flutter-apk/app-release.apk
   ```

## 🔐 自动记账权限说明
- 自动记账依赖 Android 的“通知读取权限”（Notification Listener）。
- 只有在系统设置中为 `yuyu_记账` 开启通知读取权限后，应用才可自动识别微信/支付宝等支付通知并入账。
- 若未开启该权限，手动记账和导出功能可正常使用，但自动读取不会生效。

## 📸 体验亮点
- 精美的底部导航栏及平滑切换动画。
- 无闪烁且极速的 SegmentedButton 类型筛选。
- 精准的金额保留 2 位小数和动态百分比计算。

## 👤 作者信息
- 作者: alakalin
- GitHub 主页: https://github.com/alakalin
- 项目地址: https://github.com/alakalin/yuyu_accounting

## 💚 赞助支持
如果这个项目对你有帮助，欢迎扫码赞助支持持续开发。

![微信赞助二维码](assets/sponsor_wechat.png)

## 📜 协议 (License)
使用 MIT License 开源。

---
*Built with ❤️ via GitHub Copilot*
