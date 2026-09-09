# DLUT Online

**在熟悉的校园，遇见新的故事。**

DLUT Online 是一个以大连理工大学为背景的第一人称校园 MMORPG 项目，面向浏览器，探索校园生活与多人互动的更多可能。

从凌水主校区到开发区校区，再到盘锦校区，我们希望把散落在不同地方的校园记忆，连接成一个可以走进、停留和相遇的世界。沿着熟悉的道路漫步，重新看看曾经匆匆路过的建筑，也去认识另一座校区的风景。

校园的故事还在人与人之间。我们希望以各个社团的特色为灵感，将棋牌对弈、服装搭配和校园趣味活动融入这个世界，让共同的兴趣成为相识的起点。独自闲逛，或与朋友一起参与其中，都是我们想呈现的校园生活。

我们以真实地图与实景照片为参考，追求自然、写实的校园氛围，让建筑、道路与日常生活共同构成这个世界。

## 当前版本操作

点击进入校园后，WASD 行走，Shift 奔跑，鼠标环视，空格跳跃（仅落地时起跳，按住不连跳）。M 或点击小地图打开地图，M/Escape 收起；Escape 暂停，点击世界或 Escape 恢复，失焦停止控制。

浏览器加载页显示已加载 / 总资源量（MB）及百分比，1 MB = 1,000,000 字节；计数来自 Godot 的 WASM/PCK 加载进度，不代表压缩后的网络流量，下载完成后仍可能需要等待引擎初始化。

## 桌面服务器配置

编辑器 F5/F6 或直接运行项目时，默认 `DO_ENV=development`、`DO_SERVER_URL=http://localhost:8060`。Windows/macOS 导出（包括调试导出）默认使用 `production` 和 `https://dlut.online`；项目已启用原生导出插件，编辑器导出和 CI 均会自动将这两个值写入包内，不生成工作区配置文件。

在仓库根目录可这样覆盖本地配置：

```sh
DO_SERVER_URL=http://localhost:9000 godot --path apps/client
```

默认发布导出无需额外变量，也可显式指定。先确保输出目录存在：

```sh
mkdir -p apps/client/build/macos
DO_ENV=production DO_SERVER_URL=https://dlut.online \
  godot --headless --path apps/client --export-release macOS 'build/macos/DLUT Online.zip'
```

将导出命令中的 `DO_ENV` 改为 `development` 并移除 `DO_SERVER_URL`，可生成默认指向 localhost 的测试包。Windows 使用 `Windows` 预设与 `.exe` 输出路径。

桌面客户端运行时也接受进程环境变量覆盖。优先级为：显式 `DO_SERVER_URL` > 显式 `DO_ENV` 对应的默认地址 > 包内配置。空变量视为未设置；`DO_ENV` 只接受 `development` / `production`。服务器地址须为 HTTP(S) 根地址，不含接口路径，末尾斜杠会移除。不自动加载 `.env`；已打开的编辑器需要重启才能继承新设置的环境变量。

后续桌面网络代码通过 `preload("res://scripts/desktop_config.gd").read()` 获取 `environment` 和 `server_url`。本次仅配置地址，不发起连接；Web 不注入桌面配置，该读取入口在 Web 返回空字典，Web 同源连接留待网络模块实现。
