# 更新日志

本项目按 `VERSIONING.md` 维护版本。每个版本必须说明版本定位、相较上一版的变化、迁移或兼容性影响、验证结果和发布产物状态。

## v0.9.1 - 2026-05-03

版本定位：Token.log 文件选择兼容性修复版本。

相较 `v0.9.0`：这一版不改变运行页、历史页和数据结构，重点修复 Android 文档选择器在自定义扩展名过滤下可能隐藏 `.log` 文件的问题。导入 Token.log 时改为允许选择任意文件，再交给现有解析逻辑校验内容。

变更：

- Token.log 导入入口从 `.log/.txt` 自定义过滤改为 `FileType.any`，提升 Android 文件管理器兼容性。
- README 更新为 `v0.9.1`，补充 Token.log 文件选择兼容性说明。

修复：

- 修复部分 Android document provider 不显示 `.log` 文件，导致用户无法选择 Token.log 的问题。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 无备份 schema 版本升级。
- 既有设备配置、物模型和历史数据不受影响。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.9.1](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.9.1)
- 与上一版对比：[v0.9.0...v0.9.1](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.9.0...v0.9.1)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.9.1-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.9.1-signed.apk`

## v0.9.0 - 2026-05-03

版本定位：属性历史页与实时面板交互版本。

相较 `v0.8.1`：这一版把原先由默认面板自动生成的趋势图改为独立的属性历史页。运行页的数据卡片现在可直接点击查看历史，数值属性展示曲线，布尔和枚举属性展示阶梯图，文本属性展示列表；同时会清理本地残留的旧趋势控件并以实时卡片重新组织默认面板。

新增：

- 新增 `PropertyHistoryScreen`，用于按属性查看历史数据。
- 运行页数据卡片新增历史入口，点击即可打开属性历史页。
- 历史页支持数值曲线、布尔/枚举阶梯图和文本列表三种展示方式。
- 新增属性历史页测试，覆盖数值、布尔、枚举、文本和空状态。

变更：

- 默认面板生成逻辑不再自动创建趋势图，只生成实时控制卡。
- 启动时会清理本地旧趋势控件，避免旧布局和新历史页同时存在。
- 物模型页文案和运行页文案更新为“实时卡片 + 独立历史页”的交互方式。
- README 更新为 `v0.9.0`，补充属性历史查看说明。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 无备份 schema 版本升级。
- 旧版 `trendChart` 控件会在初始化时从本地面板中移除，并由实时卡片与独立历史页替代，历史数据本身保留不变。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.9.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.9.0)
- 与上一版对比：[v0.8.1...v0.9.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.8.1...v0.9.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.9.0-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.9.0-signed.apk`

## v0.8.1 - 2026-05-01

版本定位：OneNET MQTT 协议兼容性修复版本。

相较 `v0.8.0`：这一版不改变配置界面和数据结构，重点修复 OneNET MQTT 连接兼容性。MQTT CONNECT 报文现在显式使用 MQTT 3.1.1 协议名和协议版本，避免客户端默认协议版本与 OneNET 服务端要求不一致时连接失败。

新增：

- 新增 MQTT 连接报文测试，覆盖协议名、协议版本、clientId、username 和 password。

变更：

- MQTT 连接报文创建逻辑抽出为 `createConnectionMessage()`，便于测试和后续诊断。
- CONNECT 报文明确定义为 MQTT 3.1.1：协议名 `MQTT`，协议版本 `4`。
- README 更新为 `v0.8.1`，补充 MQTT 3.1.1 兼容性说明。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 无备份 schema 版本升级。
- 既有配置和 `mqtt_use_tls` 设置保持不变。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.8.1](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.8.1)
- 与上一版对比：[v0.8.0...v0.8.1](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.8.0...v0.8.1)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.8.1-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.8.1-signed.apk`

## v0.8.0 - 2026-05-01

版本定位：MQTT 连接端点与 TLS 开关版本。

相较 `v0.7.0`：这一版把简单设备 Token 模式的 MQTT 连接端点从固定 TLS 连接调整为可配置端点，默认使用 OneNET 非加密 MQTT 1883，并提供 SSL/TLS 8883 开关。设备配置、状态卡、连接诊断、数据库和备份导出都同步记录当前端点选择。

新增：

- 设备配置页新增“启用 SSL/TLS 加密”开关，用户可以在非加密 MQTT 与 SSL/TLS MQTT 之间切换。
- OneNET MQTT 服务新增端点解析逻辑，默认连接 `studio-mqtt.heclouds.com:1883`，启用 SSL/TLS 后连接 `studio-mqtts.heclouds.com:8883`。
- 配置状态卡新增 MQTT 端点模式显示，便于确认当前使用 1883 还是 8883。
- 新增项目配置持久化测试，覆盖 `mqtt_use_tls` 默认值、数据库映射和备份导出映射。
- 新增 MQTT 服务端点测试，覆盖默认非加密端点和 SSL/TLS 端点。

变更：

- MQTT 连接创建时会根据项目配置设置 host、port 和 secure 参数。
- 连接失败诊断会显示当前实际访问的 MQTT host/port。
- TLS 握手错误只在已启用 SSL/TLS 时归类为 TLS 连接问题，避免非加密模式下误导排查。
- README 更新为 `v0.8.0`，补充 MQTT 1883/8883 端点说明和配置方式。

兼容性与迁移：

- 本地数据库 schema 从 `3` 升级到 `4`，为 `project_config` 增加 `mqtt_use_tls` 字段。
- 已有配置升级后默认 `mqtt_use_tls = false`，即默认使用非加密 MQTT 1883。
- 备份导出 schema 从 `3` 升级到 `4`，导出时会包含 `mqtt_use_tls`。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.8.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.8.0)
- 与上一版对比：[v0.7.0...v0.8.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.7.0...v0.8.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.8.0-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.8.0-signed.apk`

