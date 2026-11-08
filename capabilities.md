# CutSzn 能力与配置说明（用户版）

> App：CutSzn ｜ Bundle ID：`com.zzoutuo.CutSzn` ｜ Widget：`com.zzoutuo.CutSzn.widget`
> 开发团队：`JP4TN5PTS3` ｜ 最低系统：iOS 17.0

## 一、需要你手动完成的配置（按顺序）

### 1. Xcode 登录与真机签名（必做）
本地 provisioning profile 尚未包含 App Groups / iCloud / HealthKit 三项能力，因此真机归档前需要：
1. 打开 Xcode → Settings → Accounts，登录你的 Apple ID（Team `JP4TN5PTS3`）。
2. 在 Xcode 中打开 `CutSzn.xcodeproj`，等待自动签名刷新；或在终端执行：
   ```bash
   xcodebuild -project CutSzn.xcodeproj -scheme CutSzn \
     -destination 'generic/platform=iOS' -allowProvisioningUpdates build
   ```
3. 首次成功后，Xcode 会自动在开发者后台注册 App Group、iCloud 容器、HealthKit 能力并重建描述文件。

### 2. CloudKit 容器与 Schema（上线前必做）
- 容器 ID：`iCloud.com.zzoutuo.CutSzn`（已在 entitlements 中声明）。
- 首次带账号签名后容器自动创建。
- 打开 [CloudKit Console](https://icloud.developer.apple.com/dashboard) → 选择该容器 → Schema → 将 Development 环境的记录类型部署到 Production（`AthleteSnapshot`）。
- 不部署也不影响核心功能：Team 页会提示需要登录 iCloud，本地模式照常可用。

### 3. App Store Connect 内购产品（必做）
在 App Store Connect → 你的 App → 订阅 / 内购 中创建以下 5 个产品（与 `price.md` 完全一致）：

| 产品 ID | 类型 | 价格 |
|---|---|---|
| `com.zzoutuo.CutSzn.pro.monthly` | 自动续订订阅（组：CutSzn Pro） | $9.99 / 月 |
| `com.zzoutuo.CutSzn.pro.yearly` | 自动续订订阅（组：CutSzn Pro，7 天免费试用） | $49.99 / 年 |
| `com.zzoutuo.CutSzn.coach.yearly` | 自动续订订阅（组：CutSzn Coach） | $99.99 / 年 |
| `com.zzoutuo.CutSzn.pro.byo.lifetime` | 非消耗型 | $34.99 一次性 |
| `com.zzoutuo.CutSzn.singlecut.pass` | 非续期订阅（30 天） | $14.99 / 30 天 |

> 本地调试已内置 `CutSzn/Resources/CutSzn.storekit`，模拟器可直接购买测试。

### 4. 云端 AI 密钥（可选）
- 当前 AI 路由顺序：Apple 端侧 → 用户自带 Key → 云端配额 → 本地离线回答。
- 若要让「CutSzn Cloud」配额真正可用，把一个代理密钥文件放到 app target 目录：
  `CutSzn/GLMProxySecret.txt`，格式：`密钥|端点|模型`
- 该文件已在 `.gitignore` 中，不会进 Git，也不会打包进 Release（建议在 Xcode 的 Build Phases 中排除）。
- 没有该文件时，云端调用自动跳过，功能降级为端侧 + 自带 Key + 离线回答，不会报错。

### 5. App Store 提审资料（必做）
- 政策页已上线，提交时填写：
  - 隐私政策：https://asunnyboy861.github.io/CutSzn/privacy.html
  - 服务条款：https://asunnyboy861.github.io/CutSzn/terms.html
  - 支持网址：https://asunnyboy861.github.io/CutSzn/support.html
- 年龄分级：12+（医疗/治疗信息，偶发）。
- 隐私标签：健康与健身数据（体重）仅本地使用；不用于追踪；无第三方广告。
- 审核备注可直接复制 `keytext.md` 的 Review Notes 段落。

## 二、已自动完成、无需你操作的配置

| 能力 | 状态 | 说明 |
|---|---|---|
| HealthKit（体重读写） | ✅ 已配置 | entitlements + 隐私用途文案 + Settings 的 HealthKit 区块 + Learn More 页面 |
| iCloud / CloudKit | ✅ 工程内已配置 | 容器、CloudKit 服务、kvstore 已声明；仅需第 2 步后台部署 |
| App Groups | ✅ 已配置 | `group.com.zzoutuo.CutSzn`，App 与 Widget 共享 |
| WidgetKit 锁屏/桌面小组件 | ✅ 已配置 | `CutSznWidget` target，已嵌入 App |
| 相机 / 相册 | ✅ 已配置 | 拍照识餐与相册选图用途文案 |
| Privacy Manifest | ✅ 已配置 | App 与 Widget 各一份，声明无追踪 |
| StoreKit 2 | ✅ 已配置 | 本地 `.storekit` + 购买/恢复/权益刷新 |
| 本地通知 | ✅ 已配置 | 21:00 明日目标提醒 + 赛周 USG 提醒 |
| 出口合规 | ✅ 已配置 | `ITSAppUsesNonExemptEncryption = NO` |
| App 图标 | ✅ 已生成 | 1024×1024、无 alpha、深色底 + 电光绿 |
| GitHub 仓库与 Pages | ✅ 已部署 | 代码与四张页面均已上线 |

## 三、降级行为（保证下载即用）

- HealthKit 未授权 → 只用手动称重，无报错页。
- iCloud 未登录 → 数据全部本地；Team 页显示说明，不阻塞。
- Widget 无快照 → 显示「Open CutSzn to log a weight」。
- AI 全部不可用 → 本地离线教练回答，核心流程 100% 正常。
- StoreKit 不可用 → 免费核心功能不受影响。

## 四、构建验证记录

- iPhone 16（iOS 26.4）模拟器：✅ BUILD SUCCEEDED 并成功启动
- iPad Pro 13-inch（M5）模拟器：✅ BUILD SUCCEEDED
- 真机 generic/platform=iOS：⏳ 待你登录 Xcode 后执行第 1 步命令
