# 更新日志

本项目按 `VERSIONING.md` 维护版本。每个版本必须说明版本定位、相较上一版的变化、迁移或兼容性影响、验证结果和发布产物状态。

## v0.5.0 - 2026-04-30

版本定位：设备 Token 快速接入与简单 MQTT 控制版本。

相较 `v0.4.0`：这一版把默认接入流程从高级应用鉴权调整为设备 Token 快速接入，用户一次选择 `Token.log` 和 OneNET TSL JSON 后即可生成连接配置、导入物模型并通过 MQTT 收发属性；高级项目分组/用户鉴权仍保留在配置页用于 OpenAPI、历史数据和不占用设备身份的场景。

新增：

- 设备页新增“一键导入 Token.log + 物模型 JSON”流程，同时解析连接身份和物模型属性。
- 新增设备 Token 鉴权生成，支持使用 `DeviceKey` 自动续期 Token，也支持复用未过期的导入 Token。
- MQTT 服务新增设备 Token 身份连接参数、属性设置订阅、属性设置消息解析和属性发布。
- 简单模式下控制下发改走 MQTT property post，高级应用接入继续使用 OneNET OpenAPI。
- 配置状态卡展示接入模式、Product ID、Device Name、Token 有效期和物模型属性数量。
- 新增连接文件导入、产品 ID 校验、设备 Token 鉴权、MQTT 凭据生成和 Token.log 解析测试。

变更：

- 默认鉴权模式改为设备 Token；高级项目分组/用户鉴权折叠到“高级应用接入”中。
- Token.log 解析支持英文冒号、中文冒号、Token-only 日志和常见乱码冒号输出。
- 物模型导入会读取 `profile.productId`，并与 Token.log 的 Product ID 做一致性校验。
- 简单模式不再调用 OneNET OpenAPI；刷新和历史数据优先使用本地 MQTT 缓存。
- README 更新为设备 Token 快速接入说明，并保留高级应用接入边界说明。

兼容性与迁移：

- 本地数据库 schema 从 `2` 升级到 `3`，为 `project_config` 增加 `device_token_method`、`device_token_version` 和 `device_token_expires_at`。
- `DeviceKey` 和导入 Token 使用安全存储保存，不写入普通数据库字段。
- 备份导出 schema 标记升级到 `3`；包含密钥导出时会带出设备 Token 相关密钥字段。
- 简单设备 Token 模式可能占用同一设备 MQTT 在线身份；需要避免占用真实设备会话或需要云端历史查询时，应启用高级应用接入。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.5.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.5.0)
- 与上一版对比：[v0.4.0...v0.5.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.4.0...v0.5.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.5.0-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.5.0-signed.apk`

## v0.4.0 - 2026-04-30

版本定位：物模型重置与本地数据清理版本。

相较 `v0.3.1`：这一版新增物模型删除流程，让用户可以在保留云平台配置和日志的前提下，清空当前设备物模型、面板配置和本地历史数据，便于切换设备或重新导入物模型。

新增：

- 物模型页新增“删除物模型”操作。
- 删除前弹窗确认，明确说明会删除物模型、面板配置和本地历史数据，并断开实时连接。
- 控制器新增 `clearThingModel()`，统一停止轮询、断开 MQTT、清理仓库数据并刷新状态。
- 仓库新增 `clearThingModel()`，事务性清空 `thing_properties`、`dashboard_widgets`、`dashboard_pages` 和 `runtime_values`。
- 新增控制器测试，覆盖删除物模型后状态清空、历史数据清理、MQTT 断开和轮询停止。

变更：

- 物模型页会在已有物模型、面板、控件或本地值时启用删除入口。
- 删除物模型时保留项目配置和应用日志。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 删除操作是破坏性本地操作，但只影响本地物模型、面板和历史缓存，不删除 OneNET 云端设备或项目配置。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.4.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.4.0)
- 与上一版对比：[v0.3.1...v0.4.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.3.1...v0.4.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.4.0-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.4.0-signed.apk`

## v0.3.1 - 2026-04-30

版本定位：Android 签名发布补丁版。

相较 `v0.3.0`：这一版不改变 App 功能，重点补齐 Android release signing 配置，使 Release 可以附带经过 `apksigner verify` 验证的 APK。

新增：

- Android release 构建读取本机 `android/key.properties` 和 keystore。
- Release 构建缺少签名配置时会直接失败，避免误产出未签名 APK。
- `.gitignore` 明确屏蔽 `android/key.properties`、`.jks` 和 `.keystore`，避免签名密钥入库。

变更：

- README 的 APK 构建说明改为签名配置说明。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 构建 Release APK 前，本机必须存在 `android/key.properties` 和对应 keystore。
- 签名文件仅用于本地打包，不纳入 Git 仓库。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.3.1](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.3.1)
- 与上一版对比：[v0.3.0...v0.3.1](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.3.0...v0.3.1)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.3.1-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.3.1-signed.apk`

## v0.3.0 - 2026-04-29

版本定位：连接稳定性、备份恢复和本地数据维护版本。

相较 `v0.2.0`：这一版在可编辑仪表盘基础上补强运行可靠性，增加配置备份导入，切换 OneNET MQTT 到 TLS 连接，并加入运行数据/日志保留策略。

新增：

- 支持导入配置备份 JSON，可恢复项目配置、物模型、面板页面和控件配置。
- 新增备份文件时间戳命名，避免多次导出互相覆盖。
- 新增运行数据保留策略，根据历史天数清理过旧 runtime values，最低保留 30 天。
- 新增日志数量上限，自动保留最近 1000 条日志。
- 新增控制器级测试，覆盖物模型导入生成面板、控制下发和实时连接状态。
- 新增时间格式化和仪表盘布局常量，减少重复格式化与硬编码布局值。

变更：

- OneNET MQTT 从明文 IP/端口切换到 `studio-mqtt.heclouds.com:8883` TLS 连接。
- Android Manifest 移除 `usesCleartextTraffic`，默认不允许明文网络流量。
- 初始设备状态改为离线，只有连接或生命周期消息确认后再更新。
- 趋势图历史数据加载改为 stateful future，避免频繁 rebuild 时重复拉取历史数据。
- 滑块控制在设备离线时禁用结束回调，控制完成后清理草稿值。
- Token.log、物模型和备份导入统一处理 `file_picker` 的内存/路径读取。
- OneNET AccessKey 非 Base64 时返回更明确的错误提示。
- 物模型导入只把枚举 specs 解析为枚举值，字符串长度等 specs 不再误入枚举表。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 备份导入支持当前 schema 2 数据；导入时会保留已有安全存储中的 AccessKey，除非备份文件显式包含 `access_key`。
- MQTT 连接依赖设备网络可访问 OneNET Studio TLS 地址与 8883 端口。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。

发布产物：

- GitHub Release：[v0.3.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.3.0)
- 与上一版对比：[v0.2.0...v0.3.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.2.0...v0.3.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.3.0-unsigned.apk`
- 未附带 APK 到 GitHub Release，因为 Android release signing 尚未配置，未签名 APK 不作为正式 Release 附件发布。

