# Contributing

感谢你愿意改进森时。提交改动前，请确保：

1. 使用 macOS 14 或更新版本构建。
2. 运行 `swift build`。
3. 运行模型冒烟测试：

   ```bash
   swiftc Sources/FocusGarden/Models.swift SmokeTests/main.swift -o .build/model-smoke
   .build/model-smoke
   ```

4. 不提交 `.build`、`dist`、`.app`、用户偏好数据、绝对路径或签名凭据。
5. 新增视觉素材必须是原创、获得授权，或采用与本项目兼容的许可证。

提交 Issue 时，请说明 macOS 版本、复现步骤和预期行为。请勿附上包含私人白名单、浏览记录或其他敏感信息的截图和日志。
