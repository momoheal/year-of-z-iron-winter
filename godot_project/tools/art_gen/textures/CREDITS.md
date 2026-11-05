# 第三方美术素材来源（CC0）

本目录存放用于**程序化生成管线**的真实材质 albedo 贴图，来源为 **ambientCG**（https://ambientcg.com），
许可 **CC0 1.0 公有领域**——可商用、无需署名、可修改。

| 文件 | 来源 | 用途 |
|------|------|------|
| `Concrete035_Color.jpg` | https://ambientcg.com/a/Concrete035 | 真实混凝土纹理，用于食堂 / 疗养院立面墙面（`Layer.mat_tex`） |
| `Snow014_Color.jpg` | https://ambientcg.com/a/Snow014 | 真实雪纹理，备用（地面细节叠加） |

说明：
- 仅取 **Color（albedo）** 单图做 2D 纹理映射；normal / roughness / displacement 等 PBR 通道未使用。
- `Layer.mat_tex()` 在找不到材质文件时会回退到程序噪声 `Layer.tex()`，因此离线 / CI 环境依然可复现，
  只是墙面纹理退化为噪声版本。
- 选择真实材质而非现成角色 / 建筑 sprite 的原因：现成俯视资源多为纯俯视或 Q 版卡通，
  与本项目 S/E/N 三向侧视、苏联阴暗油画质感的视角与风格均不匹配；真实材质与视角无关，可无缝融入。
