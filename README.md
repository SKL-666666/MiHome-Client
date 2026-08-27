# 米居 MiJu

一款为 HarmonyOS NEXT 打造的第三方米家客户端。让你在鸿蒙设备上用米家账号扫码登录，管理家庭、房间与设备，直接控制米家生态里的智能硬件。

> 当前版本：1.0.0（versionCode 1000100，bundleName `com.miju.client`）
> 下载安装包请前往 [Releases](https://github.com/SKL-666666/MiHome-Client/releases) 页面。

本项目以 [MrCashmere/miha_hm（鸿米家）](https://github.com/MrCashmere/miha_hm) 为基础进行二次开发，在日常使用中针对体验问题做了大量打磨与重构。感谢原作者的优秀工作。

---

## ✨ 与原版（鸿米家 miha_hm）的不同

 fork 不只是为了换个名字，以下是本项目的实际改动：

### 交互体验

| 改动 | 说明 |
| --- | --- |
| **全页面下拉刷新** | 首页、智能、信息页移除顶部刷新按钮，统一下滑手势刷新。轻划即触发（触发距离从默认 80vp 降到 48vp），并带有"下拉刷新 → 释放立即刷新 → 正在刷新 → 刷新完成"的完整状态提示条 |
| **自动刷新间隔可调** | 设置页新增"自动刷新间隔"选项，默认 30 秒，可选 30 秒 / 1 / 2 / 5 / 10 分钟，持久化保存 |
| **登录二维码自动续期** | 扫码二维码过期后自动静默换码（最多 6 次），页面实时提示"二维码已自动刷新，请重新扫码"，不再需要手动刷新 |
| **开关乐观更新与动效** | 设备开关操作即时反馈、先更新 UI 再等云端确认，配合过渡动效，操控跟手不卡顿 |

### 外观

| 改动 | 说明 |
| --- | --- |
| **自定义背景去蒙版** | 用户设置的背景图直接原样展示，不再叠加半透明白色/黑色蒙版 |
| **全新应用图标与品牌** | 应用更名为"米居"，全新图标，bundleName 调整为 `com.miju.client` |
| **纯净开屏页** | 开屏界面移除图标，仅保留纯色背景（浅色模式纯白、深色模式纯黑） |
| **沉浸光感与翻译统一** | 全局背景沉浸、设备能力翻译文案统一 |

### 修复

- 关于页 / 反馈页 / 家庭选择页顶部标题栏错位（`Stack` 未显式指定 `alignContent` 导致内容居中）的问题
- 多处文字遮挡与显示不全问题
- 调试签名配置，克隆后可直接构建安装

---

## 🧭 功能一览

- **米家扫码登录**：二维码登录 + 自动续期，授权数据自动组装
- **家庭 / 房间 / 设备管理**：在线、缓存、离线状态清晰区分
- **动态设备控制**：基于 MIoT-Spec V2 动态生成控制界面，无需为每个机型适配
- **设备能力中文翻译**：常见米家设备类型与服务能力本地化
- **智能场景**：场景查看与创建
- **自定义外观**：背景图（含裁切）、字体管理、开屏与界面适配
- **备份与恢复**：设置导出为 ZIP，可选附带背景与字体资源
- **反馈与日志**：日志导出自动脱敏 Token 等敏感信息
- **音箱控制**：播放控制、麦克风与音量阶梯调节

## 📲 下载安装

1. 前往 [Releases](https://github.com/SKL-666666/MiHome-Client/releases) 下载最新的 `.hap` 文件
2. 通过以下任一方式安装：
   - `hdc install -r entry-default-signed.hap`
   - 或使用 DevEco Studio / 手机直接安装工具安装

> 应用需要联网访问小米云 / 米家 API，首次使用请使用米家 App 扫码登录。

## 🛠 从源码构建

- 环境要求：DevEco Studio（含 HarmonyOS SDK，建议 6.x / API 26）
- 用 DevEco Studio 打开项目根目录，在 `File > Project Structure > Signing Configs` 配置你自己的签名后构建

命令行构建：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

产物路径：`entry/build/default/outputs/default/entry-default-signed.hap`

## 🙏 致谢

本项目站在下面这些优秀开源项目的肩膀上，感谢：

- **[MrCashmere/miha_hm](https://github.com/MrCashmere/miha_hm)**（鸿米家）—— 本项目的基础。原项目完成了从零到一的 HarmonyOS NEXT 米家客户端实现，米居在其基础上持续迭代。
- **[Do1e/mijia-api](https://github.com/Do1e/mijia-api)** —— 米家云 API 协议的详细公开文档，登录算法与 API 端点均参考其实现。

同时感谢 [XiaoMi/ha_xiaomi_home](https://github.com/XiaoMi/ha_xiaomi_home) 公开的协议细节。

## ⚠️ 免责声明

本项目仅供学习与技术研究使用。使用本项目访问小米云 / 米家服务前，请确保遵守小米相关服务条款；因使用本项目产生的账号、设备与数据安全风险请自行承担。

本项目与小米公司官方无关，米家及相关名称版权归其各自所有者所有。

## 📄 许可证

本项目基于原项目 [MrCashmere/miha_hm](https://github.com/MrCashmere/miha_hm) 修改，依原项目许可继续以 **GNU General Public License v3.0（GPL v3）** 发布。

你可以自由使用、修改与分发本项目，但分发时必须同样以 GPL v3 许可并保留版权声明，详见 `LICENSE` 文件。
