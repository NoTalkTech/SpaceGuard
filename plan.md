# SpaceGuard 场景化清理功能实施计划

## 概述
基于macOS磁盘清理操作手册，将SpaceGuard从通用风险评估工具进化为智能清理助手。实现场景化清理、预设策略、空间预估和安全检查功能。

## 核心架构变更
1. **CleanupScenarioDetector** - 场景检测模块
2. **SpaceEstimator** - 空间预估模块
3. **CleanupPresetManager** - 预设管理模块
4. **Enhanced RiskAnalyzer** - 场景感知风险评估
5. **SafetyChecker** - 安全检查模块

## 实施任务

### 阶段1：基础架构（核心模块）
#### 任务4：创建CleanupScenario枚举和基础检测逻辑
**文件**: `Sources/CleanupScenariosDetector.swift`
- 定义`CleanupScenario`枚举：trash, wallpaperCache, jetbrainsCache, shipItCache, homebrewCache, npmCache, pipCache
- 实现`detectScenario(at:)`方法：基于路径模式检测场景
- 实现`getScenarioDetails(_:)`方法：返回场景描述和风险说明
- 实现`estimateSpaceForScenario(_:)`方法：预估可释放空间

#### 任务5：实现SpaceEstimator空间预估功能
**文件**: `Sources/SpaceEstimator.swift`
- 实现`SpaceEstimator`类
- `estimateSpace(for:)`：基于场景预估可释放空间
- `calculateTotalSavings()`：计算所有检测场景总节省空间
- `formatSpace(_:)`：格式化空间显示（MB/GB）

#### 任务6：实现CleanupPresetManager预设管理
**文件**: `Sources/CleanupPresetManager.swift`
- 定义`CleanupPreset`枚举：safe, developer, advanced, custom
- 实现`PresetManager`类
- `getPresetRules(_:)`：返回预设对应的规则配置
- `applyPreset(_:to:)`：将预设应用到CleanupRules
- `saveCustomPreset(_:)`：保存自定义预设

### 阶段2：核心功能集成
#### 任务9：扩展CleanupRules支持预设配置（依赖任务4）
**文件**: `Sources/CleanupRules.swift`
- 添加`preset`属性到`CleanupRules`
- 添加`appliedPresets`数组记录已应用的预设
- 扩展`save()`和`load()`方法支持预设保存
- 添加`applyPreset(_:)`方法

#### 任务8：扩展CleanupEngine添加安全清理方法
**文件**: `Sources/CleanupEngine.swift`
- 添加`performSafeCleanup()`方法：执行安全清理流程
- 添加`validateCleanupSafety()`方法：安全检查
- 添加`estimateCleanupSpace()`方法：预估清理空间
- 添加`executeScenarioCleanup(_:)`方法：执行特定场景清理

#### 任务13：增强RiskAnalyzer支持场景感知风险评估
**文件**: `Sources/RiskAnalyzer.swift`
- 添加`considerCleanupScenario()`方法：场景因素加权
- 修改`assessRisk()`方法：集成场景感知
- 添加`getScenarioRiskLevel(_:)`方法：场景风险等级

### 阶段3：用户界面
#### 任务7：创建CleanupPresetsView预设选择界面
**文件**: `Sources/CleanupPresetsView.swift`
- 创建SwiftUI视图显示预设选项
- 每个预设显示：名称、描述、预估节省空间、风险等级
- 提供"应用预设"按钮
- 提供自定义预设创建界面

#### 任务10：修改SettingsView集成预设清理标签页
**文件**: `Sources/SettingsView.swift`
- 在TabView中添加"预设清理"标签页
- 集成`CleanupPresetsView`
- 添加空间预估显示区域
- 添加"立即清理"和"仅预估"按钮

### 阶段4：具体场景实现
#### 任务12：实现具体场景检测逻辑
**文件**: `Sources/CleanupScenariosDetector.swift`（扩展）
- 实现每个场景的具体检测逻辑：
  - **废纸篓**: 检测`~/.Trash`目录
  - **壁纸缓存**: 检测`~/Library/Application Support/com.apple.wallpaper/aerials`
  - **JetBrains缓存**: 检测`~/Library/Caches/JetBrains`和`~/Library/Logs/JetBrains`
  - **ShipIt缓存**: 检测`~/Library/Caches/*.ShipIt`模式
  - **Homebrew缓存**: 调用`brew cleanup -s`预估
  - **npm缓存**: 调用`npm cache clean --force`预估
  - **pip缓存**: 调用`pip3 cache purge`预估

#### 任务14：实现安全检查功能
**文件**: `Sources/SafetyChecker.swift`
- 实现`SafetyChecker`类
- `checkFileInUse(_:)`：检查文件是否被占用
- `checkApplicationRunning(_:)`：检查相关应用是否运行
- `checkDiskSpace()`：检查磁盘剩余空间
- `validateDeletionSafety(_:)`：综合安全检查

### 阶段5：测试和优化
#### 任务11：编写单元测试和集成测试
**文件**: `Tests/SpaceGuardTests/`（新目录）
- 创建测试目标（需要修改Package.swift）
- 编写`CleanupScenariosDetectorTests`
- 编写`SpaceEstimatorTests`
- 编写`CleanupPresetManagerTests`
- 编写`SafetyCheckerTests`

#### 任务15：性能优化和用户体验改进
- 优化场景检测性能（并行检测）
- 添加进度指示器
- 完善错误处理和用户反馈
- 添加清理历史记录

## 实施顺序和依赖
1. 任务4 → 任务9（依赖）
2. 任务4,5,6 → 任务7,8,10,13（并行）
3. 任务12,14 → 任务11（测试）
4. 所有任务 → 任务15（优化）

## 验证步骤
每个任务完成后：
1. 编译验证：`swift build`
2. 功能测试：运行应用测试场景
3. 代码审查：检查实现符合设计

## 成功标准
1. 应用支持选择预设清理策略
2. 准确预估可释放磁盘空间
3. 安全执行实际清理操作
4. 提供清晰的用户反馈和进度指示
5. 通过所有单元测试

## 风险管理
1. **数据安全**: 永不自动删除高风险文件
2. **系统稳定性**: 避免删除系统关键文件
3. **用户体验**: 提供撤销和确认机制
4. **性能影响**: 优化大目录扫描性能