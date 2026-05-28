# 护眼提醒

一个轻量的 macOS 护眼休息提醒工具。支持固定工作时长 / 休息时长、休息浮窗、延后 5 分钟、跳过本次休息，以及 `Esc` 直接跳过当前休息。

![界面预览](docs/assets/eye-breaker-preview.png)

## 功能

- 定时提醒休息
- 全屏休息浮窗
- `Esc` 跳过本次休息
- 延后 5 分钟
- 开机自启

## 使用

1. 打开应用后，在设置里调整工作分钟和休息分钟。
2. 点“保存”后开始计时。
3. 到休息时间后，会弹出全屏休息窗口。
4. 需要跳过时，按 `Esc` 或点“跳过本次休息”。

## 构建

```bash
swift build -c release
./scripts/package-app.sh release
```

打包后的应用在：

```bash
dist/护眼提醒.app
```

## 目录

- `Sources/`：应用源码
- `scripts/`：打包和图标生成脚本
- `dist/`：发布产物
- `docs/assets/`：README 预览图

## 许可证

MIT
