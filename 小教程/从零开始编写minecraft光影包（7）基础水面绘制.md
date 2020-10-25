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

@[TOC](目录)

# 前言

国庆快完了。。。还是来更新下博客，不能太摸鱼了。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007160027513.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
好了不扯了。。。今天来实现水面的渲染。

> 注：本次着色器特效的编写基于[上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108943499)中完成的着色器。

# gbuffer阶段着色器是如何渲染水面的

要渲染水面，首先我们编写 gbuffers_water 着色器。他们的内容是：

gbuffers_water.vsh：

```
#version 120

varying vec4 texcoord;
varying vec4 color;

void main() {
    gl_Position = ftransform();
    color = gl_Color;   // 基色
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
```

gbuffers_water.fsh：

```
#version 120

uniform sampler2D texture;

varying vec4 texcoord;
varying vec4 color;

void main() {
   gl_FragData[0] = color * texture2D(texture, texcoord.st);
}
```

~~重新加载光影包，你会发现啥变化都没有。。。这不是废话🐎，我们只是把颜色直接输出了而已。。。~~ 

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007160530179.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
和其他方块的绘制一样，颜色的绘制分为两个部分：

1. 水方块基色
2. 水方块纹理

我们当然可以无视这个过程，比如我们直接输出颜色，将 gbuffers_water.fsh 中输出颜色的部分改为：

```
gl_FragData[0] = vec4(vec3(0.1, 0.2, 0.4), 0.5);
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007160845610.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

其中 w 分量表示颜色的 alpha 通道，即透明度，下面展示不同透明度的水面渲染结果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007161126475.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

但是问题就来了，当我们直接输出 `vec4(vec3(0.1, 0.2, 0.4), 0.5)` 的时候，会发现染色玻璃，冰块等透明方块，也变成了水的颜色：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007161528402.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
这是因为 gbuffers_water 着色器除了负责渲染水，还负责这些透明方块的渲染，因此我们要渲染水面，首先得进行一次筛选。

我们在 block.properties 中添加一行，将水方块的 id 设置为 10091：

```
block.10091 = flowing_water water
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007161903753.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


随后我们将 gbuffers_water.vsh 的内容改为：

```
#version 120

attribute vec2 mc_Entity;

varying float id;

varying vec4 texcoord;
varying vec4 color;

void main() {
    gl_Position = ftransform();
    color = gl_Color;   // 基色
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

    // 方块id
    id = mc_Entity.x;
}
```

使用 mc_Entity 这个顶点属性，我们判断是否是水方块，然后决定是否绘制我们自定义的颜色。

随后，修改 gbuffers_water.fsh 的内容为：

```
#version 120

uniform sampler2D texture;

varying float id;

varying vec4 texcoord;
varying vec4 color;

void main() {
    // 不是水面则正常绘制
    if(id!=10091) {
        gl_FragData[0] = color * texture2D(texture, texcoord.st);
        return;
    }
    // 是水面则绘制自定义颜色
    gl_FragData[0] = vec4(vec3(0.1, 0.2, 0.4), 0.5);
}
```

再次加载光影包，我们发现水面和其他透明方块可以分别绘制了。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007162454161.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 水面基色绘制

~~常言道水天一色~~ ，水面会反射天空的颜色，尤其是开阔的水域这种现象经常发生。我们希望**通过天空的颜色来绘制水面基色**。

> 还记得上一篇博客中，我们如何绘制天空的颜色吗？根据世界时间 worldTime 进行平滑过渡。

我们直接将代码复制一份过来即可，这里就不细🔒了。在 gbuffers_water.vsh 中添加：

