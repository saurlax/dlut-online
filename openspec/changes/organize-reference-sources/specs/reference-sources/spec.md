## ADDED Requirements

### Requirement: Campus and subject organization

项目 SHALL 将单校区参考资料放入 references/lingshui、references/eda、references/panjin，并按 mapping、terrain、vegetation、buildings、facilities、imagery 分类。跨校区来源 SHALL 放入 references/shared；events 和 documents SHALL 按真实资料需要创建。

#### Scenario: Add a campus source

- **WHEN** 增加一个校区的建筑照片、地形或植被数据
- **THEN** 资料归入该校区对应主题，保留原始 URL、对象 ID、读取日期、用途与精度信息，不复制其他校区资料填空

### Requirement: Directory documentation and evidence

README SHALL 只维护目录职责、录入规范和索引；长期配准及估计依据 SHALL 保存于专题 basis.md 或 JSON，需求和任务状态 SHALL 维护于 OpenSpec；临时验收材料 MUST NOT 作为长期资料提交。

#### Scenario: Reorganize existing evidence

- **WHEN** 移动现有照片、索引和来源说明
- **THEN** 同步生成器和文档引用，保持原始影像、源 URL、测量及估计数值不变，并验证迁移前后生成结果只存在来源路径差异

### Requirement: Project source and licence register

根目录 CREDITS.md SHALL 记录游戏、网站和服务端使用的信息、素材、数据服务与算法参考，包括 Weather API。声明 SHALL 使用正式的版权与许可文体，仅列实际使用的来源、使用范围、权利归属及许可条件；MUST NOT 包含调研候选、内部维护约定或过程报告。授权依据缺失时 SHALL 如实说明，不把公开访问等同于开放许可。

#### Scenario: Weather provider attribution

- **WHEN** 服务端通过 Open-Meteo 获取天气并向客户端提供
- **THEN** 声明记录 API 来源、CC BY 4.0 数据许可、服务套餐条件和可视化处理，链接共享天气资料，并与桌面 WEATHER-CREDITS.txt 同步维护

#### Scenario: Distribute an existing website asset

- **WHEN** 网站包含校园照片、视频或字体副本
- **THEN** 声明记录实际分发文件、原始来源、处理和许可状态，不将它们误标为仅离线参考

#### Scenario: Formal third-party notice

- **WHEN** 编辑 CREDITS.md
- **THEN** 使用分条声明与正式署名，保留 Weather API、素材及字体的适用许可和必要授权说明；目录录入规则保留在 references/README.md
