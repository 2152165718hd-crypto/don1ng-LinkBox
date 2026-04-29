# don1ng LinkBox

don1ng LinkBox 是一个 Flutter Android 应用，用于把 OneNET Studio 物模型设备快速接入手机端监控和控制面板。当前版本采用应用侧直连 OneNET OpenAPI 与应用长连接 MQTT，不冒充真实单片机设备登录 MQTT，避免和设备端抢占同一个设备会话。

![don1ng LinkBox cover](assets/branding/linkbox_cover.png)

## 当前版本

- 最新版本：`v0.2.0`
- 应用版本：`0.2.0+2`
- Release 页面：[don1ng LinkBox v0.2.0](https://github.com/2152165718hd-crypto/don1ng-LinkBox/releases/tag/v0.2.0)
- 状态：Android MVP，可运行源码版本；正式签名 APK 尚未配置发布。

## 功能特性

- OneNET 项目分组/用户鉴权配置，本地保存，`AccessKey` 使用安全存储单独保存。
- OpenAPI：最新属性查询、历史属性查询、属性设置。
- 应用 MQTT 长连接：订阅生命周期、属性上报、事件上报、属性设置响应。
- OneNET TSL JSON 导入：提取 `identifier`、`name`、`dataType`、`specs`、`accessMode`，异常属性会跳过并生成导入报告。
- Token.log 识别：可自动带出 `Product ID` 和 `Device Name`，不会把设备 `DeviceKey` 当作 App 的 `AccessKey`。
- 自动生成默认面板：数值卡、进度条、仪表盘、开关、按钮、滑块、枚举选择、状态文本、趋势图。
- 可编辑 UI 卡片：支持显示模式、尺寸、颜色、单位显示、小数位和图标配置。
- 内置 IoT PNG 图标库：温度、湿度、光照、烟雾、距离、开关、继电器、电机、设备。
- 支持上传 PNG 作为单个控件图标。
- 运行页：实时数据刷新、控制下发前校验、离线拦截、历史曲线。
- 本地日志和配置导出，导出默认不包含密钥。
- 品牌启动图、应用封面和 Android launcher icon。

## 运行环境

- Flutter 3.x
- Dart 3.x
- Android SDK
- JDK 17
- Android 设备或模拟器

本项目已提交 `pubspec.lock` 和 Android Gradle Wrapper，首次拉取后可以直接使用仓库内的 Gradle 配置。

## 本地运行

```bash
flutter pub get
flutter test
flutter run -d android
```

如果 Android 工程提示缺少 `android/local.properties`，执行一次 `flutter pub get`，或手动写入本机 Flutter SDK 路径：

```properties
flutter.sdk=C:\\path\\to\\flutter
```

## 构建 APK

调试或本地验证可以执行：

```bash
flutter build apk --release
```

构建产物会出现在：

```text
build/app/outputs/flutter-apk/app-release.apk
```

注意：仓库当前没有提交正式签名配置。面向用户分发 APK 前，需要先配置 Android release signing，并确认 APK 可以通过 `apksigner verify`。

## OneNET 配置

默认使用 OneNET Studio 应用开发侧的项目分组鉴权，需要在 App 内填写：

- `Project ID`
- `Group ID`
- `Access Key`
- `Product ID`
- `Device Name`

设备侧仍由单片机使用自己的 `ProductID`、`DeviceName`、`DeviceKey` 登录 OneNET。App 不使用 `DeviceKey`，避免影响真实设备 MQTT 在线状态。

## 数据导入

- `Token.log`：用于识别 `Product ID` 和 `Device Name`。
- OneNET TSL JSON：用于生成属性模型、控制类型和默认面板。
- 导入过程中会跳过不支持或格式异常的属性，并保留导入报告方便排查。

本地云平台日志、物模型一键导入样例、构建缓存和 Android 本地配置已在 `.gitignore` 中屏蔽，避免把密钥、Token 或机器路径提交到仓库。

## 项目结构

```text
lib/
  core/          主题和全局样式
  dashboard/     物模型面板生成和控件
  onenet/        OneNET OpenAPI、MQTT、鉴权和 Token.log 解析
  runtime/       页面运行状态、连接和控制流程
  storage/       本地数据库、安全存储和导出
  thing_model/   物模型模板、导入器和校验器
test/            鉴权、物模型导入、Token.log 和控制校验测试
assets/branding/ 品牌封面和图标素材
android/         Android 工程和 Gradle Wrapper
```

## 已验证

```bash
flutter test
```

测试覆盖：

- OneNET 应用鉴权参数生成
- OneNET TSL 属性导入和异常节点跳过
- Token.log 字段解析
- 控制值范围和只读属性校验

## 当前边界

- 仅面向 Android；iOS 后台连接策略未处理。
- 仅支持 OneNET Studio 物模型，不支持旧版数据流/数据点产品。
- Release 暂未附带正式签名 APK。
- 素材矢量图库完整管理、配置加密导出属于后续版本范围。
