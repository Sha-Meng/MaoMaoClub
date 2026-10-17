# 店长 Blender 动画验证

状态：2026-10-17 用户授权执行单角色验证。

## 为什么

现有整图程序变形步态被用户否定。用户选择免软件授权费、由代理完成制作与接入的路线，先以店长验证 Blender 分层骨骼动画导出透明序列帧后在 Godot 4.6.3 播放。

## 改什么

- 补画店长完整分层，保存生成原稿、提示词和部件定位数据。
- 创建可编辑 Blender 骨骼、权重与关键帧工程及可复现构建脚本。
- 制作站立、起步、行走、持杯行走、停步，覆盖双向、常驻尺寸与放大对照。
- 提供独立 Godot 验证场景，自动验证状态衔接、位移同步、素材边界及占用。
- 保留现有营业入口与存档；验证结果明确区分技术通过、代理视觉检查及用户验收。

## 影响

- 范围仅店长；全员迁移由 adopt-authored-character-animation 继续跟踪。
- 新资源与脚本位于 assets/source/manager_blender、assets/tavern/manager_authored、features/animation_lab、tools/manager_blender、tests/animation_lab。
- Blender 仅离线制作依赖，不作为游戏运行依赖。
