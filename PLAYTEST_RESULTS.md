# Robot War Prototype 半自动 Playtest 结果

> 本轮是半自动基线记录：用现有 LÖVE 自动截图采集 wave 1/3/6/9/12 的战斗与商店状态，并结合当前配置计算压力/经济快照。它不是完整人工通关结论，不能替代后续真实游玩测试。


## 2026-05-26 23:14 CST · v2026.05.26.80 Boss 教学阀与第二章坡度回归

### 范围

- 在 20 Boss 随机池后，修正早期自然构筑稳定性。
- 新增/调整：第一 Boss 教学保护、前两章 Boss 前整备、Boss 击破后章节整备、第二章普通关/第二 Boss 坡度、玩家燃烧残焰不再自伤、自动跑局死亡/超时详情。
- 记录文件：
  - `tmp/natural20/playtest-v80l-natural-target6-run1.md`
  - `tmp/natural20/playtest-v80l-natural-target6-run2.md`
  - `tmp/natural20/playtest-v80l-natural-target6-run3.md`
  - `tmp/natural20/playtest-v80l-balanced-wave9-direct.md`
  - `tmp/natural20/playtest-v80l-balanced-wave12-direct.md`

### 自然构筑 target wave 6

| Run | Wave 3 Boss | Wave 6 Boss | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 1 | 终焉播报机 | 零度列车 | 抵达 wave 6 后商店 | 通过，结束 77/106 HP、104/121.5 护盾。 |
| 2 | 碎星决斗者 | 天灾反应堆 | 死亡于 wave 6 | 死于泄压区；第二 Boss 区域型仍需后续观察。 |
| 3 | 终焉播报机 | 裂心机核 | 抵达 wave 6 后商店 | 通过，结束 55/76 HP、68/80 护盾。 |

### 高波测试构筑直跑

| Wave | Boss | 结果 | 备注 |
| --- | --- | --- | --- |
| 9 | 蜂巢母机 | Boss 击破 | balanced 直跑通过。 |
| 12 | 深井压缩者 | Boss 击破 | balanced 直跑通过；击杀数 119，仍需自然构筑复核拖时。 |

### 结论

- 早期 Boss 随机池不再稳定卡死在 wave 3；自然构筑 target wave 6 达到 2/3 通过。
- 第二章 Boss 仍存在区域型失败样本，不能视为完整自然难度收口。
- 中后段 Boss 链路未被教学阀改崩：balanced wave 9 / 12 直跑通过。


## 2026-05-26 22:22 CST · v2026.05.26.79 20 Boss 点名回归

### 范围

- 使用 `LOVE_AUTOPLAY_BOSS_ID` 强制逐个指定 20 个 Boss。
- 测试方式：`balanced` 测试构筑，wave 6 直跑。
- 记录目录：`tmp/boss20/playtest-v79-*-wave6.md`。
- 注意：这是基础链路回归，不等同自然构筑难度结论。

### 结果摘要

| Boss ID | Boss | 结果 | 击杀数 |
| --- | --- | --- | --- |
| `boss_heartbreak` | 裂心机核 | Boss 击破 | 1 |
| `boss_forge` | 赤炉执刑者 | Boss 击破 | 1 |
| `boss_bulwark` | 铁幕壁垒 | Boss 击破 | 1 |
| `boss_hive` | 蜂巢母机 | Boss 击破 | 1 |
| `boss_glacier` | 冷井裁决体 | Boss 击破 | 1 |
| `boss_venom` | 蚀刻孢群 | Boss 击破 | 1 |
| `boss_void` | 黑箱坍缩核 | Boss 击破 | 1 |
| `boss_rail` | 白噪狙击塔 | Boss 击破 | 1 |
| `boss_reactor` | 天灾反应堆 | Boss 击破 | 1 |
| `boss_reboot` | 重启终端 | Boss 击破 | 1 |
| `boss_storm` | 电磁审判庭 | Boss 击破 | 1 |
| `boss_mirror` | 量子镜像体 | Boss 击破 | 1 |
| `boss_reclaimer` | 回收圣棺 | Boss 击破 | 2 |
| `boss_minefield` | 地雷织网机 | Boss 击破 | 1 |
| `boss_duelist` | 碎星决斗者 | Boss 击破 | 1 |
| `boss_prism` | 棱镜分光仪 | Boss 击破 | 1 |
| `boss_gravity` | 深井压缩者 | Boss 击破 | 1 |
| `boss_stitcher` | 血肉缝合塔 | Boss 击破 | 4 |
| `boss_train` | 零度列车 | Boss 击破 | 1 |
| `boss_broadcast` | 终焉播报机 | Boss 击破 | 1 |

### 结论

