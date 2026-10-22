成长背包 1.3.0 美术源文件

本目录美术均使用内置 image_gen 生成或编辑。1.3.0 将穿戴素材与地面/图标来源分离：四张 gb_pack_N-worn.png 用于肩带及各方向穿戴，四张 gb_pack_N.png 仅继续提供地面造型与物品栏/地图图标；旧图集中的穿戴视角已被替代。构建脚本 tools/build_art.py 将两类源图组合为 anim/gb_pack_N.zip 与 images/gb_pack_N.xml/.tex。所有物品栏图标编译为 64×64 像素，并留透明边距。游戏发布包包含编译资源；本目录源图、提示词和说明保留在 GitHub。

当前穿戴源图：
  gb_pack_0-worn.png — 缝补布包；提示词 gb_pack_0-worn-prompt.txt。
  gb_pack_1-worn.png — 猪皮行囊；提示词 gb_pack_1-worn-prompt.txt。
  gb_pack_2-worn.png — 发条机械背包；提示词 gb_pack_2-worn-prompt.txt。
  gb_pack_3-worn.png — 铥矿远古背包；提示词 gb_pack_3-worn-prompt.txt。
  模式：内置 image_gen，依据原版背包符号布局与对应已认可的背包设计重新生成穿戴图集；正面是肩带，各方向包体按角色视角分别绘制。
  图集仍为 4 列、3 行，用于构建脚本指定的穿戴符号；地面帧来自下列原图。最终穿戴几何以构建脚本与编译产物为准。

地面造型与图标源图、提示词链：

gb_pack_0.png — 8 格缝补布包
  提示词：prompts.txt 的 Tier 0。
  模式：内置 image_gen，以原版背包图集为布局参考生成。
  设计：粗黑线、歪斜轮廓、灰橄榄布料、赭色包盖、骨扣和粗针脚补丁。

gb_pack_1.png — 16 格猪皮行囊
  提示词链：upgrade-prompts.txt 的 Tier 1 → pigskin-edit-prompt.txt。
  模式：内置 image_gen 先以认可的布包图集为风格/布局参考生成，再编辑；最终编辑另参考原版猪皮包材质。
  最终设计：灰粉肉色猪皮、卷猪尾巴、骨扣和粗针脚。upgrade-prompts.txt 中红褐皮革初稿的描述已由最终编辑替代。

gb_pack_2.png — 24 格发条机械背包
  最终提示词：clockwork-final-prompt.txt。
  模式：内置 image_gen 重新生成，以认可的布包图集为布局参考，并参考原版发条骑士、发条主教材质。
  最终设计：双孔发条钥匙、灰色大弹簧、褐色铆钉外壳和圆镜片。
  过程提示词：upgrade-prompts.txt 的 Tier 2、mechanical-edit-prompt.txt。两者均记录此前方案，已被 clockwork-final-prompt.txt 的最终设计替代，不代表当前 gb_pack_2.png。

gb_pack_3.png — 32 格铥矿远古背包
  最终提示词：thulecite-final-prompt.txt。
  模式：内置 image_gen 重新生成，以认可的布包图集为布局参考，并参考原版铥矿、铥矿甲和铥矿皇冠材质。
  最终设计：橙黄色块状铥矿外壳、方形回纹和黑色刻线。
  过程提示词：upgrade-prompts.txt 的 Tier 3、ancient-cleanup-prompt.txt。两者均记录此前方案，已被 thulecite-final-prompt.txt 的最终设计替代，不代表当前 gb_pack_3.png。

tiers-preview.png 是四档物品栏图标的并排排版预览，不是游戏截图或另一套源图。最终外观以四张 gb_pack_N-worn.png、四张 gb_pack_N.png 及其编译产物为准。旧提示词仅保留设计过程，重新生成最终方案时应使用上面对应的最终提示词和参考关系。

三种扩容工具：gb_upgrade_1.png（猪皮缝补包）、gb_upgrade_2.png（发条零件包）、gb_upgrade_3.png（铥矿镶嵌包）。均使用内置 image_gen 生成；对应最终提示词为 gb_upgrade_1-prompt.txt 至 gb_upgrade_3-prompt.txt。

两种功能插件：gb_preservation_kit.png（保鲜插件）、gb_freshness_kit.png（返鲜插件）。均使用内置 image_gen 生成；对应提示词为 gb_preservation_kit-prompt.txt、gb_freshness_kit-prompt.txt。

上述五种工具由 tools/build_kit_art.py 编译独立 idle 动画、地面造型及 64×64 像素库存图标。assets/kits-preview.png 为五种图标并排预览，不是游戏截图。
