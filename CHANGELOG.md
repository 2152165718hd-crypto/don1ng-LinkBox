# 更新日志

本项目按 `VERSIONING.md` 维护版本。每个版本必须说明版本定位、相较上一版的变化、迁移或兼容性影响、验证结果和发布产物状态。

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
