## 1. 固定签名
- [x] 1.1 保存当前本机 keystore 到仓库 Actions Secret，不输出密钥内容。
- [x] 1.2 更新普通构建、发布调用、受限 PR 行为和相关规范。
- [x] 1.3 actionlint、OpenSpec 严格校验通过；本地执行工作流签名步骤，验证固定密钥恢复、缺失密钥失败、受限 PR 退化和无效 Base64 失败；提交并创建 PR。