```
uniform int worldTime;
varying vec3 mySkyColor;

vec3 skyColorArr[24] = {
    vec3(0.1, 0.6, 0.9),        // 0-1000
    vec3(0.1, 0.6, 0.9),        // 1000 - 2000
    vec3(0.1, 0.6, 0.9),        // 2000 - 3000
    vec3(0.1, 0.6, 0.9),        // 3000 - 4000
    vec3(0.1, 0.6, 0.9),        // 4000 - 5000 
    vec3(0.1, 0.6, 0.9),        // 5000 - 6000
    vec3(0.1, 0.6, 0.9),        // 6000 - 7000
    vec3(0.1, 0.6, 0.9),        // 7000 - 8000
    vec3(0.1, 0.6, 0.9),        // 8000 - 9000
    vec3(0.1, 0.6, 0.9),        // 9000 - 10000
    vec3(0.1, 0.6, 0.9),        // 10000 - 11000
    vec3(0.1, 0.6, 0.9),        // 11000 - 12000
    vec3(0.1, 0.6, 0.9),        // 12000 - 13000
    vec3(0.02, 0.2, 0.27),      // 13000 - 14000
    vec3(0.02, 0.2, 0.27),      // 14000 - 15000
    vec3(0.02, 0.2, 0.27),      // 15000 - 16000
    vec3(0.02, 0.2, 0.27),      // 16000 - 17000
    vec3(0.02, 0.2, 0.27),      // 17000 - 18000
    vec3(0.02, 0.2, 0.27),      // 18000 - 19000
    vec3(0.02, 0.2, 0.27),      // 19000 - 20000
    vec3(0.02, 0.2, 0.27),      // 20000 - 21000
    vec3(0.02, 0.2, 0.27),      // 21000 - 22000
    vec3(0.02, 0.2, 0.27),      // 22000 - 23000
    vec3(0.02, 0.2, 0.27)       // 23000 - 24000(0)
};
```

gbuffers_water.vsh 的 main 函数中添加：

```
// 颜色过渡插值
int hour = worldTime/1000;
int next = (hour+1<24)?(hour+1):(0);
float delta = float(worldTime-hour*1000)/1000;
// 天空颜色
mySkyColor = mix(skyColorArr[hour], skyColorArr[next], delta);
```

然后再在 gbuffers_water.fsh 中，加入

```
varying vec3 mySkyColor;
```

将 main 函数中，水面颜色绘制改为：

```
// 是水面则绘制自定义颜色
gl_FragData[0] = vec4(mySkyColor, 0.5);
```

然后重新加载光影包，可以看到昼夜水面颜色发生了变化：

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020100716384833.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

此时我们的水面害不够逼真，看起来就像一般的方块一样，接下来我们将会为水面添加一些物理上的效果。

# 透射效应

在现实世界中，**当视线平视水面时候，反射光的颜色会强，这时候往往看不清水底的细节。而当视线垂直水面的时候，往往可以看清水底的细节**。这便是光发生了**透**射。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007164445310.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

> 图片来源：百度图片


如何判断视线是平视还是垂直水面呢？我们需要用到**法向量**。我们希望通过**视线和水面法向量的角度**，来绘制具有透射效应的水面。那么首先我们需要得到水面方块的法线。

