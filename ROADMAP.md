# Gotoo 发布路线图

## 当前状态

- 代码完成，BUILD SUCCEEDED（Debug + Release）
- GitHub 远程仓库：`Henri3s/gotoo`
- 沙箱已关闭，App 可访问完整文件系统
- Ad-hoc 签名打包脚本已就绪
- GitHub Actions CI/CD 已配置
- 本地 DMG 打包验证通过（3.6MB）

---

## 开源分发方案（无需 Apple Developer Program）

大量知名开源 Mac App 都采用此方式：IINA、Rectangle、AltTab、MonitorControl、Stats、Homebrew Cask 中的数千个应用。

### 用户安装方式

1. 下载 DMG → 拖拽到应用程序文件夹
2. **首次打开**：右键点击 Gotoo → 选择「打开」→ 再次点击「打开」
3. 或者终端执行 `xattr -cr /Applications/Gotoo.app`

---

## 已完成

- [x] 关闭 App Sandbox（文件管理器需要完整磁盘访问）
- [x] 移除 Hardened Runtime（不需要公证）
- [x] 清空 DEVELOPMENT_TEAM（不需要证书）
- [x] 本地打包脚本 `scripts/build-release.sh`
- [x] GitHub Actions `.github/workflows/release.yml`
- [x] Ad-hoc 签名 + DMG 打包验证通过

## 发布步骤

### 方式一：推 tag 触发 GitHub Actions 自动发布

```bash
git add -A
git commit -m "v0.8.0"
git tag v0.8.0
git push origin main --tags
```

GitHub Actions 自动：构建 → 签名 → 打 DMG → 创建 GitHub Release → 上传 DMG

### 方式二：本地构建手动上传

```bash
./scripts/build-release.sh 0.8.0
# 然后在 GitHub Releases 页面手动上传 dist/Gotoo-0.8.0.dmg
```

---

## 后续可选优化

| 项目 | 优先级 | 说明 |
|------|--------|------|
| Homebrew Cask 分发 | 中 | 提交到 homebrew-cask，用户可 `brew install --cask gotoo` |
| Sparkle 自动更新 | 低 | 嵌入 Sparkle 框架实现应用内自动更新 |
| Apple Developer 签名 | 低 | $99/年，消除首次打开的右键步骤 |
| Mac App Store | 低 | 需要重新开沙箱 + 适配权限，工作量较大 |
