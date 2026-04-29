# don1ng LinkBox

don1ng LinkBox 是一个 Flutter Android MVP，用于把 OneNET Studio 物模型设备快速变成手机端监控控制面板。首版采用 APP 直连 OneNET 的应用长连接 MQTT + OpenAPI，不冒充真实单片机设备登录 MQTT。

## 已实现

- OneNET 项目分组/用户鉴权配置，本地保存，`access_key` 通过安全存储单独保存。
- OpenAPI：最新属性查询、历史属性查询、属性设置。
- 应用 MQTT 长连接：订阅生命周期、属性上报、事件上报、属性设置响应。
- OneNET TSL JSON 导入：提取 `identifier/name/dataType/specs/accessMode`，异常属性跳过并生成导入报告。
- Token.log 识别：可自动带出 `Product ID` 和 `Device Name`，但不会把设备 `DeviceKey` 当作 APP 的 `AccessKey`。
- 毕设高频物模型模板：温湿度、烟雾、人体红外、光照、超声波、继电器、LED、电机。
- 自动生成默认面板：数值卡、开关、滑块、枚举选择、趋势图。
- 运行页：实时数据刷新、控制下发前校验、离线拦截、历史曲线。
- 本地日志和配置导出，导出默认不包含密钥。

## 运行

1. 安装 Flutter 3 和 Android SDK。
2. 在项目根目录执行：

```bash
flutter pub get
flutter test
flutter run -d android
```

如果 Android 工程提示缺少 `android/local.properties`，执行一次 `flutter pub get` 或手动写入：

```properties
flutter.sdk=C:\\path\\to\\flutter
```

## OneNET 配置

MVP 默认使用项目分组鉴权：

- `Project ID`
- `Group ID`
- `Access Key`
- `Product ID`
- `Device Name`

设备侧仍由单片机使用自己的 `ProductID/DeviceName/DeviceKey` 登录 OneNET。APP 不使用 `DeviceKey`，避免和真实设备抢占同一个 MQTT 设备会话。

## 当前边界

- 仅面向 Android；iOS 后台连接策略未处理。
- 仅支持 OneNET Studio 物模型，不支持旧版数据流/数据点产品。
- 自定义图片上传、素材矢量图库完整管理、配置加密导出属于 MVP+。
- 本仓库在当前机器上无法运行 Flutter 命令，因为本机未安装 `flutter`/`dart`。
