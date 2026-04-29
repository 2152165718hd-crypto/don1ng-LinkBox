# 更新日志

本项目按 `VERSIONING.md` 维护版本。每个版本必须说明版本定位、相较上一版的变化、迁移或兼容性影响、验证结果和发布产物状态。

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
