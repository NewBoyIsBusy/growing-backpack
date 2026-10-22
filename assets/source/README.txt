成长背包 1.2.0 美术源文件

本目录的四张 gb_pack_N.png 是当前采用的最终源图。均使用内置 image_gen 生成或编辑，每张为 4 列、3 行透明图集：前 6 格为穿戴肩带，后 6 格为不同方向的背包。构建脚本 tools/build_art.py 将它们编译为 anim/gb_pack_N.zip 与 images/gb_pack_N.xml/.tex。游戏发布包包含编译资源；本目录源图、提示词和说明保留在 GitHub。

最终源图与提示词链：

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

tiers-preview.png 是四档物品栏图标的并排排版预览，不是游戏截图或另一套源图。最终外观以四张 gb_pack_N.png 及其编译产物为准。旧提示词仅保留设计过程，重新生成最终方案时应使用上面对应的最终提示词和参考关系。

三种扩容工具：gb_upgrade_1.png（猪皮缝补包）、gb_upgrade_2.png（发条零件包）、gb_upgrade_3.png（铥矿镶嵌包）。均使用内置 image_gen 生成；对应最终提示词为 gb_upgrade_1-prompt.txt 至 gb_upgrade_3-prompt.txt。由 tools/build_kit_art.py 编译独立 idle 动画、地面造型及128像素库存图标。
