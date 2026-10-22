# 成长背包（材料扩容）

《饥荒联机版》服务器模组，版本 1.2.0。新增一个可用材料逐级扩容的背包：**8 → 16 → 24 → 32 格**。

[Steam 创意工坊](https://steamcommunity.com/sharedfiles/filedetails/?id=3822024875) · [公开源码](https://github.com/NewBoyIsBusy/growing-backpack) · [安装包下载](https://github.com/NewBoyIsBusy/growing-backpack/releases/tag/v1.2.0)

Steam 工坊条目设为仅好友可见；GitHub 源码和版本下载公开。

![成长背包升级概念封面](assets/workshop-preview.jpg)

封面为 AI 生成的宣传示意，非游戏截图。1.2.0 为四档背包加入独立绘制的贴图，详见下文。

## 制作与升级

在制作栏的“容器”分类中制作成长背包和扩容工具。

| 物品 | 配方 | 科技要求 | 用途 |
| --- | --- | --- | --- |
| 成长背包 | 草 ×4、树枝 ×4 | 科学机器 | 初始 8 格 |
| 皮革扩容工具 | 绳子 ×2、猪皮 ×2、金块 ×2 | 科学机器 | 8 → 16 格 |
| 机械扩容工具 | 蜘蛛丝 ×4、莎草纸 ×2、齿轮 ×2 | 炼金引擎 | 16 → 24 格 |
| 远古扩容工具 | 铥矿 ×4、黄宝石 ×2、噩梦燃料 ×4 | 完整远古伪科学站，每次需在站旁制作 | 24 → 32 格 |

1. 把成长背包脱下，放在地上；不用清空里面的东西。
2. 用鼠标拿起对应档位的扩容工具，指向**地上的背包实体**，执行“扩容背包”（左右键均支持）。
3. 成功后消耗一个工具，原背包直接增加容量，再捡起装备即可。

必须按顺序升级，无法跳级。错误档位、普通材料、已满级或穿戴中的背包不会消耗工具。升级后的容量显示在物品名称中，检查背包可查看下一档要求。

1.1.2 修复了旧版工具被“存入”背包而不升级的问题。把工具拖到已经打开的背包格子中仍是普通存放；扩容时请点地上的背包。先前被存入的工具可以取出继续使用。

容量记录在背包自身，换人携带不会重置。保存时记录等级，读档时先恢复容量，再装载包内物品。

## 分级外观

| 容量 | 独立贴图 |
| --- | --- |
| 8 格 | 缝补布包 |
| 16 格 | 猪皮行囊（带卷猪尾巴） |
| 24 格 | 发条机械背包（双孔发条钥匙、大弹簧、圆镜片） |
| 32 格 | 铥矿远古背包（橙黄色块、方形回纹、黑色刻线） |

![四档游戏物品栏贴图：布包、猪皮行囊、机械背包、远古背包](assets/tiers-preview.png)

四档采用一致的粗黑线、歪斜轮廓和少量平涂色。16 格猪皮行囊使用灰粉肉色和卷猪尾巴；24 格取材于原版发条生物，以双孔发条钥匙、灰色大弹簧、褐色铆钉外壳和圆镜片组成机械外观；32 格取材于原版铥矿，以橙黄色块、方形回纹和黑色刻线构成外壳。升级时同步切换地面造型、角色穿戴造型、物品栏图标及地图图标。贴图独立绘制，沿用原版背包动画；不需要购买皮肤。三档扩容工具拥有独立的地面造型、制作栏和库存图标：猪皮缝补包、发条零件包、铥矿镶嵌包。

![三档扩容工具图标](assets/kits-preview.png)

旧版本的已有背包在载入后会按保存的等级自动更新外观，无需重新制作或升级。容量和物品保留。1.1.3 的容器初始化和格子同步修复继续保留。

## 安装

解压 `growing_backpack_v1.2.0.zip`，把整个 `growing_backpack` 文件夹放入游戏 `Don't Starve Together/mods/`。目录结构应为 `mods/growing_backpack/modinfo.lua`。更新已安装的版本时完全退出游戏，覆盖原模组文件，然后重新启动。

房主在世界设置的“模组 → 服务器模组”中启用“成长背包（材料扩容）”。本模组新增物品和容器布局，**房主和所有加入的玩家均需安装**；本地安装包不会自动向好友分发，好友需要手动安装同一版本。

专用服务器需要在地面和洞穴的 `modoverrides.lua` 中都启用：

```lua
["growing_backpack"] = { enabled = true },
```

将该条目合并到现有 `return { ... }` 表中。已有世界可以启用，然后制作新背包。

## 使用说明

- 普通背包、猪皮包、坎普斯背包保持原版行为；只有新制作的“成长背包”可升级。
- 占用原版身体装备栏，不附带保鲜、防水、加速或防火效果。
- 仍然可燃，烧毁时按原版背包方式将物品掉落地面。
- 独立侧栏固定四行，容量增加时扩展列数（2/4/6/8 列）。整合背包模式下，16/24/32 格分别显示为 8 列 × 2/3/4 行，向上展开，物品图标保持原尺寸。鼠标和手柄均可使用；普通背包及游戏设置保持原样。
- 关闭或卸载前先把物品移出成长背包；禁用新增物品模组后，这些自定义物品无法正常载入。

## 开发验证

编译后的 `anim/gb_pack_0.zip` 至 `anim/gb_pack_3.zip` 和 `images/gb_pack_0..3.xml/.tex`，以及三组 `gb_upgrade_1..3` 对应动画和库存图标，随安装包发布。GitHub 另外保留透明 PNG 源图和构建脚本；运行模组不需要安装美术工具。

重新构建贴图需要 Python 3.10+、Pillow，以及 Steam 的 Don't Starve Mod Tools（其自带 Python 2.7、`buildanimation.py` 和 `TextureConverter.exe`）：

```powershell
python tools/build_art.py --work-dir ../.tools/art_build
```

在仓库根目录运行。工具默认查找本机 D 盘 Steam 的 Mod Tools，可用 `--mod-tools` 指定 `mod_tools` 目录，或用 `--level 0` 只编译一个等级。源图为 4 列、3 行的透明图集；构建时生成各视角贴图、穿戴符号、库存和地图图标，并验证编译产物。

工坊包以普通文件发布，不含 Klei 文件清单，`modinfo.lua` 必须保留 `forcemanifest = false`，否则工坊版会在启动时找不到模块。同级克隆 [nearby-autofuel](https://github.com/NewBoyIsBusy/nearby-autofuel) 后，其 `tests/run_workshop_smoke.py` 可直接加载两个实际工坊安装包进行联合验证，支持 `--caves`。

```powershell
python growing_backpack/tests/run_checks.py
python growing_backpack/tests/run_client_checks.py
python growing_backpack/tests/run_inventory_layout_checks.py
python growing_backpack/tests/run_game_smoke.py
```

`run_checks.py` 需要 Python 与 `lupa.lua51`，优先使用工作区 `.tools/lua_test_runtime`。它检查 Lua 5.1 语法、四档布局、等级边界，以及远端客户端初始化和等级变更后的容器刷新。

`run_client_checks.py` 在 Lua 5.1 中运行原版 `container_replica` 和 `container_classified` 的实际客户端代码，以模拟网络变量和调度器检查生命周期。可复现 1.1.2 的重复初始化崩溃，并验证制作后初始化、四档有效格子、末格监听、满包判断、重开、晚加入及预制物回调。需要原版 `scripts` 目录（默认工作区 `game_scripts_reference/scripts`，或设置 `DST_SCRIPTS_PATH`）。这不是完整真人客户端的联网测试。

`run_game_smoke.py` 默认使用本机 Steam 的 DST 专用服务器，也可将游戏路径作为参数传入。脚本创建单独的离线测试世界和临时验证模组，不读取已有存档；结束后移除临时模组，保留工作区 `growingpack_*` 目录中的日志。验证内容包括配方注册、初始容量、升级顺序、工具扣除、原物品保留、末格存储、满包存取档、穿脱和原版背包隔离。

远端客户端检查使用模拟环境；游戏界面的实际显示、真人多人联机及跨洞穴迁移仍需在游戏中验收。原版游戏脚本和测试世界不包含在安装包内。

2026-10-18，1.1.0 验证结果：Lua 5.1 语法和客户端模拟检查通过；本机 DST 专用服务器的 9 项引擎测试全部通过，包括装满 32 格后保存并恢复物品、四档外观与图标的切换及读档恢复。穿戴符号覆盖与清理另通过模拟检查；专用服务器无画面，尚未做真人客户端的视觉验收。

2026-10-18，1.1.2 验证结果：12 项引擎测试通过，新增原版动作选择器的左右键选择、三档升级执行、错误档位和满级拒收、普通物品存入及工具存入其他容器检查；客户端仅副本组件环境下的动作收集也通过模拟测试。

2026-10-18，1.1.3 验证结果：13 项引擎测试通过，包含实际制作成长背包、材料扣除、自动装备、三档工具制作与升级。原版客户端容器代码的 5 组生命周期检查通过，覆盖原崩溃复现、重复初始化、四档同步、重开/晚加入和实际预制物回调。所有检查均使用独立测试环境，不读取或修改玩家存档。

四档贴图由内置 `image_gen` 工具生成，最终源图为 `assets/source/gb_pack_0.png` 至 `gb_pack_3.png`。布包使用 `prompts.txt`；猪皮行囊由 `upgrade-prompts.txt` 的初稿按 `pigskin-edit-prompt.txt` 修改；发条机械包和铥矿远古包分别采用 `clockwork-final-prompt.txt`、`thulecite-final-prompt.txt` 重新生成。完整提示词链和被替代旧稿的说明见 [美术源文件说明](assets/source/README.txt)。这些源图和提示词仅在 GitHub 源码中保留，Steam 和安装包使用编译后的资源。封面同样由内置 `image_gen` 生成，提示词保存于 `assets/cover-prompt.txt`；原图为 `assets/workshop-cover.png`，工坊使用同画面的 JPEG 文件 `assets/workshop-preview.jpg`。

扩容工具源图为 `assets/source/gb_upgrade_1.png` 至 `gb_upgrade_3.png`，分别使用同目录对应的 `gb_upgrade_N-prompt.txt`，由内置 image_gen 生成。

2026-10-22，1.2.0 验证结果：14 项真实游戏引擎检查通过，包括四档独立 build/库存与地图 atlas、三种工具动画/制作图标、制作自动装备、升级与满包读档；5 组原版客户端容器生命周期检查及7组真实 inventorybar 代码配合 UI stub 的布局/导航检查通过。4组背包共48帧及3种工具均经官方编译和BC3解码校验。UI检查覆盖16/24/32分行、32格手柄导航、末格事件、换普通背包恢复、光标及缩放锚点；这不等同于真人客户端画面验收。
