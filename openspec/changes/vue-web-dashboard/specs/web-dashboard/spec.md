## ADDED Requirements

### Requirement: Vue 网站
网站 SHALL 使用 Vue 3、TypeScript 和 Vite，通过 Go 嵌入静态构建产物并同域提供 API，运行时不依赖 Node。

#### Scenario: 访问网站
- **WHEN** 用户打开 Go Web 首页
- **THEN** 显示产品介绍、客户端下载入口、总在线人数及三校区状态，并适配移动屏幕

#### Scenario: 未知资源
- **WHEN** 请求不存在的静态资源、API 或旧游戏 Web 路由
- **THEN** 返回 404 而非首页 HTML

### Requirement: 在线状态时效
网页 SHALL 每 10 秒请求公开在线接口，展示更新时间；失败、未上报或超过 15 秒的数据 SHALL 显示状态未知，不以零或历史人数冒充当前人数。

#### Scenario: 正常在线
- **WHEN** 接口返回有效 live 状态
- **THEN** 展示真实总人数、三校区人数及更新时间

#### Scenario: 断连或数据过期
- **WHEN** HTTP 请求失败或上报数据失效
- **THEN** 清楚显示状态未知并保留可用的最后更新时间，后续请求成功自动恢复