## v0.7.0 - 2026-05-01

版本定位：仪表盘 SVG 图标库与图标选择体验版本。

相较 `v0.6.0`：这一版补齐可编辑仪表盘的矢量图标能力，新增内置 SVG 图标资源、分类化 Material 图标库和搜索式图标选择器。新生成的默认面板会优先使用 SVG 图标，同时保留旧版 PNG 图标配置的兼容性。

新增：

- 新增 `flutter_svg` 依赖，用于渲染内置 SVG 图标资源。
- 新增 `assets/vector_icons/` 内置 SVG 图标库，覆盖设备、温度、湿度、光照、烟雾、距离、开关、继电器、电机、网关、风扇、水泵、阀门、电池、摄像头和门锁。
- 图标选择器新增搜索框、分类筛选和网格选择体验，Material 图标与内置 SVG 图标均支持分类浏览。
- Material 图标库扩展到环境、设备、网络、电源、状态、工业、数据和操作等场景。
- 默认面板生成逻辑改为使用内置 SVG 图标，并新增电池、摄像头、门锁等属性关键词匹配。
- 新增图标库测试，覆盖图标数量、key 唯一性和 SVG 资源存在性。

变更：

- `DashboardIconKind` 新增 `builtinSvg`，新生成的卡片与趋势图默认使用 SVG 图标。
- 图标来源切换时会自动修正不匹配的图标值，避免从 Material/PNG/SVG 切换后出现空图标。
- README 更新为 SVG 图标库、搜索筛选和图标资源目录说明。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 旧版 `builtinPng` 和 `material` 图标配置继续按名称解析，不受新增 enum 值影响。
- 旧面板不会被强制改写为 SVG；只有新生成或用户手动选择的卡片使用新 SVG 图标。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.7.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.7.0)
- 与上一版对比：[v0.6.0...v0.7.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.6.0...v0.7.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.7.0-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.7.0-signed.apk`

## v0.6.0 - 2026-05-01

版本定位：连接配置体验与错误诊断增强版本。

相较 `v0.5.0`：这一版把设备连接流程从“同时导入 Token.log 与物模型 JSON”调整为“Token.log/手动连接信息”和“物模型 JSON”分开维护。用户可以直接手动填写 `Product ID`、`Device Name`、`Device Key` 或 `Token`，连接失败时 App 会返回明确的出错位置、原因和处理建议。

新增：

- 设备页新增连接方式下拉框，可在简单设备 Token、高级项目分组鉴权和高级用户鉴权之间直接切换。
- 简单设备 Token 模式新增 `Device Key / key` 和 `Token / token` 手动输入框。
- 连接动作会先保存当前表单，再发起 MQTT 连接，避免手动修改后忘记保存。
- 新增连接失败诊断弹窗，覆盖缺失字段、Token 过期、鉴权格式错误、OneNET 拒绝登录、网络连接和 TLS 握手问题。
- 控制器新增 `ConnectionFailureInfo`，让连接失败原因可以被 UI 和测试明确消费。
- 新增控制器测试，覆盖缺失字段诊断和 OneNET MQTT 拒绝登录诊断。

变更：

- Token.log 导入改为单文件导入，只负责连接身份和设备 Token 信息。
- 物模型 JSON 回到物模型页单独导入，并继续校验 Product ID 是否与当前连接配置一致。
- 配置状态卡不再要求已有物模型属性才显示“连接信息已就绪”。
- 高级应用接入仅在选择高级鉴权模式时展示，减少简单模式下的干扰字段。
- README 更新为 Token.log/手动填写和物模型单独导入流程。

兼容性与迁移：

- 无数据库 schema 版本升级。
- 现有 `v0.5.0` 配置可以继续使用；已保存的 DeviceKey、Token、AccessKey 仍从安全存储读取。
- 物模型数据不受影响，但新流程要求在物模型页单独导入或维护物模型 JSON。

验证：

- `flutter pub get` 通过。
- `dart format lib test` 通过。
- `flutter analyze` 通过。
- `flutter test` 通过。
- `flutter build apk --release` 通过。
- `apksigner verify --print-certs` 通过。

发布产物：

- GitHub Release：[v0.6.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.6.0)
- 与上一版对比：[v0.5.0...v0.6.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/compare/v0.5.0...v0.6.0)
- 本地 APK 归档：`build/app/outputs/versioned-apk/don1ng-LinkBox-v0.6.0-signed.apk`
- GitHub Release 附件：`don1ng-LinkBox-v0.6.0-signed.apk`

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
