# Debug Overlay 使用说明

这份文档说明当前迁移版中的两套调试显示：

- `DebugOverlay.gd`：按 `F1` 打开的左上角 HUD 文本面板。
- `WorldDebugDrawer.gd`：按 `F2` 打开的世界空间调试绘制层。

当前项目已经从 TileMap 迁移到 Piece/Socket 世界，因此调试信息也围绕 **chunk、piece、socket、seam** 展开。

---

## 快捷键

| 按键 | 作用 |
| --- | --- |
| `F1` | 显示/隐藏左上角 Debug HUD |
| `F2` | 显示/隐藏世界调试绘制层 |
| `F3` | 使用当前 seed 重新生成世界 |
| `F4` | 切换到下一个 seed 并重新生成 |
| `WASD` / 方向键 | 移动玩家/摄像机锚点 |
| `+` / `-` | 缩放视图 |

---

## F1：左上角 Debug HUD 怎么看

HUD 主要用来查看当前玩家所在 chunk 的结构状态。

### World 行

示例：

```text
Seed 12345  ·  Loaded 49  ·  Radius 3
Player chunk (0, 1)  ·  Renderer PieceImage  ·  Unit 128px x 4
```

含义：

| 字段 | 含义 |
| --- | --- |
| `Seed` | 当前世界种子 |
| `Loaded` | 当前已加载 chunk 数量 |
| `Radius` | chunk streaming 加载半径 |
| `Player chunk` | 玩家/摄像机当前所在 chunk 坐标 |
| `Renderer` | 当前地形渲染路径，迁移后应为 `PieceImage` |
| `Unit 128px x 4` | 每个 piece unit 为 128px，每个 chunk 每边 4 个 socket slot |

---

### Chunk 行

示例：

```text
Biome mine  ·  Type MAIN_PATH  ·  Open sides 2  ·  Conn 2
Expected: T SSSS  R smSS  B SSSS  L smSS
Actual:   T SSSS  R smSS  B SSSS  L smSS
Tags main_path
```

重点看 `Expected` 和 `Actual`。

| 字段 | 含义 |
| --- | --- |
| `Biome` | 当前 chunk 所属 biome |
| `Type` | 当前 chunk 的宏观结构类型，例如主路、洞穴、分支、特殊房间等 |
| `Open sides` | 这个 chunk 有多少条边被规划为可连接 |
| `Conn` | 世界结构规划希望这个 chunk 连接到多少个邻居 |
| `Expected` | `WorldSeamRegistry` 规定的权威 socket profile |
| `Actual` | 当前 chunk 实际由 piece/glue 生成出来的边缘 socket profile |
| `Tags` | 世界结构标签，例如 main path、branch、chamber 等 |

`Expected` 和 `Actual` 正常情况下应该一致。若不一致，说明当前 chunk 的边缘没有满足全局 seam 要求。

---

### Socket 字符含义

每条边有 4 个 socket slot，对应 4 个 128px piece unit。

| 字符 | Socket | 含义 | 典型颜色 |
| --- | --- | --- | --- |
| `S` | `SOLID` | 封闭实体边，不应连通 | 半透明白 / 灰白 |
| `s` | `OPEN_SMALL` | 小开口 | 绿色 |
| `d` | `DOUBLE_OPEN_SMALL` | 双小开口 | 浅蓝 |
| `m` | `OPEN_MEDIUM` | 中开口 | 青绿色 |
| `L` | `OPEN_LARGE` | 大开口 | 黄色 |
| `?` | `ANY` | 通配 socket，通常会在 seam registry 中被具体化 | 白色 |

示例：

```text
Right: smSS
```

表示右边 4 个 slot 从上到下分别是：

```text
slot 0 = open_small
slot 1 = open_medium
slot 2 = solid
slot 3 = solid
```

---

### Stats 行

示例：

```text
Regular pieces 12  ·  Open sockets 8  ·  Glue 3
Air units 5  ·  Placements 16  ·  Special loaded 1
Chambers 0  ·  Seam repairs 1  ·  Seam broken E/N 0/0
```

| 字段 | 含义 |
| --- | --- |
| `Regular pieces` | 普通 piece 数量 |
| `Open sockets` | 当前 chunk 中参与连通的开放 socket 数量 |
| `Glue` | glue piece 数量 |
| `Air units` | 空气/空白 unit 统计 |
| `Placements` | 当前 chunk 内 piece placement 总数 |
| `Special loaded` | 已加载 special chunk 数量 |
| `Chambers` | 当前 world structure 中的 chamber 数量 |
| `Seam repairs` | seam repair 发生次数 |
| `Seam broken E/N` | seam 检查错误数：`E = expected-vs-actual`，`N = neighbor actual-vs-actual` |

`Seam broken E/N` 是最重要的健康指标：

- `E > 0`：当前 chunk 自己没有满足 canonical seam。
- `N > 0`：当前 chunk 与已加载邻居的实际边缘不一致。
- 理想状态是 `0/0`。

---

## F2：世界调试绘制层怎么看

世界调试层直接画在世界空间中，用来观察 chunk、piece、socket 和 seam 问题。

---

## Socket Marker：新的空心圆/实心点规则