## v0.2.0 - 2026-04-29

版本定位：仪表盘自定义能力版本。

相较 `v0.1.0`：这一版从“自动生成默认面板”升级为“可编辑 UI 卡片系统”，用户可以调整控件展示方式、图标、颜色、尺寸和数据显示格式。

新增：

- 可编辑仪表盘 UI 卡片，支持显示模式、尺寸、颜色、单位显示、小数位和图标设置。
- 内置 IoT PNG 图标库，覆盖温度、湿度、光照、烟雾、距离、开关、继电器、电机和默认设备。
- 支持上传 PNG 作为单个控件图标。
- 新增 `dashboard_widgets` schema v2，用于保存显示模式、图标、颜色和格式化设置。
- 新增仪表盘配置测试，覆盖旧字段回填、显示模式兼容性和默认控件补齐逻辑。

变更：

- 导入物模型后会补齐缺失的默认 UI 卡片和数值趋势图，不再覆盖用户已有布局。
- 移除内置“毕设模板”快捷入口，改为要求导入真实 OneNET Studio TSL JSON。
- 调整物模型导入乱码提示和异常文案。

兼容性与迁移：

- 本地数据库版本从 `1` 升到 `2`。
- 旧版 `dashboard_widgets` 会在升级时自动补齐新字段。
- 旧版控件类型会映射到新版 `DashboardDisplayMode`。

验证：

- `flutter test` 通过。
- `flutter analyze` 通过。
- `flutter build apk --release` 通过。

发布产物：

- GitHub Release：[v0.2.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.2.0)
- 与上一版对比：[v0.1.0...v0.2.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.1.0...v0.2.0)
- 未附带 APK，因为 Android release signing 尚未配置，未签名 APK 不作为正式 Release 附件发布。

## v0.1.0 - 2026-04-29

版本定位：首个 Android MVP。

相较上一版：首个公开版本，无上一版可比较。

新增：

- Flutter Android MVP，用于把 OneNET Studio 物模型设备接入手机监控控制面板。
- OneNET OpenAPI 集成，支持最新属性查询、历史属性查询和属性设置。
- OneNET 应用 MQTT 长连接集成，支持生命周期、属性上报、事件上报和属性设置响应。
- 项目分组/用户鉴权配置，本地保存，`AccessKey` 使用安全存储。
- Token.log 解析，用于识别 `Product ID` 和 `Device Name`。
- OneNET TSL JSON 导入，用于生成属性模型和默认面板。
- 默认监控控制面板，包含数值卡、开关、滑块、枚举选择和趋势图。

验证：

- `flutter test` 通过。

发布产物：

- GitHub Release：[v0.1.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.1.0)
- 未附带 APK，因为 Android release signing 尚未配置，未签名 APK 不作为正式 Release 附件发布。