- 20 个 Boss 模板均可生成、进入战斗、被击破并结算。
- `luac -p main.lua` 和 `git diff --check` 通过。
- 回收圣棺、血肉缝合塔已体现召唤/恢复型机制，但 wave 6 下仍可控。
- 下一步仍需自然构筑和高波次连续战役验证，重点看召唤/区域/恢复 Boss 是否拖时。


## 2026-05-26 22:08 CST · v2026.05.26.78 10 Boss 随机池回归

### 范围

- 新增 10 Boss 随机池后，使用 `balanced` 测试构筑直跑 Boss 波：wave 3 / 6 / 9 / 12。
- 记录文件：
  - `tmp/playtest-20260526-140752-v78-named-balanced-wave3-direct.md`
  - `tmp/playtest-20260526-140754-v78-named-balanced-wave6-direct.md`
  - `tmp/playtest-20260526-140756-v78-named-balanced-wave9-direct.md`
  - `tmp/playtest-20260526-140758-v78-named-balanced-wave12-direct.md`
- 注意：本轮是强测试构筑直跑，只验证 Boss 随机池、动态缩放和机制链路不崩，不等同自然构筑难度结论。

### 结果摘要

| Wave | 随机 Boss | 结果 | 关键观察 |
| --- | --- | --- | --- |
| 3 | 白噪狙击塔 | Boss 击破 | 直跑通过，满血满盾。 |
| 6 | 蜂巢母机 | Boss 击破 | 直跑通过，满血满盾。 |
| 9 | 蚀刻孢群 | Boss 击破 | 直跑通过，击杀数 9。 |
| 12 | 蚀刻孢群 | Boss 击破 | 直跑通过，击杀数 453；提示该 Boss 在高波次会拉长战斗并大量触发敌群，需要后续自然构筑复核。 |

### 结论

- 10 Boss 随机池第一版可运行：Boss 名称能进入自动记录，Boss 波能从池中抽取不同模板。
- 动态数值缩放链路未被破坏：wave 3/6/9/12 均可完成。
- 仍需后续做自然构筑和连续战役验证，尤其是高波次召唤/区域型 Boss 的耗时和击杀数是否过高。


## 2026-05-26 21:37 CST · v2026.05.26.77 多轮自动记录

### 范围

- baseline 自然开局：连续 3 轮目标 wave 3，记录文件：
  - `tmp/playtest-20260526-133657-v77-baseline-wave3-run1.md`
  - `tmp/playtest-20260526-133715-v77-baseline-wave3-run2.md`
  - `tmp/playtest-20260526-133726-v77-baseline-wave3-run3.md`
- `balanced` 测试构筑：
  - wave 3→6：`tmp/playtest-20260526-133230-balanced-wave6-from3.md`
  - wave 9→12：`tmp/playtest-20260526-133428-v77-balanced-wave12-from9.md`
  - wave 12 直跑：`tmp/playtest-20260526-133632-v77-balanced-wave12-direct.md`
- 注意：本轮仍是简单自动驾驶 / 专用测试构筑记录，不等同人工完整通关。

### 结果摘要

| 记录 | 结果 | 关键观察 |
| --- | --- | --- |
| baseline run1 wave 1→3 | 死亡于 wave 3 | wave 1/2 可清，wave 2 后满血但护盾仅 `23/36`。 |
| baseline run2 wave 1→3 | 抵达 wave 3 后商店 | wave 3 结束仅 `33/76` 生命、`0/36` 护盾，属于低容错通过。 |
| baseline run3 wave 1→3 | 死亡于 wave 3 | wave 2 后 `68/76` 生命、`0/36` 护盾，仍死于第一 Boss。 |
| balanced wave 3→6 | 抵达 wave 6 后商店 | Boss/清场主链路可用，强构筑全程满状态。 |
| balanced wave 9→12 | 420 秒模拟中止 | 不再 stack overflow；wave 9/10/11 可过，但连跑到 wave 12 前节奏拖长。 |
| balanced wave 12 直跑 | 抵达 wave 12 后商店 | wave 12 Boss 可击破，说明第四 Boss 本体不是绝对断点。 |

### 修复记录

- 发现并修复电弧链式伤害递归：二段/链式电弧伤害传入 `statusChance=0` 时，旧逻辑仍叠加玩家元素附着概率，可能继续触发跳电并导致 stack overflow。
- v77 起显式 `statusChance <= 0` 直接禁用异常附着，保留主武器自然附着。

### 结论

