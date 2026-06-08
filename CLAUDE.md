# Desk Clawd — CLAUDE.md

## GitHub 推送注意事项

### 首次推送 / 推送失败时

```bash
git remote add origin https://Ginger-Hao:ghp_你的token@github.com/Ginger-Hao/desk-clawd.git
git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=http://127.0.0.1:7890 push -u origin main
```

- 必须**开梯子**（flclash 端口 7890）
- 用 `-c` 参数临时指定代理，不写进全局配置
- Personal Access Token 在 GitHub → Settings → Developer Settings → Personal access tokens → Tokens (classic) 生成，勾选 `repo` 权限
- 如 remote 已存在，先 `git remote remove origin` 再 add

### 常见错误

| 错误 | 原因 | 解决 |
|------|------|------|
| `403 denied to Ginger-Hao` | Windows 凭据管理器缓存了错误的账号 | 用 Token 内嵌 URL |
| `Connection was reset` | 网络被重置 | 开梯子，用 `-c http.proxy` |
| `Failed to connect to github.com port 443` | 直连不通 | 开梯子 |
| `Permission denied (publickey)` | SSH key 未配置 | 用 HTTPS + Token 方式 |

## 项目结构

```
desk-clawd/
├── firmware/desk-clawd/desk-clawd.ino   # 主固件
├── models/case/                          # 3D 打印外壳
├── models/clawd-figure/                  # Clawd 玩偶
├── pics/                                 # 图片素材
├── scripts/find-esp32.{sh,ps1}          # IP 检测脚本
├── secrets.h.example                     # WiFi 配置模板
├── claude-hooks.example.json             # Claude Code hooks 参考
├── README.md                             # 英文说明
├── README.zh.md                          # 中文说明
└── CLAUDE.md                             # 本文件
```

## 硬件引脚

- ST7789 屏幕: CS=4, DC=1, RST=2, BLK=3, MOSI=10, SCK=8
- 红绿灯: 绿灯=GPIO5, 黄灯=GPIO9, 红灯=GPIO20
- 所有 VCC 接 3.3V，GND 串联
- ESP32-C3 无 GPIO 18/19

## 开发板设置

- Board: ESP32C3 Dev Module
- USB CDC On Boot: Enabled
- Upload Speed: 921600
