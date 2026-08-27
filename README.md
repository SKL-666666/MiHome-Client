# 鸿米家（miha）

基于 HarmonyOS NEXT 原生 ArkTS / ArkUI 开发的小米家庭 / 米家（MIoT）控制应用。目标是在手机、平板、2in1 与穿戴设备上，通过小米云 / 米家 API 管理家庭、房间与设备，并尽可能打通局域网与 MQTT 通道。

> 当前版本：1.0.7（bundleName `com.miha.harmony`）

## 功能特性

- **米家扫码登录**：基于 `serviceLogin` 的二维码登录流程，长期轮询票据，自动组装授权数据。
- **家庭 / 房间 / 设备管理**：拉取家庭列表、房间与设备数据，支持设备在线 / 缓存 / 离线状态区分。
- **动态设备控制**：按 MIoT-Spec V2 实例解析设备能力，动态生成属性与动作控件，无需为每个设备型号写死 UI；支持带参数的 action 输入。
- **设备能力翻译**：服务类型与设备能力显示名翻译，覆盖常见米家设备类型。
- **局域网发现**：基于 mDNS 发现 `_miot-central._tcp.local.` 的 MIPS 服务。
- **LAN 传输层**：`LanCrypto`（AES-CBC / MD5 / PKCS7 / 报文分帧）+ UDP Socket + `LanDeviceTransport`，为局域网直连控制做准备。
- **MQTT 抽象**：状态机、订阅管理，保留私有服务器 / 证书参数接入位。
- **通知与后台能力**：通过 `DeviceEventBus` 驱动原生通知；仅声明系统允许的后台通知能力。
- **外观设置**：自定义背景（含裁切）与字体管理，全局沉浸光感开关。
- **备份与恢复**：导出为 ZIP 压缩包，可选附带自定义背景与字体，恢复时同步还原资源，并按设备比对过滤不适用设置项。
- **反馈与日志**：完整日志模式，导出日志时对 Token、密钥等敏感参数脱敏；支持教程与选择保存位置。
- **悬浮底栏与主页优化**：主页平滑切换、隐藏离线设备实时生效、音箱播放 / 麦克风控制与音量阶梯调节。

## 页面一览

| 页面 | 说明 |
| --- | --- |
| LoginPage | 米家二维码登录 |
| FamilySelectPage | 家庭选择 |
| HomePage / RoomsPage | 家庭概览与房间设备列表 |
| DeviceDetailPage | 设备详情，按 MIoT-Spec 动态渲染属性 / 动作控件 |
| SettingsPage | 设置入口 |
| AppearanceSettingsPage / BackgroundCropPage / FontManagePage | 外观、背景裁切、字体管理 |
| BackupRestorePage | 备份导出 / 恢复 |
| FeedbackPage | 反馈与日志导出 |
| AboutPage / AboutDevicePage | 关于应用与设备信息 |

## 项目结构

```text
.
├── AppScope/                 # 应用级配置（bundleName、图标、版本）
├── entry/                    # entry 模块
│   └── src/main/ets/
│       ├── entryability/     # EntryAbility、深链（xiaomihome://oauth）
│       ├── pages/            # 页面
│       ├── components/       # 可复用组件
│       ├── models/           # 家庭 / 房间 / 设备 / MIoT-Spec 模型
│       ├── repositories/     # 数据仓库与缓存
│       ├── services/         # OAuth、数据、通知、备份恢复、反馈日志
│       ├── cloud/            # XiaomiCloudClient、MijiaApiClient、Spec 解析
│       ├── oauth/            # OAuth / 米家扫码登录
│       ├── lan/              # mDNS 发现、UDP、LAN 加密与传输
│       ├── mqtt/             # MQTT 客户端抽象
│       ├── network/          # HTTP 客户端
│       ├── storage/          # 安全存储与本地缓存
│       ├── events/           # DeviceEventBus
│       ├── controllers/      # DeviceController 等控制层
│       ├── utils/            # 工具函数
│       └── generated/        # 生成代码
├── build-profile.json5       # SDK 版本、产品配置（签名需自行配置）
├── hvigor/                   # hvigor 构建配置
├── oh-package.json5          # 工程依赖
├── .gitignore
├── LICENSE                   # GPL v3
└── README.md
```

## 技术要点

- **框架**：HarmonyOS NEXT，ArkTS + ArkUI 声明式开发。
- **SDK**：compileSdkVersion / targetSdkVersion 26.0.0，compatibleSdkVersion 6.1.1(24)。
- **设备形态**：phone、tablet、2in1、wearable。
- **数据流**：`Repository / Service` → `DeviceController` → 多 Transport（Cloud / LAN / MQTT）→ `DeviceEventBus` 分发属性变化、上下线、动作结果与错误。
- **能力渲染**：`CapabilityRenderer` 将 MIoT-Spec 描述转换为控件描述，避免硬编码设备型号。
- **缓存**：`JsonCache` 等本地缓存区分 online / cached / stale 状态。
- **安全**：Token 等敏感信息使用系统安全存储；日志导出对敏感参数脱敏。

## 环境要求

- DevEco Studio（含 HarmonyOS SDK，建议 6.x / API 26）。
- 可选的命令行构建需要 `DEVECO_SDK_HOME` 指向 DevEco Studio 的 SDK 目录。

## 构建

> 仓库不包含签名配置。首次构建请在 DevEco Studio 中通过
> `File > Project Structure > Signing Configs` 生成并配置你的签名，否则只能产出未签名 HAP。

### 方式一：DevEco Studio

用 DevEco Studio 打开本项目根目录，同步工程后选择 `entry` 模块构建 HAP。

### 方式二：命令行 hvigor

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap
```

产物路径：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
entry/build/default/outputs/default/entry-default-signed.hap   # 配置签名后
```

## 测试

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p product=default -p module=entry@default -p buildMode=debug test
```

单元测试使用 `@ohos/hypium` 与 `@ohos/hamock`。

## 权限说明

应用声明了以下权限：

- `ohos.permission.INTERNET`：访问小米云 / 米家 API。
- `ohos.permission.STORE_PERSISTENT_DATA`：持久化存储。

## 已知限制与验证状态

- 米家扫码登录与云 API 路径基于公开的 `Do1e/mijia-api` 仓库实现，算法与端点已落地，但**尚未使用真实账号 / 真实设备响应做过端到端校准**。
- LAN 加密控制（AES / MD5 分组、token/key/iv 派生）与 UDP 协议需要真实设备 token 联调。
- MQTT 事件订阅需要 MIPS 服务地址、端口与证书流程。
- HarmonyOS NEXT 不提供违规的常驻后台通道，后台能力仅限系统允许的原生通知。

## 合规说明

本项目为 **clean-room 独立实现**：本仓库不包含上游源码。实现仅基于公开的协议事实与公开仓库（如 `XiaoMi/ha_xiaomi_home`）记录的 API 信息编写，未复制上游代码。上游许可证对将 Licensed Work 用于开发 App / Web 服务等场景有限制，请在使用、分发前自行确认相关授权。

## 免责声明

本项目仅用于学习与技术研究。使用本项目访问小米云 / 米家服务前，请确保遵守小米相关服务条款，并对由此产生的账号、设备与数据安全风险自行负责。

## 许可证

Copyright (C) 2026 鸿米家（miha）项目开发者

本项目基于 **GNU General Public License v3.0（GPL v3）** 发布。

你可以自由地使用、复制、修改与分发本项目，但任何分发或修改后的作品必须同样以 GPL v3 许可，并保留版权声明与本许可文本。GPL v3 不提供任何担保，详见 `LICENSE` 文件。

```text
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