如图：通过法线和视线方向的夹角，可以判断出是平视还是直视
![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008011549798.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


首先我们需要在顶点着色器中获取当前像素的法线（法向量），修改 gbuffers_water.vsh ，加入：

```
uniform mat4 gbufferModelViewInverse;	
varying vec3 normal;	// 法向量在眼坐标系下
varying vec4 positionInViewCoord;	// 眼坐标
```

然后在 main 函数中，首先我们修改原来的 mvp 变换过程，我们首先进行 mv 变换，得到**眼坐标**，然后进行 p 变换：

```
positionInViewCoord = gl_ModelViewMatrix * gl_Vertex;   // mv变换计算眼坐
gl_Position = gbufferProjection * positionInViewCoord;  // p变换
```

随后我们将法向量赋值给 normal 变量：

```
// 眼坐标系中的法线
normal = gl_NormalMatrix * gl_Normal;
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007173252550.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

然后在  gbuffers_water.fsh 中，加入透射的计算。我们通过**视线方向与法向量的夹角**，来计算透射系数。

因为其中眼坐标系下的坐标原点位于摄像机中心，那么**眼坐标就是视线方向**。故在  gbuffers_water.fsh 中，加入

```
varying vec3 normal;    // 法向量在眼坐标系下
varying vec4 positionInViewCoord;   // 眼坐标
```

随后修改 main 函数，在颜色输出之前，加入：

```
// 计算视线和法线夹角余弦值
float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
cosine = clamp(abs(cosine), 0, 1);
float factor = pow(1.0 - cosine, 4);    // 透射系数
```

我们通过菲涅尔方程的近似解，即那个 pow（， 4） 求出了透射系数，其中近似方程为：

~~因为cs专业没有学过《工程光学》，所以直接抄作业力。。。。~~ 

> ![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008012032244.png)
> 引自：[用 C 语言画光（六）：菲涅耳方程](https://zhuanlan.zhihu.com/p/31534769)
> 注：此处将5次方改为4次，~~更符合我的xp~~ ，此外，R0 为介质的反光率（是叫这个吧？），一般取 0.05（反正是一个很小的数字），这里我直接取 0 了简单粗暴


接下来我们通过透射系数，将**深浅不同**的颜色进行混合

我们修改最后的颜色输出，视线直视的像素，颜色浅一些（乘以0.3），视线平视的像素，则取原来的值：

```
gl_FragData[0] = vec4(mix(mySkyColor*0.3, mySkyColor, factor), 0.75);
```

图解：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007185719187.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


重载光影包之后，可以发现，是不是 “有内味了” ？

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007185529141.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


可以看到，近处的水更加通透，而远处的水反射的光线更加多。这就是透射效应。


# 水面凹凸绘制

到目前为止，我们的水面都像是镜面一样，我们希望让水面动起来，有一点凹凸感，有一点波浪起伏。

首先我们需要让水面有一些起伏。我们通过在顶点着色器中，**调整水方块坐标的 y 值**，来实现水的上下凹凸。

首先我们在顶点着色器 gbuffers_water.vsh 中加入如下的 uniform 变量：

```
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform int worldTime;
```


我们加入了：四个坐标变换矩阵，然后是**世界坐标系下摄像机的坐标**，世界时间，以帮助我们绘制凹凸水面。

随后我们添加一个函数，来对水面方块的  y 坐标进行修改：

```
/*
 *  @function getBump          : 水面凹凸计算
 *  @param positionInViewCoord : 眼坐标系中的坐标
 *  @return                    : 计算凹凸之后的眼坐标
 */
vec4 getBump(vec4 positionInViewCoord) {
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;  // “我的世界坐标”
    positionInWorldCoord.xyz += cameraPosition; // 世界坐标（绝对坐标）

    // 计算凹凸
    positionInWorldCoord.y += sin(positionInWorldCoord.z * 2) * 0.05;

    positionInWorldCoord.xyz -= cameraPosition; // 转回 “我的世界坐标”
    return gbufferModelView * positionInWorldCoord; // 返回眼坐标
}
```

首先我们必须将眼坐标转换到世界坐标。这里是世界坐标，不是”我的世界坐标“，这意味着其原点不在摄像机原点。注意到：

```
positionInWorldCoord.y += sin(positionInWorldCoord.z * 2) * 0.05;
```

我们将 z 轴作为 sin 函数的取值，这意味着，水面的高度会和其 z 坐标相关。这正是我们想要的波浪效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201007235818489.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
然后我们修改 main 函数中的坐标计算，将：

```
gl_Position = gbufferProjection * positionInViewCoord;  // p变换
```

改为：

```
if(mc_Entity.x == 10091) {  // 如果是水则计算凹凸
   gl_Position = gbufferProjection * getBump(positionInViewCoord);  // p变换
} else {    // 否则直接传递坐标
    gl_Position = gbufferProjection * positionInViewCoord;  // p变换
}
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008001146149.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


这样我们就传递了计算凹凸之后的坐标！重新加载光影包，你会发现：


![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008000243941.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

但是遗憾的是，这个凹凸并不会随着时间而挪动，我们需要在计算 sin 时传入和时间相关的量。我们将 getBump 函数中，凹凸的计算改为：

```
positionInWorldCoord.y += sin(float(worldTime*0.3) + positionInWorldCoord.z * 2) * 0.05;
```

其中 `float(worldTime*0.3) ` 负责控制波浪随时间而挪动（即 sin 的取值），再次加载光影包，现在，波浪会随着时间而波动了


![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008001428403.gif#pic_center)

# 水面纹理绘制

水面纹理，说到底就是一大堆亮暗相间的，形状类似波浪的东西。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020100800230522.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

我们只要搞出一堆比较随机的亮暗条纹，然后覆盖上去即可。。。难点在于如何获取随机数。这就需要引入噪声纹理了

## 噪声纹理
在glsl中，可没有什么 rand 函数来产生随机数，不过好在shadermod为我们提供了一张噪声纹理。

> 噪声纹理其实就是一张图，其中的值是随机的，且**连续**的随机数。连续是个好特性。

此外，如果坐标取值超过噪声纹理的范围，还会自动取模到合法范围内，这意味着，我们可以通过一张小的噪声纹理，拼凑出 ”边缘连续“ 的一张大噪声纹理。

如果我们在着色器中，直接输出噪声纹理的颜色，比如利用如下的代码：

```
gl_FragData[0] = vec4(vec3(texture2D(noisetex, texcoord.st).x), 1);
```

会发现：

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020100800292382.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

这就是一堆在坐标上取值连续的随机数嘛，刚好满足我们的需求！

## 利用噪声纹理进行绘制

开始动工！我们在 gbuffers_water.fsh 中，加入如下的内容：

```
const int noiseTextureResolution = 128;
uniform mat4 gbufferModelViewInverse;
uniform sampler2D noisetex;
uniform vec3 cameraPosition;
```

首先我们声明了噪声纹理的分辨率（和shadow纹理类似。。。），然后声明一些uniform变量，他们分别是：mv变换逆矩阵，噪声纹理，相机在世界坐标系中的坐标。

现在开始编写计算波浪纹理的函数：

```
/*
 *  @function getWave           : 绘制水面纹理
 *  @param color                : 原水面颜色
 *  @param positionInWorldCoord : 世界坐标（绝对坐标）
 *  @return                     : 叠加纹理后的颜色
 */
vec3 getWave(vec3 color, vec4 positionInWorldCoord) {

    // 小波浪
    float speed1 = float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 3;
    coord1.x += speed1;
    coord1.z += speed1 * 0.2;
    float noise1 = texture2D(noisetex, coord1.xz).x;

    // 绘制 “纹理”
    color *= noise1 * 0.6 + 0.4;    // 64开调整颜色亮度

    return color;
}
```

**和刚刚的水面凹凸算中，利用 sin 函数的取值类似，只是这次我们取的是噪声图中的值，而不是 sin 函数的值了。**

~~不要在意这些常数 都是调出来的。。。~~ 

然后在 main 函数中，加入

```
// 计算 "世界坐标"
vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;   // “我的世界坐标”
positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）

// 绘制明暗相间的水面波浪纹理
vec3 finalColor = mySkyColor;
finalColor = getWave(mySkyColor, positionInWorldCoord);
```

首先我们计算世界坐标，随后传递给 getWave 函数，绘制水面纹理。然后最终我们将 finalColor 和基色混合，即修改输出颜色的代码为：

```
gl_FragData[0] = vec4(mix(mySkyColor*0.3, finalColor, factor), 0.75);
```

图解：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008004032885.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

重新加载光影包，可以看到，波浪绘制已经取得了比较好的效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008004202879.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

## 复合噪声

注意到我们的水面有一些单调，我们需要**更加复杂**的噪声函数！

和 sin / cos 一样，噪声函数也可以进行复合。复合，即一个函数的输出，作为另一个函数的输入，即 `y = sin(a * sin(x) + b)` 这样子

但是因为cs专业，并没有学过《信号与系统》这门课，我么不知道怎么讲解这个复合噪声，而是直接按照经验调了一下参数算了

~~差不多得了~~ 

我们将 getWave 函数的内容改为：

```
/*
 *  @function getWave           : 绘制水面纹理
 *  @param color                : 原水面颜色
 *  @param positionInWorldCoord : 世界坐标（绝对坐标）
 *  @return                     : 叠加纹理后的颜色
 */
vec3 getWave(vec3 color, vec4 positionInWorldCoord) {

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

    // 绘制 “纹理”
    color *= noise2 * 0.6 + 0.4;    // 64开调整颜色亮度

    return color;
}
```

其中我们让第一个噪声采样的输出，作为第二个噪声采样的输入：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008004725423.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

重新加载光影包，现在噪声的效果更加耐看 ，变化也更加复杂：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008004840828.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


# 小结

好了。。。今天一口气更了这么多。。。我也该躺好了

总结下，

1. 利用worldTime进行平滑取值，计算水方块的基色
2. 利用法线，计算透射效应后的水面效果
3. 利用顶点着色器，绘制凹凸的水面顶点
4. 利用噪声纹理，绘制波浪纹理

差不多得了。。。下次博客将会更新进一步的水面特效，比如焦散和反射。

放几张图。睡了睡了明天开学了

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008010703575.gif#pic_center)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201008010840604.gif#pic_center)


