shader_type canvas_item;
// night_post.gdshader — 夜潜后处理：冷调分级 + 暴风雪雾 + 暗角 + 胶片颗粒 + 失温霜边 + 警报红边 + 天亮渐变。
// 色彩脚本 A「暴风雪青灰」（dawn = 0）：除点睛色外压饱和度；暗部推向 #0b0f14 焦油黑。
// 色彩脚本 B「黎明前」（dawn → 1，夜长最后 20%）：冷调退回中性、曝光抬升、北侧天际泛暖、
//   雾与暗角变薄、失温霜边化掉 —— 天亮了，但你还没回到锅炉房通风口。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D fog_tex : repeat_enable, filter_linear;
uniform vec2 cam_offset = vec2(0.0);
uniform float fog_amount = 0.16;
uniform float vignette = 0.62;
uniform float grain = 0.045;
uniform float desat = 0.18;
uniform float frost = 0.0;
uniform float alarm = 0.0;
// 天亮进度 0..1：NightExplore.dawn_grade()（夜长最后 DAWN_WINDOW=20% 内 0→1，已做 smoothstep 缓动）
uniform float dawn = 0.0;
uniform vec3 dawn_tint = vec3(1.0, 0.66, 0.42);   // 黎明暖光：钠灯之外第一种不是人造的暖色
uniform float dawn_gain = 0.62;                   // 天亮时的最大曝光抬升
uniform float dawn_sky = 0.10;                    // 天际线高度（屏幕坐标，0=顶）：暖光从这里漏进来

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float dn = clamp(dawn, 0.0, 1.0);
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// 保留高饱和点睛色（火光/CRT/探照灯）：越亮越不去饱和；天亮时整体去饱和减弱（颜色回来了）
	float ds = desat * (1.0 - 0.7 * dn);
	c = mix(vec3(l), c, 1.0 - ds * (1.0 - smoothstep(0.35, 0.8, l)));
	// 冷调：暗部偏蓝，亮部略暖 → 天亮时冷调退回中性偏暖
	vec3 cool_tint = mix(vec3(0.86, 0.95, 1.12), vec3(1.04, 0.99, 0.92), dn);
	c = mix(c * cool_tint, c, smoothstep(0.15, 0.7, l));
	// 焦油黑的暗部托底：天亮时被青灰抬起（雪面不再吃光）
	vec3 ink_floor = mix(vec3(0.043, 0.059, 0.078), vec3(0.149, 0.145, 0.145), dn);
	c = mix(ink_floor, c, smoothstep(-0.02, 0.18, l) * (0.35 - 0.2 * dn) + 0.65);

	// 世界坐标锚定的雪雾（随风漂移）；天亮雾变薄、转暖
	vec2 px = FRAGCOORD.xy + cam_offset;
	float f1 = texture(fog_tex, px / 1400.0 + TIME * vec2(0.018, 0.006)).r;
	float f2 = texture(fog_tex, px / 620.0 + TIME * vec2(0.045, 0.012)).r;
	float fog = smoothstep(0.35, 0.95, f1 * 0.6 + f2 * 0.4);
	vec3 fog_col = mix(vec3(0.55, 0.62, 0.72), vec3(0.86, 0.74, 0.63), dn);
	c += fog_col * fog * fog_amount * (1.0 - 0.45 * dn);

	// 天亮：曝光抬升 + 天光。上方（北 / 远处楼际线）抬得更多，像光从楼顶漏下来。
	float sky = smoothstep(0.95, dawn_sky, SCREEN_UV.y);
	c *= 1.0 + dn * dawn_gain * (0.42 + 0.58 * sky);
	c += dawn_tint * dn * (0.03 + 0.12 * sky);
	// 东天际线：贴着楼顶的一条暖边（黎明前最亮的那 10 分钟）
	c += dawn_tint * dn * smoothstep(0.30, 0.0, SCREEN_UV.y) * 0.14;

	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	// 暗角随天亮松开
	c *= mix(1.0 - vignette * (1.0 - 0.55 * dn), 1.0, smoothstep(0.82, 0.22, r));

	// 失温：屏幕边缘结霜（天亮化霜 —— 但你还是得回锅炉房）
	float fr = smoothstep(0.55 - frost * 0.3, 0.8, r + (f2 - 0.5) * 0.12) * frost * (1.0 - 0.9 * dn);
	c = mix(c, vec3(0.78, 0.88, 0.96), fr * 0.55);
	// 警报：红边脉冲
	float al = alarm * (0.6 + 0.4 * sin(TIME * 9.0)) * smoothstep(0.35, 0.85, r);
	c = mix(c, vec3(0.75, 0.12, 0.14), al * 0.45);

	c += (hash(FRAGCOORD.xy + fract(TIME * 13.0) * 100.0) - 0.5) * grain * (1.0 - 0.35 * dn);
	COLOR = vec4(c, 1.0);
}
