# 开发部署脚本使用说明

## 一、首次安装（只需一次）

首次使用时，运行完整安装（自动编译 + 安装）：

```powershell
# 在 hades2-coop 目录下运行
.\install_all.ps1
```

这会：
1. 编译 `hades2-mod-extension` → 生成 `HadesModNativeExtension.asi`
2. 编译 `hades2-coop` → 生成 `HadesCoopGame.dll`
3. 安装 ASI Loader（如果未安装 Hell2Modding）
4. 复制所有文件到游戏目录

**⚠️ 注意：** 不要使用 `install/install.ps1`，它找不到依赖文件！

---

## 二、开发快速部署

修改代码后，只需运行：

```powershell
# 只修改了 Lua 脚本（无需重新编译）
.\dev_deploy.ps1

# 修改了 C++ 代码（需要编译）
.\build_and_deploy.bat
```

### 工作流对比

| 场景 | 脚本 | 耗时 |
|------|------|------|
| 首次安装 | `install_all.ps1` | ~5 分钟（编译两次） |
| 修改 Lua | `dev_deploy.ps1` | ~1 秒 |
| 修改 C++ | `build_and_deploy.bat` | ~30 秒（编译 + 部署） |
| 完全重装 | `install_all.ps1` | ~5 分钟 |

---

## 三、一键编译+部署

```batch
# CMD/PowerShell 一键编译+部署
.\build_and_deploy.bat
```

这会：
1. 编译 `hades2-coop`
2. 运行 `dev_deploy.ps1` 部署

---

## 配置游戏路径

首次运行 `dev_deploy.ps1` 或 `install_all.ps1` 时会询问游戏路径，保存到 `.gamepath` 文件。

**手动设置游戏路径：**
```powershell
echo "D:\SteamLibrary\steamapps\common\Hades II\Ship\Hades2.exe" > .gamepath
```

---

## 文件结构

### 安装后的游戏目录
```
Hades II/
├── Ship/
│   ├── Hades2.exe
│   ├── bink2w64.dll              ← ASI Loader
│   └── plugins/
│       └── HadesModNativeExtension.asi  ← Mod 加载器
└── Content/Mods/
    ├── TN_Core/                  ← 核心框架
    │   ├── core/
    │   └── meta.sjson
    └── TN_CoopMod/               ← Co-op Mod
        ├── HadesCoopGame.dll
        ├── config.lua
        ├── logic/
        │   ├── CoopRun.lua
        │   └── ...
        └── ...
```

---

## 验证部署

部署完成后，检查：
```powershell
# 检查 DLL 时间戳
Get-Item "E:\SteamLibrary\steamapps\common\Hades II\Content\Mods\TN_CoopMod\HadesCoopGame.dll"
```

---

## 常见问题

**Q: `install.ps1` 报错找不到 `HadesModNativeExtension.asi`？**
A: 使用 `install_all.ps1` 代替，它会自动编译并复制所有依赖。

**Q: 修改 Lua 脚本后没有生效？**
A: 运行 `.\dev_deploy.ps1` 确保文件已复制。

**Q: 编译失败？**
A: 确保先运行 CMake 生成构建文件：
```powershell
cmake -A x64 . -B build_msvc
```

**Q: 需要重新安装 ASI Loader？**
A: 只有以下情况需要重新运行 `install_all.ps1`：
- 游戏更新
- ASI Loader 更新
- 首次安装

---

## 开发提示

- **只改 Lua** → `dev_deploy.ps1`
- **改 C++** → `build_and_deploy.bat`
- **第一次设置** → `install_all.ps1`
- 可以将 `dev_deploy.ps1` 绑定到 VS Code 任务，保存时自动部署