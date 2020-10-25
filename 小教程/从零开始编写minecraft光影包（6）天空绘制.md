**完整资源：**

 [我的Github地址](https://github.com/AKGWSB/Hello-Minecraft-Shaders/tree/master)

**前情提要：**

[从0开始编写minecraft光影包（0）GLSL，坐标系，光影包结构介绍](https://blog.csdn.net/weixin_44176696/article/details/108152896)

[从零开始编写minecraft光影包（1）基础阴影绘制](https://blog.csdn.net/weixin_44176696/article/details/108625077)

[从零开始编写minecraft光影包（2）阴影优化](https://blog.csdn.net/weixin_44176696/article/details/108637819)

[从零开始编写minecraft光影包（3）基础泛光绘制](https://blog.csdn.net/weixin_44176696/article/details/108672719)

[从零开始编写minecraft光影包（4）泛光性能与品质优化](https://blog.csdn.net/weixin_44176696/article/details/108692525)

[从零开始编写minecraft光影包（5）简单光照系统，曝光调节，色调映射与饱和度](https://blog.csdn.net/weixin_44176696/article/details/108909824)

@[TOC](目录)

# 前言

在国庆又当懒狗了几天之后，终于决定又来更新博客了。。。。

今天更新天空的绘制，我们将绘制自定义的天空颜色以及太阳，月亮，雾，以及他们的昼夜交替效果。

注：本章节博客基于 [上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108909824) 中完成的光影包代码

# 干掉原版天空

要绘制我们自定义的天空，首先我们需要干掉原版的天空，通过查阅[资料](https://www.jianshu.com/p/a7772f621bb4)可知，有两个着色器负责天空的绘制：

1. gbuffers_skybasic ：天空原色 + 星星
2. gbuffers_skytextured ： 太阳与月亮

那么我们需要干掉原版的天空，让这两个着色器输出纯黑即可。我们编写四个着色器，分别是：

gbuffers_skybasic.fsh，gbuffers_skybasic.vsh，gbuffers_skytextured.fsh，gbuffers_skytextured.vsh

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006212542312.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
其中 .vsh 的内容都是：

```
#version 120

void main() {
	gl_Position = ftransform();
}
```

与之对应，.fsh 的内容为：

```
#version 120

void main() {
	gl_FragData[0] = vec4(vec3(0), 1.0); 
}
```


再次加载光影包，我们发现原版的天空已经被我们干掉了，太阳，月亮以及其他天空颜色都消失了。。。现在可以开始着手绘制我们的天空了

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006212845181.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 天空基色绘制

因为没有一个很好的机制来判断何处是天空，我们采用曲线救国的方式，通过距离计算原色与天空颜色混合（即mix线性混合）。

即：**越远的方块，颜色越靠近天空的颜色**，这样绘制最终会形成**雾**的效果。这样会比直接使用距离作为阈值来绘制天空要平滑很多。

要绘制天空颜色，首先我们需要有昼夜变换的的天空颜色，我们在 composite.vsh 中加入：

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

这个数组表示了一天24小时中，昼夜的天空颜色的变换，然后在**main函数**中加入如下的代码，根据世界时间 `worldTime` 对颜色进行实时地平滑过渡取值。

```
// 颜色过渡插值
int hour = worldTime/1000;
int next = (hour+1<24)?(hour+1):(0);
float delta = float(worldTime-hour*1000)/1000;

// 天空颜色
mySkyColor = mix(skyColorArr[hour], skyColorArr[next], delta);
```

其中 `mySkyColor` 负责将天空颜色从顶点着色器传递到片段着色器。

然后我们在 composite.fsh 中编写`drawSky`函数，该函数接收**不包含天空的原始颜色**，以及其他必要的数据，并且绘制天空：

```
/*
 *  @function drawSky           : 天空绘制
 *  @param color                : 原始颜色
 *  @param positionInViewCoord  : 眼坐标
 *  @param positionInWorldCoord : 我的世界坐标
 *  @return                     : 绘制天空后的颜色
 */
vec3 drawSky(vec3 color, vec4 positionInViewCoord, vec4 positionInWorldCoord) {
    // 距离
    float dis = length(positionInWorldCoord.xyz) / far;

    return mix(color, mySkyColor, clamp(pow(dis, 3), 0, 1));
}
```

这一步仅仅是根据像素在世界坐标系中的**距离**，进行简单的颜色混合。**越远的像素，颜色越接近天空**，越近的像素则不受影响：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006214428883.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

虽然很简陋，但是我们完成了一个简单的天空基色的绘制。以线性混合的形式，通过距离将很远的像素绘制上颜色，以表示天空。


# 太阳与月亮绘制
天空绘制非常简单，但是现在有个带问题：没有太阳和月亮，因为我们在 gbuffer 着色器中将他们干掉了。。。

所以我们迫切需要绘制太阳和月亮，我们同样需要先在 composite.vsh 中，和计算天空颜色类似，我们计算太阳（或者月亮）的颜色。

在 composite.vsh 中加入：

```
varying vec3 mySunColor;

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

这个数组同样代表平滑过渡的太阳颜色取值。然后在 composite.vsh 的 main 函数中，计算天空颜色的部分**之后**，加入：

```
// 太阳颜色
mySunColor = mix(sunColorArr[hour], sunColorArr[next], delta);
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006215229496.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
以完成对太阳颜色的平滑过渡取值。

随后进入到 composite.fsh 中，添加如下两个uniform变量：

```
uniform vec3 sunPosition;
uniform vec3 moonPosition;
```

他们代表太阳或者月亮在**眼坐标系**中的坐标。然后，我们修改一下 drawSky 函数的内容：

```
vec3 drawSky(vec3 color, vec4 positionInViewCoord, vec4 positionInWorldCoord) {

    // 距离
    float dis = length(positionInWorldCoord.xyz) / far;

    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005 && dis>0.99999) {
        drawSun = mySunColor * 2;
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005 && dis>0.99999) {
        drawMoon = mySunColor * 2;
    }

    // 根据距离进行最终颜色的混合
    return mix(color, mySkyColor, clamp(pow(dis, 3), 0, 1)) + drawSun + drawMoon;
}
```

首先我们通过 positionInViewCoord 变量， 即当前像素在眼坐标系中的坐标，和太阳（或者月亮）在眼坐标系中的坐标进行 dot （点乘）操作，计算出他们之间的 “距离” 

离太阳中心的距离小于一定范围，我们便认为这就是太阳。于是绘制太阳，值得注意的是，绘制的时候要考虑两个因素：

1. 当前像素是否离太阳足够近
2. 当前像素是否是天空（即离世界坐标系原点的距离是否足够远）

所以绘制太阳和月亮的两个 if 需要这么判断。重新加载光影包，我们可以看到，太阳和月亮已经绘制成功了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006221255217.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 颜色混合

在现实世界中，天空往往会被太阳（或者月亮）的颜色染色，我们希望实现这一特效。

和绘制太阳一样，我们仍然通过眼坐标系中的距离，判断当前像素是否足够靠近太阳。如果是，则将其颜色和太阳的颜色 mySunColor 进行线性混合。

我们修改 drawSky 函数：

```
vec3 drawSky(vec3 color, vec4 positionInViewCoord, vec4 positionInWorldCoord) {

    // 距离
    float dis = length(positionInWorldCoord.xyz) / far;

    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005 && dis>0.99999) {
        drawSun = mySunColor * 2;
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005 && dis>0.99999) {
        drawMoon = mySunColor * 2;
    }
    
    // 雾和太阳颜色混合
    float sunMixFactor = clamp(1.0 - disToSun, 0, 1);
    vec3 finalColor = mix(mySkyColor, mySunColor, pow(sunMixFactor, 4));

    // 雾和月亮颜色混合
    float moonMixFactor = clamp(1.0 - disToMoon, 0, 1);
    finalColor = mix(finalColor, mySunColor, pow(moonMixFactor, 4));

    // 根据距离进行最终颜色的混合
    return mix(color, finalColor, clamp(pow(dis, 3), 0, 1)) + drawSun + drawMoon;
}
```

其中在绘制太阳和月亮之后，加入了混合颜色的步骤。我们对那些靠近太阳（或者月亮）的像素，将其基色和太阳颜色进行线性混合（mix函数）。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006222203616.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

再次重新加载光影包，我们可以看到，天空逐渐被太阳的颜色染色：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006222458779.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006222616371.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 昼夜交替平滑过渡

事到如今，我们的天空已经绘制的较为完善了，接下来我们需要对其瑕疵进行修复。

因为太阳和月亮使用的是同一套颜色，那么昼夜交替的时候，就会出现两个太阳（或者两个月亮），这显然是不够平滑的。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006222959307.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

还记得我们怎么解决阴影的昼夜交替问题🐎？我们设置了一个变量 `isNight`，表示是否到达晚上。它的值会在 0 和 1 之间平滑过渡。在 composite.vsh 中加入：

```
varying float isNight;
```

以向片段着色器传递昼夜交替的信号，随后我们在  composite.vsh 的 main 函数中加入：

```
// 昼夜交替插值
isNight = 0;  // 白天
if(12000<worldTime && worldTime<13000) {
    isNight = 1.0 - (13000-worldTime) / 1000.0; // 傍晚
}
else if(13000<=worldTime && worldTime<=23000) {
    isNight = 1.0;    // 晚上
}
else if(23000<worldTime) {
    isNight = (24000-worldTime) / 1000.0;   // 拂晓
}
```

这样子我们就获得了昼夜交替的信号值。1 表示 夜晚，0 表示白天，其他数值表示过渡中...

随后我们在  composite.fsh 中加入：

```
varying float isNight;
```

以使用这个变量。顺便改掉之前 `getShadow` 函数中，阴影绘制时，利用`isNight`进行判断的代码。

即我们不需要从 gbuffers_terrain.fsh 写入的 3 号缓冲区中读取这个值了，省略 texture2D 纹理查询，直接调用即可。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006223940167.png#pic_center)


最后我们修改 composite.fsh 中 drawSky 函数的内容，我们加入昼夜变换的过渡：

```
vec3 drawSky(vec3 color, vec4 positionInViewCoord, vec4 positionInWorldCoord) {

    // 距离
    float dis = length(positionInWorldCoord.xyz) / far;

    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005 && dis>0.99999) {
        drawSun = mySunColor * 2 * (1.0-isNight);
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005 && dis>0.99999) {
        drawMoon = mySunColor * 2 * isNight;
    }
    
    // 雾和太阳颜色混合
    float sunMixFactor = clamp(1.0 - disToSun, 0, 1) * (1.0-isNight);
    vec3 finalColor = mix(mySkyColor, mySunColor, pow(sunMixFactor, 4));

    // 雾和月亮颜色混合
    float moonMixFactor = clamp(1.0 - disToMoon, 0, 1) * isNight;
    finalColor = mix(finalColor, mySunColor, pow(moonMixFactor, 4));

    // 根据距离进行最终颜色的混合
    return mix(color, finalColor, clamp(pow(dis, 3), 0, 1)) + drawSun + drawMoon;
}
```

要修改的地方其实就四处：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006223713578.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

再次切换光影包，我们可以看到日出和日落的时候，会有更加平滑的过渡，不会出现两个太阳这种情况

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006225045359.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 小结
本次博客描述了如何绘制一个基础的天空，并且增加一些特效，比如颜色的混合等等。通过混合太阳和天空的颜色，实现天空的渲染。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006232418181.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201006232616740.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

当然这样粗暴地通过距离来将基色和天空线性混合，也会带来意想不到的效果，以及一些bug。

比如我们覆盖了下雨时候雨滴动画，可以看到，天空部分是没有雨滴的：

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020100623295353.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

好吧。。。虽然好像很严重，但是修复起来很简单，我们可以在gbuffer阶段，将雨滴的动画存储起来，等到天空颜色合成完成之后，再覆盖上去即可

~~下次一定~~ 



