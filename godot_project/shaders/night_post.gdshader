shader_type canvas_item;
// night_post.gdshader — 夜潜后处理：冷调分级 + 暴风雪雾 + 暗角 + 胶片颗粒 + 失温霜边 + 警报红边。
// 色彩脚本 A「暴风雪青灰」：除点睛色外压饱和度；暗部推向 #0b0f14 焦油黑。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D fog_tex : repeat_enable, filter_linear;
uniform vec2 cam_offset = vec2(0.0);
uniform float fog_amount = 0.16;
uniform float vignette = 0.62;
uniform float grain = 0.045;
uniform float desat = 0.18;
uniform float frost = 0.0;
uniform float alarm = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// 保留高饱和点睛色（火光/CRT/探照灯）：越亮越不去饱和
	c = mix(vec3(l), c, 1.0 - desat * (1.0 - smoothstep(0.35, 0.8, l)));
	// 冷调：暗部偏蓝，亮部略暖
	c = mix(c * vec3(0.86, 0.95, 1.12), c, smoothstep(0.15, 0.7, l));
	c = mix(vec3(0.043, 0.059, 0.078), c, smoothstep(-0.02, 0.18, l) * 0.35 + 0.65);

	// 世界坐标锚定的雪雾（随风漂移）
	vec2 px = FRAGCOORD.xy + cam_offset;
	float f1 = texture(fog_tex, px / 1400.0 + TIME * vec2(0.018, 0.006)).r;
	float f2 = texture(fog_tex, px / 620.0 + TIME * vec2(0.045, 0.012)).r;
	float fog = smoothstep(0.35, 0.95, f1 * 0.6 + f2 * 0.4);
	c += vec3(0.55, 0.62, 0.72) * fog * fog_amount;

	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	c *= mix(1.0 - vignette, 1.0, smoothstep(0.82, 0.22, r));

	// 失温：屏幕边缘结霜
	float fr = smoothstep(0.55 - frost * 0.3, 0.8, r + (f2 - 0.5) * 0.12) * frost;
	c = mix(c, vec3(0.78, 0.88, 0.96), fr * 0.55);
	// 警报：红边脉冲
	float al = alarm * (0.6 + 0.4 * sin(TIME * 9.0)) * smoothstep(0.35, 0.85, r);
	c = mix(c, vec3(0.75, 0.12, 0.14), al * 0.45);

	c += (hash(FRAGCOORD.xy + fract(TIME * 13.0) * 100.0) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