- 当前不能判定“难度/玩法已经 ok”。
- 早期自然构筑在第一 Boss 附近仍偏硬：3 轮只有 1 轮通过，且通过样本血盾余量低。
- 中后期强构筑主链路可用，但 wave 9→12 连跑出现节奏拖长，需要半人工验证真实击杀效率和购买决策。
- 暂不做玩法结构或数值大改；建议下一步先讨论小幅早期保底/第一 Boss 门槛调整方案。


## 2026-05-26 19:43 CST · v2026.05.26.76 自动记录复核

### 范围

- baseline 自动驾驶：目标 wave 3，记录文件 `tmp/playtest-v76-baseline-wave3.md`。
- `balanced` 测试构筑：从 wave 3 起跑到 wave 4，记录文件 `tmp/playtest-v76-balanced-wave3-240.md`。
- 注意：本轮仍是简单自动驾驶 / 专用测试构筑记录，不等同人工完整通关。

### 结果摘要

| 记录 | 结果 | 关键观察 |
| --- | --- | --- |
| baseline wave 1→3 | 死亡于 wave 3 | wave 1/2 可清；wave 1 结束护盾仅 `2/36`，wave 2 回满；第一 Boss 前自然构筑仍存在断点信号。 |
| balanced wave 3→4 | 抵达 wave 4 后商店 | wave 3 Boss 击破；wave 4 敌群清完；说明 Boss/清场链路没断，但这是强测试构筑，不代表普通玩家手感。 |

### 结论

- 视觉小修和 Boss 安全边距调整没有破坏自动记录链路。
- 当前最重要的玩法风险仍是：自然构筑在第一 Boss 前后的压力门槛，而不是 Boss 机制完全不可击破。
- 暂不做数值改动；需要人工或半人工记录购买决策、死亡原因和 Boss 击破时间后再调。

## 2026-05-23 14:11 CST · v2026.05.23.53 基线

### 范围

- 采集波次：wave 1 / 3 / 6 / 9 / 12
- 采集内容：战斗截图、商店截图、配置数值快照
- 关键配置：
  - 初始材料：100
  - 难度目标：30 小关完整通关
  - 补给转轮：可花材料持续投资

## 数值快照

| Wave | 节点 | 敌血倍率 | 敌伤倍率 | 速度倍率 | 刷怪间隔倍率 | 通关材料 | 转轮付费成本（第1/第3次） | 模块倍率 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 普通 | ×1.00 | ×1.00 | ×1.00 | ×1.00 | 13 | 8 / 12 | ×1.00 |
| 3 | Boss | ×1.09 | ×1.06 | ×1.01 | ×0.99 | 16 | 10 / 14 | ×1.11 |
| 6 | Boss | ×1.30 | ×1.19 | ×1.03 | ×0.96 | 21 | 13 / 17 | ×1.27 |
| 9 | Boss | ×1.49 | ×1.30 | ×1.04 | ×0.93 | 25 | 16 / 20 | ×1.44 |
| 12 | Boss | ×1.66 | ×1.40 | ×1.06 | ×0.90 | 30 | 19 / 23 | ×1.60 |

## 视觉 / UX 验收

| Wave | 战斗观察 | 商店观察 | 阻塞 |
| --- | --- | --- | --- |
| 1 | HUD 完整，生命/护盾/材料/倒计时/威胁信息可读。 | 当前材料 100，可购买状态清楚。 | 无 |
| 3 | Boss HUD 正常，主目标和 Boss 状态可读。 | Lv.3 商品、价格、可购买状态明确。 | 无 |
| 6 | Boss 压场时仍未遮挡 HUD。 | Lv.6 词条较多但未溢出，绿色购买按钮清楚。 | 无 |
| 9 | 顶部信息密度偏高但未崩坏。 | Lv.9 商品、稀有度、价格、锁货状态清楚。 | 无 |
| 12 | 后期商店排版稳定。 | Lv.12、价格、可购买状态可辨识；当前构筑面板无错位。 | 无 |

## 结论

- **当前半自动基线可通过**：wave 1/3/6/9/12 的战斗与商店 UI 没有阻塞级崩坏。
- **经济方向符合当前目标**：wave 12 的转轮付费成本为 19/23，低于约 30 的通关材料收入，仍适合作为持续投资入口。
- **难度曲线仍需真实游玩验证**：半自动截图只能证明 UI 与配置快照合理，不能证明玩家手感、击杀效率、Boss 实际击破时间或死亡率。

## 后续建议

1. 做一次人工完整跑局，至少记录 wave 1/3/6/9/12 的实际击杀、剩余血量、材料、购买决策。
2. 后续若发现 wave 9/12 必须靠特定武器才稳，再检查商店武器权重或敌人护盾/装甲比例。
3. Boss 战顶部信息略密，但不阻塞；若后续继续 UI 打磨，可单独优化 Boss 状态栏层级。