当前版本已经取消“每个 slot 两个分离圆点”的显示方式，改为一个组合 marker：

```text
空心圆 / 外圈 = Expected socket
实心圆 / 内点 = Actual socket
```

也就是说，同一个 socket slot 现在只占一个位置：

- 外圈颜色代表 `WorldSeamRegistry` 要求这里是什么。
- 内点颜色代表实际生成结果是什么。
- 所有 socket 类型都使用统一 marker 尺寸：外圈半径固定，内点半径固定。
- 大小不再表达 socket 类型；socket 类型只通过颜色和 HUD 字符表达。

### 如何判断是否正常

| 看到的情况 | 含义 |
| --- | --- |
| 外圈和内点颜色一致 | expected 与 actual 一致，正常 |
| 外圈是绿色，内点是灰白 | 规划要求开口，但实际生成成了 solid，严重问题 |
| 外圈是灰白，内点是绿色/青色/黄色 | 规划要求封闭，但实际 piece 开了口 |
| 外圈和内点都是开放类但颜色不同 | 逻辑不一致，例如 small/medium 差异；chunk 外边界应修正到完全一致 |
| 出现红色边缘条 | 该 slot 的 expected 与 actual 不一致 |

---

## Socket Marker 尺寸说明

| 形状 | 表示 | 尺寸规则 |
| --- | --- | --- |
| 空心外圈 | `Expected` / canonical socket | 所有 socket 类型固定同一半径 |
| 实心内点 | `Actual` / 实际生成 socket | 所有 socket 类型固定同一半径 |

大小只用于区分“外圈”和“内点”两层含义，不再用于区分 `open_small`、`open_medium`、`open_large` 等类型。类型统一看颜色或 F1 HUD 的 socket 字符。

---

## Socket Marker 颜色说明

| 颜色 | Socket | 用途 |
| --- | --- | --- |
| 半透明白 / 灰白 | `SOLID` | 封闭边缘；正常情况下不应与开放 socket 连接 |
| 绿色 | `OPEN_SMALL` | 小型通道入口 |
| 浅蓝 | `DOUBLE_OPEN_SMALL` | 两个小入口；目前兼容性更严格，通常需要精确匹配 |
| 青绿色 | `OPEN_MEDIUM` | 中型通道入口 |
| 黄色 | `OPEN_LARGE` | 大型通道入口 |
| 白色 | `ANY` | 通配/未具体化，正常 world seam 中应较少出现 |
| 红色半透明边缘条 | mismatch | `expected != actual`，需要检查 piece 选择、glue 修复或 authored piece socket 标注 |

---

## Chunk 边框颜色说明

`WorldDebugDrawer` 会给不同 chunk 类型画不同颜色的边框/底色：

| 颜色 | Chunk 类型 | 含义 |
| --- | --- | --- |
| 青蓝 | `MAIN_PATH` | 主路径 chunk |
| 绿色 | `CAVE` | 普通洞穴 chunk |
| 黄色 | `BRANCH` | 分支路径 chunk |
| 青绿加粗 | `CHAMBER` | chamber/大型结构区域 |
| 灰色 | `SOLID` | 实心或不参与通路的 chunk |
| 粉紫色 | `SPECIAL` | special chunk 或特殊结构 |

Special chunk 额外会有粉紫色的大矩形框，表示它覆盖的 chunk 范围。

---

## Piece 边框颜色说明

当 `show_piece_bounds` 开启时，每个 placement 会被画出边框：

| 颜色 | Phase | 含义 |
| --- | --- | --- |
| 红色 | `anchor` | anchor piece，通常是 chunk 内的关键结构起点 |
| 绿色 | `regular` | 普通 piece |
| 橙色 | `glue` | glue piece，用于补缝、补洞、衔接局部空间 |
| 高亮红色 | `seam_repair` | seam 修复用 glue。若频繁出现，说明 piece 库或 socket 声明需要优化 |
| 灰色 | 其他 | 未分类/后备 placement |

---

## 推荐排查流程

当你看到某条 chunk 边界不自然或断开时，按这个顺序看：

1. 打开 `F2`，看对应 slot 是否有红色边缘条。
2. 看 marker 外圈颜色：这是全局 seam 要求。
3. 看 marker 内点颜色：这是实际 piece/glue 结果。
4. 如果外圈与内点不同，再看左上角 HUD 的 `Expected` / `Actual` 字符串确认是哪一边、哪个 slot。
5. 如果 HUD 里 `Seam broken E/N` 不是 `0/0`，优先排查该 chunk 的边缘 piece。
6. 如果外圈和内点一致但视觉仍然不对，说明 `PieceDef` 的 socket 声明可能和图片内容不一致，需要检查 authored piece 资源本身。

---

## 当前调试目标

理想情况下，普通相邻 chunk 应满足：

```text
left_chunk.actual_right_profile == right_chunk.actual_left_profile
upper_chunk.actual_bottom_profile == lower_chunk.actual_top_profile
```

同时，每个 chunk 自己也应满足：

```text
expected_top/right/bottom/left == actual_top/right/bottom/left
```

如果这两条都成立，socket/seam 层基本健康；后续问题就更可能来自 piece 图片内容、连通性 flood fill、碰撞生成或材料模拟层。
