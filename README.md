<h1 align="center">DLUT Online</h1>

[![Build](https://github.com/saurlax/dlut-online/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/saurlax/dlut-online/actions/workflows/build.yml)
[![Documentation](https://img.shields.io/badge/docs-spec-blue)](spec/README.md)

**以大连理工大学为背景的浏览器像素多人在线游戏。**

DLUT Online 将校园探索、像素美术与多人在线体验结合在一个可自行部署的项目中。项目以真实校园资料为基础，通过俯视二维世界呈现建筑、道路与公共空间，面向电脑和移动设备上的浏览器访问。

项目围绕三个方向建设：

- **探索校园。** 以校园空间为核心，构建连贯、可行走的像素地图，保留真实场所的布局与辨识特征。
- **多人在线。** 让玩家进入同一个校园世界，通过账号身份与统一的游戏规则参与探索和交流。
- **自行部署。** 提供完整源码与统一发行镜像，支持独立运行和持续开发。

> 项目处于早期开发阶段。目前已建立网页与账号后端基础；可探索校园、像素角色、光照特效和多人游戏仍在建设中。

## 校园世界

DLUT Online 的内容范围覆盖大连理工大学凌水、开发区和盘锦三个校区。校园建设以照片及有效地图资料为依据，通过统一的像素风格表达空间关系与建筑特征。

游戏体验以校园探索为中心。昼夜变化、天气、二维光照和环境特效用于呈现不同时间与条件下的校园氛围。地图与室内内容按资料完整程度逐步建设，未经核实的区域不作为已完成内容发布。

世界表现、交互边界与美术要求见[前端与像素世界规范](spec/frontend.md)。

## 多人在线

多人模式以真实账号和服务端权威状态为基础。玩家移动、地图归属与交互结果遵循统一规则，客户端负责操作反馈与画面表现。

实时同步、连接恢复和持久化的职责分别由[多人通信规范](spec/networking.md)及[账号与持久化规范](spec/backend.md)定义。相关能力将随游戏实现逐步交付。

## 自行部署

项目以单一 `dlut-online` 容器镜像发行，网页与账号后端一同部署。

- [容器镜像](https://github.com/saurlax/dlut-online/pkgs/container/dlut-online)
- [部署指南](docs/deployment.md)：安装、数据管理、发布与回滚。
- [版本发布](https://github.com/saurlax/dlut-online/releases)：已发布版本及对应说明。

本文及仓库文档跟随 `main` 更新。部署特定版本时，应以对应标签下的文档和发布说明为准。

## 从源码开发

阅读[贡献指南](CONTRIBUTING.md)准备开发环境，并根据改动范围选择相应文档：

| 工作范围 | 文档 |
| --- | --- |
| 产品范围与整体设计 | [规范总览](spec/README.md) |
| 浏览器界面与像素世界 | [前端规范](spec/frontend.md) |
| 账号、接口与持久化 | [后端规范](spec/backend.md) |
| 游戏状态与实时通信 | [通信规范](spec/networking.md) |
| 仓库组织与发行边界 | [仓库规范](spec/repository.md) |
| 编码与验证约定 | [开发约定](DEVELOPMENT.md) |

当前 `main` 维护浏览器像素版本。历史三维版本保存在 [`3d` 分支](https://github.com/saurlax/dlut-online/tree/3d)。

## 参与贡献

欢迎提交问题反馈、文档修订和范围明确的功能改进。提交前请先查看[现有 Issues](https://github.com/saurlax/dlut-online/issues)与[贡献指南](CONTRIBUTING.md)；涉及产品范围、校园资料或网络协议的调整，应先明确需求与依据，再推进实现。
