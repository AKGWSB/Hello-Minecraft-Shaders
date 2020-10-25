**完整资源：**

 [我的Github地址](https://github.com/AKGWSB/Hello-Minecraft-Shaders/tree/master)

**前情提要：**

[从0开始编写minecraft光影包（0）GLSL，坐标系，光影包结构介绍](https://blog.csdn.net/weixin_44176696/article/details/108152896)

[从零开始编写minecraft光影包（1）基础阴影绘制](https://blog.csdn.net/weixin_44176696/article/details/108625077)

[从零开始编写minecraft光影包（2）阴影优化](https://blog.csdn.net/weixin_44176696/article/details/108637819)

[从零开始编写minecraft光影包（3）基础泛光绘制](https://blog.csdn.net/weixin_44176696/article/details/108672719)

[从零开始编写minecraft光影包（4）泛光性能与品质优化](https://blog.csdn.net/weixin_44176696/article/details/108692525)


@[TOC](目录)

# 前言
国庆放假摸鱼好久了。。。今天来更新一下罢

上次讲到实现了更好品质的泛光，可是因为mc的光照系统过于蛋疼，还是存在种种问题。今天来解决其他的问题。

> 注：这部分的内容基于[上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108692525)中【对低分辨率纹理进行模糊】小节的代码

# 光照系统

光照是着色器面临的重要部分。一个好的光照系统能够让着色器画面更加逼真。在上一篇的着色器中，我们虽然解决了泛光的问题，但是仍然存在很多潜在的问题：


首先是光源方块也会被染上阴影

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003142425828.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

因为阴影的关系，暗处的方块颜色会非常暗：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003142807677.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

而夜间则会显得非常亮，尤其是人造光源的亮度和太阳的亮度相等，这是有违常识的：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003143413862.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

所以我们迫切需要改写mc的光照系统。我们将光照简单的分为两种类型：

1. 自然环境光，由太阳和月亮提供
2. 人造光源照明，由玩家放置的方块提供

发光物体确定后，我们需要明确光照的几条规则：

1. 自然环境光的强度远大于人造光源的照明强度
2. 夜间的时候，自然环境光的强度应该减少。
3. 当自然光和人造光源都存在时，取最大的一方作为最终光照的结果

所以我们需要修改 gbuffers_terrain 着色器，我们需要重新计算光照。

还记得顶点着色器中的光照纹理坐标🐎？

```
lightMapCoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;   
```

其中 lightMapCoord  的 x 轴表示人造光源的强度，y 轴表示自然光源的强度。如果我们在 gbuffers_terrain 着色器直接输出他们的 x 或 y 坐标，那么会有如下的结果：

```
blockColor.rgb = vec3(lightMapCoord.x);

or 
 
blockColor.rgb = vec3(lightMapCoord.y);
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003150702970.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
所以我们需要修改 gbuffers_terrain.fsh 的内容，实现昼夜光照的变化，以及人造光源和自然光源的混合。将 gbuffers_terrain.fsh 修改为：

```
#version 120

// 声明2号颜色缓冲区为 R32F 格式 只有x通道可用 传递方块id
const int R32F = 114;
const int colortex2Format = R32F;

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform int worldTime;

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec3 color;
varying float blockId;

/* DRAWBUFFERS:023 */
void main() {

    // 昼夜交替插值
    float isNight = 0;  // 白天
    if(12000<worldTime && worldTime<13000) {
        isNight = 1.0 - (13000-worldTime) / 1000.0; // 傍晚
    }
    else if(13000<=worldTime && worldTime<=23000) {
        isNight = 1;    // 晚上
    }
    else if(23000<worldTime) {
        isNight = (24000-worldTime) / 1000.0;   // 拂晓
    }

    // 纹理 * 颜色
    vec4 blockColor = texture2D(texture, texcoord.st);
    blockColor.rgb *= color;

    // 人造光源光照
    float lightTorch = lightMapCoord.x * 0.4;
    // 如果是发光物体则不受光照影响
    if(blockId>=10089) {
        lightTorch /= 0.4;
    }
    // 环境光照
    float lightSky = lightMapCoord.y;
    lightSky = pow(lightSky, 2);
    lightSky *= (1-isNight*0.8);   // 夜晚则减弱
    // 光照混合--取最大值
    blockColor.rgb *= max(lightTorch, lightSky);

    gl_FragData[0] = blockColor;
    gl_FragData[1] = vec4(blockId);
    gl_FragData[2] = vec4(isNight, 0, 0, 0);
}
```

我们做了如下的改动：

1. 计算昼夜交替的平滑过渡值 isNight。如果是夜晚，那么这个值为1，否则为0。在昼夜交替的时候，isNight会根据当前世界的世界 worldTime 进行平滑过渡
2. 然后我们获取人造光源的强度，即 lightMapCoord.x ，随后我们减弱人造光源的光照强度即乘以0.4.但是如果是发光方块，我们照常绘制它的颜色
3. 然后我们取得环境光照的强度 lightMapCoord.y，根据昼夜交替值 isNight 对其进行变换。白昼则为正常值，夜间则减弱到原来的0.2倍
4. 将两种光源的强度进行比较，取最大的一方作为最终照明的强度
5. 将 isNight 继续写入 3 号颜色缓冲区，接下来绘制昼夜阴影的时候也会用到这个值，所以保存一下

随后我们小改一下 composite.fsh，我们首先对阴影绘制进行处理。

我们将夜间的阴影淡化，即在getShadow函数中，通过isNight来决定阴影的深度：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003152949589.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


此外，如果为光源方块，则不对其绘制阴影。我们对main函数中的阴影绘制代码进行修改：

```
// 不是发光方块则绘制阴影
float id = texture2D(colortex2, texcoord.st).x;
if(id!=10089 && id!=10090) {
    color = getShadow(color, positionInWorldCoord);
}
```



此外，我们编写一个函数，根据方块id来决定是否为光源方块，并且传递泛光的原始图像。

```
/*
 *  @function getBloomSource : 获取泛光原始图像
 *  @param color             : 原图像
 *  @return                  : 提取后的泛光图像
 */
vec4 getBloomSource(vec4 color) {
    // 绘制泛光
    vec4 bloom = color;
    float id = texture2D(colortex2, texcoord.st).x;
    float brightness = dot(bloom.rgb, vec3(0.2125, 0.7154, 0.0721));
    // 发光方块
    if(id==10089) {
        bloom.rgb *= 7 * vec3(2, 1, 1);
    }
    // 火把 
    else if(id==10090) {
        if(brightness<0.5) {
            bloom.rgb = vec3(0);
        }
        bloom.rgb *= 14 * pow(brightness, 2);
    }
    // 其他方块
    else {
        bloom.rgb *= brightness;
        bloom.rgb = pow(bloom.rgb, vec3(1.0/2.2));
    }
    return bloom;
}
```

然后修改 composite.fsh 的main函数，将泛光的原始图像传递到 1 号颜色缓冲区：

```
gl_FragData[1] = getBloomSource(color); // 传递泛光原图
```

现在我们有了更为逼真的光照效果，即人造光源，昼夜光照，阴影的协调。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003153154432.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 曝光调节

光照的问题解决了，可是又有了新的问题，因为阴影的关系，加上我们为了在露天场景下使得光照更为真实而削减了人造光源的强度，在封闭的室内场景，颜色非常暗：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003153722652.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

在现实场景中，在阴暗的室内，摄像机会增大光圈，使得整体的亮度提高，而在室外明亮场景，则会缩小光圈，让画面能够适应强光。我们希望实现这个特效。

查阅[Optifine的文档](https://github.com/sp614x/optifine/blob/master/OptiFineDoc/doc/shaders.txt)发现有 eyeBrightness 和 eyeBrightnessSmooth 两个变量：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003154153260.png#pic_center)

该变量代表了**玩家所在位置**的光照亮度，其中 x 轴是人造光源的强度，y 轴是自然光源的强度。光照的值范围 [0~240] 对应 16 个光照强度。

这意味着我们可以通过 y 轴（即自然光源的强度）来判断当前处于室内还是室外。如果是室内我们则增亮（乘以一个大于1的数字），室外则恢复到原来的水平（1.0）。

我们在 final.fsh 中加入如下的函数：

```
/*
 *  @function exposure : 曝光调节
 *  @param color       : 原颜色
 *  @param factor      : 调整因子 范围 0~1
 *  @explain           : factor越大则暗处越亮
 */ 
vec3 exposure(vec3 color, float factor) {
    float skylight = float(eyeBrightnessSmooth.y)/240;
    skylight = pow(skylight, 6.0) * factor + (1.0f-factor);
    return color / skylight;
}
```

然后在 final.fsh 的main函数中加入：

```
// 曝光调节
color.rgb = exposure(color.rgb, 0.7);
```

重新加载光影包，我们发现现在室内基本能够看清了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003154858651.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

并且从昏暗的室内走向室外，可以体验到非常睾大上的曝光调节过程：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003155405828.gif#pic_center)

# ToneMapping

解决了曝光调节之后，又有了新的问题。因为曝光调节在室内（或者环境光强度不够的地方）会提高亮，故度室内亮度过亮，光源方块直接超亮了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003160414279.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

过亮的图片造成的后果是细节的缺失，我们需要一种算法，能够将亮的图像和暗的图像综合一下，还原亮处的细节，这种算法叫做ToneMapping。

Tonemapping又名色调映射。意在通过一定的映射方式，将亮和暗的像素中和，从高亮图片中还原图像的细节。ToneMapping通过一种函数，将像素的亮度由线性变为非线性：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003161224826.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
这么做的目的就是**将高亮像素和低亮度像素，向中等亮度的区域压缩**，以还原更多的细节。

ToneMapping算法的不同，在于其曲线的不同，一般曲线通过多项式拟合即可。故直接选取比较现成的ToneMapping算法，来自这篇文章：

[Tone mapping进化论](https://zhuanlan.zhihu.com/p/21983679)

我们直接copy ACES ToneMapping 的算法：

```
/*
 *  @function ACESToneMapping : 色调映射
 *  @param color              : 原颜色
 *  @param adapted_lum        : 亮度调整因子
 *  @return                   : 色调映射之后的值
 *  @explain                  : 感谢知乎大佬：@叛逆者
 *                            : 源码地址 https://zhuanlan.zhihu.com/p/21983679
 */
vec3 ACESToneMapping(vec3 color, float adapted_lum) {
	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
	color *= adapted_lum;
	return (color * (A * color + B)) / (color * (C * color + D) + E);
}
```

然后我们修改 final.fsh ，在计算曝光调节之后，加上一行：

```
// 色调映射
color.rgb = ACESToneMapping(color.rgb, 1);
```

重新加载光影包，现在可以看看效果力：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003162151544.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
可以看到效果还是非常给力的。。。感谢知乎大佬的讲解 Orz

# 饱和度与滤镜

在进行色调映射后，还有一个小问题：图像的颜色不够鲜艳了，这是因为ToneMapping把所有本不鲜艳的颜色，压缩到中间区间，导致颜色灰头土脸的，所以我们需要增加一个滤镜，手动调节图像的饱和度。

> 什么是饱和度呢？饱和度描述了图像颜色的丰富程度，即 RGB 值越 “离散” ，图像饱和度越高。
> 参考自 - - - [公式剖析色彩三要素：色相、饱和度、明度](https://zhuanlan.zhihu.com/p/30409532)


关于RGB颜色空间下饱和度的调节，~~直接抄公式即可~~ ，

> ![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003172301526.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
> 
> 参考自：[亮度，饱和度，对比度的计算方法](https://blog.csdn.net/gaowebber/article/details/79829962)

具体步骤：

1. 计算像素亮度
2. 将像素亮度作为灰度值，和原像素值进行线性混合

其中伪代码为：

```
newRGB = oldRGB * alpha + brightness * (1 - alpha)
```

其中 alpha 为饱和度系数，0表示完全灰色，0-1表示降低饱和度，1表示原图，**超过1表示增加饱和度。**

所以我们编写一个函数，调整颜色的饱和度：

```
/*
 *  @function saturation : 饱和度调整
 *  @param color         : 原颜色
 *  @param factor        : 调整因子范围 [0~无穷] 饱和度升高
 */ 
vec3 saturation(vec3 color, float factor) {
    float brightness = dot(color, vec3(0.2125, 0.7154, 0.0721));
    return mix(vec3(brightness), color, factor);
}
```

在 final.fsh 中，计算tonemapping之后，加入：

```
// 饱和度
color.rgb = saturation(color.rgb, 1.5);
```

使用不同的饱和度系数（即公式中的 alpha），可以调节不同的效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003172855495.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

最终使用 1.5 作为系数，即可达到不错的效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003173245317.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003173542732.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003173659555.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201003174644995.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


