**完整资源：**

 [我的Github地址](https://github.com/AKGWSB/Hello-Minecraft-Shaders/tree/master)

**前情提要：**

[从0开始编写minecraft光影包（0）GLSL，坐标系，光影包结构介绍](https://blog.csdn.net/weixin_44176696/article/details/108152896)

[从零开始编写minecraft光影包（1）基础阴影绘制](https://blog.csdn.net/weixin_44176696/article/details/108625077)

[从零开始编写minecraft光影包（2）阴影优化](https://blog.csdn.net/weixin_44176696/article/details/108637819)

[从零开始编写minecraft光影包（3）基础泛光绘制](https://blog.csdn.net/weixin_44176696/article/details/108672719)

[从零开始编写minecraft光影包（4）泛光性能与品质优化](https://blog.csdn.net/weixin_44176696/article/details/108692525)

[从零开始编写minecraft光影包（5）简单光照系统，曝光调节，色调映射与饱和度](https://blog.csdn.net/weixin_44176696/article/details/108909824)

[从零开始编写minecraft光影包（6）天空绘制](https://blog.csdn.net/weixin_44176696/article/details/108943499)

[从零开始编写minecraft光影包（7）基础水面绘制](https://blog.csdn.net/weixin_44176696/article/details/108951799)

@[TOC](目录)

# 前言

回到学习就不能摸鱼了🐎？还是来更新罢。。。

这次更新一些比较高级的水面特效的绘制，比如焦散，屏幕空间反射等等。。。

# 代码迁移

[上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108951799)我们将水面绘制的代码写在了 gbuffers_water 着色器中，但是这么做有几个不好的地方：

1. 需要重复计算天空颜色
2. 在后续绘制天空漫反射的时候，因为**天空是在 composite 着色器中绘制的**，所以绘制针对天空的漫反射将会变得十分困难
3. 在后续的编程中我们将绘制屏幕空间反射，这一步需要将反射的颜色和基色混合，同样因为水面的绘制在 gbuffers_water 着色器，这使得最后颜色的混合变得十分困难

~~好吧就是我当时写的时候没有考虑清楚，我菜，我爬爬爬 dbq 呜呜呜~~ 

话不多🔒开始动工，我们将水面的基础绘制，迁移到 composite 着色器中进行：

首先将 gbuffers_water 着色器改写。我们首先修改 gbuffers_water.vsh，我们不再计算天空颜色，而是只计算法线，并且计算水面凹凸，施加到顶点上：

```
#version 120

attribute vec2 mc_Entity;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform int worldTime;

varying float id;

varying vec3 normal;

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec4 color;

/*
 *  @function getBump          : 水面凹凸计算
 *  @param positionInViewCoord : 眼坐标系中的坐标
 *  @return                    : 计算凹凸之后的眼坐标
 */
vec4 getBump(vec4 positionInViewCoord) {
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;  // “我的世界坐标”
    positionInWorldCoord.xyz += cameraPosition; // 世界坐标（绝对坐标）

    // 计算凹凸
    positionInWorldCoord.y += sin(float(worldTime*0.3) + positionInWorldCoord.z * 2) * 0.05;

    positionInWorldCoord.xyz -= cameraPosition; // 转回 “我的世界坐标”
    return gbufferModelView * positionInWorldCoord; // 返回眼坐标
}

void main() {
    vec4 positionInViewCoord = gl_ModelViewMatrix * gl_Vertex;   // mv变换计算眼坐
    if(mc_Entity.x == 10091) {  // 如果是水则计算凹凸
        gl_Position = gbufferProjection * getBump(positionInViewCoord);  // p变换
    } else {    // 否则直接传递坐标
        gl_Position = gbufferProjection * positionInViewCoord;  // p变换
    }

    color = gl_Color;   // 基色
    id = mc_Entity.x;   // 方块id
    normal = gl_NormalMatrix * gl_Normal;   // 眼坐标系中的法线
    lightMapCoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;    // 光照纹理坐标
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0; // 纹理坐标
}
```

然后在 gbuffers_water.fsh 中，我们也不计算水面的颜色，取而代之我们直接输出一个颜色即可。值得注意的是我们**将眼坐标下的法线方向传递到四号缓冲区**。

```
#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform vec3 cameraPosition;

uniform int worldTime;

varying float id;

varying vec3 normal;    // 法向量在眼坐标系下

varying vec4 texcoord;
varying vec4 color;
varying vec4 lightMapCoord;

/* DRAWBUFFERS: 04 */
void main() {
    vec4 light = texture2D(lightmap, lightMapCoord.st); // 光照
    if(id!=10091) {
        gl_FragData[0] = color * texture2D(texture, texcoord.st) * light;   // 不是水面则正常绘制纹理
        gl_FragData[1] = vec4(normal*0.5+0.5, 0.5);   // 法线
    } else {    // 是水面则输出 vec3(0.05, 0.2, 0.3)
        gl_FragData[0] = vec4(vec3(0.05, 0.2, 0.3), 0.5) * light;   // 基色
        gl_FragData[1] = vec4(normal*0.5+0.5, 1);   // 法线
    }
}
```

注意最后一位，我们用来做一个掩码，当前方块是水面时，我们输出1，而当前方块是染色玻璃等透明物体时，我们输出 0.5 ，这个值之后会用到。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021171610577.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)



重新加载光影包，现在水面只显示一个颜色了。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201018213651764.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

然后我们修改 composite.fsh 着色器，我们将在其中直接计算水面的纹理。首先添加如下的一致变量：

```
const int noiseTextureResolution = 128;     // 噪声图分辨率
uniform sampler2D colortex4;	// 4号颜色缓冲区
uniform sampler2D noisetex;	// 噪声纹理
uniform vec3 cameraPosition;	// 相机在世界坐标系下的坐标
```

然后添加两个函数，这部分也没啥新意（其实就是把之前的代码copy过来）:

```
/*
 *  @function getWave           : 绘制水面纹理
 *  @param positionInWorldCoord : 世界坐标（绝对坐标）
 *  @return                     : 纹理亮暗系数
 */
float getWave(vec4 positionInWorldCoord) {

    // 小波浪
    float speed1 = float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 3;
    coord1.x += speed1;
    coord1.z += speed1 * 0.2;
    float noise1 = texture2D(noisetex, coord1.xz).x;

    // 混合波浪
    float speed2 = float(worldTime) / (noiseTextureResolution * 7);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.x *= 0.5;
    coord2.x -= speed2 * 0.15 + noise1 * 0.05;  // 加入第一个波浪的噪声
    coord2.z -= speed2 * 0.7 - noise1 * 0.05;
    float noise2 = texture2D(noisetex, coord2.xz).x;

    return noise2 * 0.6 + 0.4;
}

/*
 *  @function drawWater         : 基础水面绘制
 *  @param color                : 原颜色
 *  @param positionInWorldCoord : 我的世界坐标
 *  @param positionInViewCoord  : 眼坐标
 *  @param normal               : 眼坐标系下的法线
 *  @return                     : 绘制水面后的颜色
 *  @explain                    : 因为我太猪B了才会想到在gbuffers_water着色器中绘制水面 导致后续很难继续编程 我爬
 */
vec3 drawWater(vec3 color, vec4 positionInWorldCoord, vec4 positionInViewCoord, vec3 normal) {
    positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）

    // 波浪系数
    float wave = getWave(positionInWorldCoord);
    vec3 finalColor = mySkyColor;
    finalColor *= wave; // 波浪纹理

    // 透射
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));  // 计算视线和法线夹角余弦值
    cosine = clamp(abs(cosine), 0, 1);
    float factor = pow(1.0 - cosine, 4);    // 透射系数
    finalColor = mix(color, finalColor, factor);    // 透射计算

    return finalColor;
}

```

最后在 main 函数中增加：

```
// 基础水面绘制
vec4 temp = texture2D(colortex4, texcoord.st);
vec3 normal = temp.xyz * 2 - 1;
float isWater = temp.w;
if(isWater==1) {
    color.rgb = drawWater(color.rgb, positionInWorldCoord, positionInViewCoord, normal);
}
```

还记得我们在 gbuffers_water.fsh 中传递的法线吗？四号缓冲区！其中最后一位为1，表示这是水面。

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020101821455490.png#pic_center)

> 注：为何法线要乘0.5再加0.5 ？这是因为除了 1 号颜色缓冲，其他的颜色缓冲，格式都是 RGBA8，即 4 个 8 位无符号int，这意味着我们**无法传递负数**。于是我们只能将法向量映射到 0-1 区间再传递。

重新加载光影包，我们实现了和上一篇博客一致的效果。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201018215058859.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)



// ---------------------------------------------------------------------------------------- //

# 水下阴影绘制

> 注：以下特效的绘制基于**上文**【代码迁移】部分完成的着色器

注意到一个细节：我们的阴影绘制，直接绘制在水面上了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009194302679.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
从代码的角度上来说没什么问题，毕竟水面也算一个方块。但是实在是看的很蛋疼。。。

还记得我们是如何通过 shadow mapping 建立阴影绘制的吗？有如下这几个步骤：

1. 通过 **深度缓冲纹理** 建立 ndc坐标，并且变换到世界坐标系
2. 坐标变换到光照坐标系（即太阳视角下的眼坐标）
3. 通过光照坐标系下的点，取出距离太阳最近的点 x 的深度
4. 比对当前像素深度和 x 点的深度，判断是否绘制阴影

其中我们是通过：

```
float depth = texture2D(depthtex0, texcoord.st).x;  
```

采样 depthtex0 纹理来获取深度值并且建立三维的ndc坐标。这个深度纹理是包含水面的，也就是说，将水面视作不透明的方块！

通过查阅 [optfine的文档](https://github.com/sp614x/optifine/blob/master/OptiFineDoc/doc/shaders.txt)，我们发现，depthtex0 是正常的深度缓冲，水面被视作不透明的方块。而 depthtex1 则不包含水面，即将水面视为完全透明的方块。depthtex2 和 depthtex1 类似，只是不包含手持方块。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009194901748.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

图解：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009195349893.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

和深度缓冲类似，我们也需要一块不包含水面的 shadow 纹理。查阅 [optfine的文档](https://github.com/sp614x/optifine/blob/master/OptiFineDoc/doc/shaders.txt)，发现 shadowtex1 满足我们的需求。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009195641648.png#pic_center)

知道原理之后，就可以 ~~开冲！~~ 了

我们修改 composite.fsh 文件，加入两个不包含水面的纹理：

```
uniform sampler2D depthtex1;
uniform sampler2D shadowtex1;
```

然后我们在 main 函数的开头，分别计算两次坐标，其中

1. 以 0 结尾的坐标包含水面方块
2. 以 1 结尾的坐标不包含水面方块

我们将原先的坐标计算改为：

```
// 带水面方块的坐标转换
float depth0 = texture2D(depthtex0, texcoord.st).x;
vec4 positionInNdcCoord0 = vec4(texcoord.st*2-1, depth0*2-1, 1);
vec4 positionInClipCoord0 = gbufferProjectionInverse * positionInNdcCoord0;
vec4 positionInViewCoord0 = vec4(positionInClipCoord0.xyz/positionInClipCoord0.w, 1.0);
vec4 positionInWorldCoord0 = gbufferModelViewInverse * positionInViewCoord0;

// 不带水面方块的坐标转换
float depth1 = texture2D(depthtex1, texcoord.st).x;
vec4 positionInNdcCoord1 = vec4(texcoord.st*2-1, depth1*2-1, 1);
vec4 positionInClipCoord1 = gbufferProjectionInverse * positionInNdcCoord1;
vec4 positionInViewCoord1 = vec4(positionInClipCoord1.xyz/positionInClipCoord1.w, 1.0);
vec4 positionInWorldCoord1 = gbufferModelViewInverse * positionInViewCoord1;
```

图示：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201018225110481.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
然后我们将用到坐标的函数的参数调用稍加修改，其中：

1. 阴影计算**不需要**包含水面的坐标
2. 天空绘制需要包含水面的坐标
3. 水面绘制需要包含水面的坐标

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201018225834774.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


最后还要修改查询 shadow 纹理的代码。我们将 getShadow 函数中，查询 shadow 纹理的部分，将传入 texture2D 的 shadow 变量，改为 shadowtex1 ：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009201819432.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

重新加载光影包，发现此时阴影能够正确的投射到水底了。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201018230020707.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 基于深度的淡出

注意到我们的阴影绘制仍然存在缺陷，比如深水处任然有鲜明的阴影绘制：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201018234623932.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

这是很违和的，所以我们希望对水底的阴影绘制的强度，**随着水深而递减**，这样更加符合真实世界中我们的认知。

那么如何计算一个方块到水面的距离呢？还是依赖于之前提到的两个深度缓冲。利用深度缓冲包含或者不包含水面方块的差异，我们得以计算出该方块到水面的距离：


![在这里插入图片描述](https://img-blog.csdnimg.cn/20201019193019780.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

~~简单的几何学~~ 

现在的问题转变为求 d0 和 d1 了，我们马上想到可以利用深度缓冲中的深度值作为距离，可是问题又来了，深度缓冲中的数值是不可以直接使用的。

因为深度缓冲中的数据不是线性的，这意味着 0.1 可能代表 2 格方块，可是 0.3 就代表着 20 格方块了。

所以我们需要将深度数据线性化，即 0.1 代表 2 格，那么 0.3 就必须代表 6 格。

> 关于深度转换，这两篇文章写的非常好
> 
> [深度缓冲中的深度值计算及可视化](https://zhuanlan.zhihu.com/p/128028758)
> 
> [为什么透视计算的深度是非线性深度](https://www.cnblogs.com/pbblog/p/3484193.html)
> 
> 我就直接套公式了，感谢大佬的推导，我就不细🔒了，~~我是懒狗~~ 

我们在 composite.fsh 中添加如下的一致变量

```
uniform float near;
uniform float far;  
```

然后编写我们的转换函数：

```
/*
 *  @function screenDepthToLinerDepth   : 深度缓冲转线性深度
 *  @param screenDepth                  : 深度缓冲中的深度
 *  @return                             : 真实深度 -- 以格为单位
 */
float screenDepthToLinerDepth(float screenDepth) {
    return 2 * near * far / ((far + near) - screenDepth * (far - near));
}
```

最后我们可以通过 d0 和 d1 到水面的距离来计算淡出系数了，我们编写如下的函数：

```
/*
 *  @function getUnderWaterFadeOut  : 计算水下淡出系数
 *  @param d0                       : 深度缓冲0中的原始数值
 *  @param d1                       : 深度缓冲1中的原始数值
 *  @param positionInViewCoord      : 眼坐标包不包含水面均可，因为我们将其当作视线方向向量
 *  @param normal                   : 眼坐标系下的法线
 *  @return                         : 淡出系数
 */
float getUnderWaterFadeOut(float d0, float d1, vec4 positionInViewCoord, vec3 normal) {
    // 转线性深度
    d0 = screenDepthToLinerDepth(d0);
    d1 = screenDepthToLinerDepth(d1);

    // 计算视线和法线夹角余弦值
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
    cosine = clamp(abs(cosine), 0, 1);

    return clamp(1.0 - (d1 - d0) * cosine * 0.1, 0, 1);
}
```

随后我们修改绘制阴影的函数，即 getShadow 函数，我们要增加一个形参以控制阴影的强度：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201019200630826.png#pic_center)
![在这里插入图片描述](https://img-blog.csdnimg.cn/2020101920065593.png#pic_center)
最后我们在main函数中，绘制阴影之前添加如下的代码以计算水下衰减强度：

```
float underWaterFadeOut = getUnderWaterFadeOut(depth0, depth1, positionInViewCoord0, normal);   // 水下淡出系数
```

然后修改绘制阴影的时候对 getShadow 的调用：

```
// 不是发光方块则绘制阴影
if(id!=10089 && id!=10090) {
    color = getShadow(color, positionInWorldCoord1, underWaterFadeOut);
}
```

图示：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201019200903431.png#pic_center)

重新加载光影包，现在水下阴影能够正确的淡出了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201019201018777.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
![在这里插入图片描述](https://img-blog.csdnimg.cn/20201019201151907.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)



# 焦散

焦散就是光线直射水面的时候，由于水面折射和反射不均匀，而形成亮暗不一致的光斑：


> ![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009203411334.png)
> 图片引自 ---- 百度图片

和水面纹理的绘制类似，因为焦散就是一堆亮暗相间的条纹堆叠而成，那么我们同样可以通过 **噪声纹理** 来获取随机数，并且随即地渲染焦散斑纹它


随后我们编写一个函数，用来获取焦散的亮暗增益，最终我们要用这个值乘以颜色以调整像素的亮度：

```
/*
 *  @function getCaustics       : 获取焦散亮度缩放倍数
 *  @param positionInWorldCoord : 当前点在 “我的世界坐标系” 下的坐标
 *  @return                     : 焦散亮暗斑纹的亮度增益
 */
float getCaustics(vec4 positionInWorldCoord) {
    positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）

    // 波纹1
    float speed1 = float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 4;
    coord1.x += speed1*2 + coord1.z;
    coord1.z -= speed1;
    float noise1 = texture2D(noisetex, coord1.xz).x;
    noise1 = noise1*2 - 1.0;

    // 波纹2
    float speed2 =  float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.z *= 4;
    coord2.z += speed2*2 + coord2.x;
    coord2.x -= speed2;
    float noise2 = texture2D(noisetex, coord2.xz).x;
    noise2 = noise2*2 - 1.0;

    return noise1 + noise2; // 叠加
}
```

和水面的噪声图采样类似。这里我们首先将 “我的世界坐标” （即以相机为原点的世界坐标。获取方式：世界坐标 - 相机在世界坐标的位置）变换到世界坐标（即绝对坐标）。随后利用世界坐标，在噪声纹理中取随机数。

> 注：这里我们叠加两个运动方向相反的波纹
> ![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009210140355.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)



随后在 main 函数中，绘制基础水面（drawWater函数）之前，加上

```
float caustics = getCaustics(positionInWorldCoord1);    // 亮暗参数  
color.rgb *= 1.0 + caustics*0.25 * underWaterFadeOut;
```

然后重新加载光影包，可以看到明显的焦散的效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009210524969.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

还有一点问题：注意到上图红色箭头指向的方块即使在陆地上，**那就是我们给所有方块都绘制了焦散，而不是水下的方块**。这意味着我们需要做一次筛选，判断那些方块是在水底，那些方块是在岸上。


那么怎么判断呢？同样利用我们在 gbuffers_water.fsh 中输出到 4 号颜色缓冲区的属性来判断：

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020102117171175.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


因为上文编写 composite.fsh 中，筛选水面的时候，已经判断过一次了，即 isWater 变量，这个变量表示当前片元（视线指向）是否经过水面：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021161212962.png#pic_center)


然后将main函数中，绘制焦散的代码改为

```
// 焦散
float caustics = getCaustics(positionInWorldCoord1);    // 亮暗参数  
// 如果在水下则计算焦散
if(isWater==1) {
    color.rgb *= 1.0 + caustics*0.25 * underWaterFadeOut;
}
```

再次重新加载光影包，发现岸上的焦散消失了，而水下的焦散照常绘制：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201019203643806.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


可是还有一个问题，当我们视角潜到水底的时候，会发现不能正常的绘制焦散：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009213145575.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
这是因为我们的其中一个深度缓冲 depthtex0 是不包含水面的，那么视角潜水之后，不能正确的获取当前的深度值，并且潜水之后，是否在水底，不能单纯利用 d1 - d0 是否大于 0 来判断：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009213535529.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

一个很简单的解决方案就是：直接粗暴的对所有方块都绘制焦散。我们将绘制焦散的 if 判断调节稍加改动，加上 ` || isEyeInWater==1`：

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020102116154374.png#pic_center)


其中 isEyeInWater 是一个 uniform 变量，表示当前视角是否在水下。查阅 [optfine的文档](https://github.com/sp614x/optifine/blob/master/OptiFineDoc/doc/shaders.txt)可以发现，如果 isEyeInWater==1 则表示在水中

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009214034200.png#pic_center)

别忘了在 composite.fsh 开头声明这个变量：

```
uniform int isEyeInWater;
```

重新加载光影包，现在水下的焦散有了一个很好的效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201009214559165.gif#pic_center)

# bug修复：染色玻璃透视问题

因为染色玻璃也属于透明方块，我们通过 depthtex0 即 0 号深度缓冲建立的坐标，来渲染天空，而我门在 gbuffers_skybasic 着色器中，已经屏蔽了原版的天空输出，这就导致了透过染色玻璃天空渲染失效，如图，天空是黑色的：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021173506744.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

这是因为我们绘制天空的时候用的是 0 号深度缓冲区的数据建立的坐标，d0 距离远达不到天空的距离（0.9999），所以我们绘制天空失败了。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021173900317.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
我承认这里又是我犯病了。。。其实天空的基色应该直接在 gbuffers_skybasic 绘制的。。。我当时为了少算一次颜色插值，就图方便了。。。

不过解决方案也很简单，我们利用 1 号深度缓冲的数据建立的坐标，再绘制一次天空，然后把两者叠加就行了。

此外，要如何判断是否是染色玻璃呢？还记得我们在 gbuffers_water.fsh 着色器中留了一手吗：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021215217754.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

对于染色玻璃等透明方块，我们令其 w 通道为 0.5 标记，于是我们可以通过增加一个判断条件：

```
bool isStainedGlass = (isWater>0 && isWater<1):(true):(false);  // 是否是染色玻璃
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021215344285.png#pic_center)

来判断是否是染色玻璃。我们在天空的绘制代码改为：

```
// 天空绘制
vec3 sky = drawSky(color.rgb, positionInViewCoord1, positionInWorldCoord1);
if(isStainedGlass) {    // 如果是染色玻璃则混合颜色
    color.rgb = mix(color.rgb, sky, 0.4) ;
} else {    // 如果是普通方块
    color.rgb = sky;
}
```

即：
1. 如果是染色玻璃则进行混色
2. 如果不是则照常绘制雾与天空

图示：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021174227809.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

修复后：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021174533752.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
~~当然我们在 gbuffers_skybasic 中再算一次天空颜色然后输出也可以的。。。~~ 
