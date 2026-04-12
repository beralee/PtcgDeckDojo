# Battle BGM

- 将你有权使用的内置战斗音乐资源放在这个目录下。
- 然后在 `res://data/battle_music_catalog.json` 中登记这些文件。
- 自定义本地音乐也可放在 `user://custom_bgm/`，游戏会在对战设置页自动扫描。

示例：

```json
{
  "tracks": [
    {
      "id": "battle_custom_01",
      "label": "自定义对战曲 01",
      "path": "res://assets/audio/bgm/battle_custom_01.ogg"
    }
  ]
}
```
