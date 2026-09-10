## 1. 目录与引用

- [x] 1.1 完成 apps/game、apps/web 迁移及脚本职责分区，检查新旧路径、UID、LFS 和忽略规则。
- [x] 1.2 同步 CI、Docker、Compose、工具和技术文档引用，检查有效路径且根 README 未修改。

## 2. 验证与交付

- [x] 2.1 验证 Godot 导入、物理和网络回归，Go race/vet，通过桌面与游戏服导出及包内资源检查。
- [x] 2.2 验证新路径 Docker 构建与双服务运行，OpenSpec 严格校验后提交，保留用户配置修改并交付目录说明。

## 3. 镜像命名

- [x] 3.1 将游戏服和 Go HTTP 镜像分别命名为 dlut-online 和 dlut-online-web，同步 CI 与发布说明并验证标签映射。

- [x] 3.2 统一游戏服和 Web 可执行产物、Compose 服务名及内部地址，验证导出、镜像构建与双服务启动。
