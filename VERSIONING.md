# 版本管理规范

本项目采用语义化版本管理，并保持 Git tag、`pubspec.yaml`、`CHANGELOG.md` 和 GitHub Release 说明一致。

## 版本号

- Git tag 使用 `vMAJOR.MINOR.PATCH`，例如 `v0.2.0`。
- Flutter 应用版本使用 `MAJOR.MINOR.PATCH+BUILD`，例如 `0.2.0+2`。
- `BUILD` 每次正式 Release 都递增。

版本递增规则：

- `PATCH`：缺陷修复、文案调整、无兼容性影响的小改动。
- `MINOR`：新增功能、UI 能力、配置能力或数据模型的向后兼容扩展。
- `MAJOR`：破坏性变更，例如旧数据无法自动迁移、OneNET 配置契约不兼容、核心目录或接口大范围重构。

## 每版必须更新

发布任何版本前必须同步更新：

- `pubspec.yaml` 的 `version`
- `CHANGELOG.md` 的新版本条目
- `README.md` 的当前版本、应用版本和 Release 链接
- Git tag
- GitHub Release 说明

## Changelog 格式

每个 `CHANGELOG.md` 条目必须包含：

- 版本定位
- 相较上一版的更新说明
- 新增
- 变更
- 修复，若没有可省略
- 兼容性与迁移，若没有需写明无迁移要求
- 验证
- 发布产物
- 与上一版的 GitHub compare 链接，首版除外

## GitHub Release 说明

GitHub Release 正文必须包含：

- 版本摘要
- 与上一版相比的主要变化
- 兼容性或迁移说明
- 验证命令结果
- 发布产物说明
- 未上传 APK 或安装包时必须说明原因

未签名 APK 不得作为正式 Release 附件上传。只有通过正式 Android release signing 并通过 `apksigner verify` 的 APK/AAB 才能附加到 Release。

## 发布检查清单

发布前：

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --release
```

发布步骤：

```bash
git status --short --branch
git add .
git commit -m "Release vX.Y.Z ..."
git tag -a vX.Y.Z -m "don1ng LinkBox vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

发布后：

- 确认 GitHub Release 已创建。
- 确认 Release notes 与 `CHANGELOG.md` 对应版本一致。
- 确认 tag 指向发布提交。
- 确认工作区只剩被 `.gitignore` 屏蔽的本地生成物。
