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

[从零开始编写minecraft光影包（8）中级水面绘制 水下阴影与焦散](https://blog.csdn.net/weixin_44176696/article/details/108984693)

@[TOC](目录)

# 前言

上次的博客我们完成了水下特效的绘制，即阴影和焦散。这次我们来搞一点赛艇的东西。。。

# 反射
在上一篇博客中，我们只是简单绘制了水体的特效，可是我们的水面还是不够漂亮，因为它始终缺少反射的效果。
![在这里插入图片描述](https://img-blog.csdnimg.cn/20201020212016751.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

而在现实世界中，我们在日出日落的时候，水面会反射天空的颜色：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201020212223690.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

**所以在该部分，我们将绘制水面，使其能够反射来自天空的光线！**


要想正确的绘制某像素的反射，这意味着我们接收该像素的反射光。我们必须知晓该像素反射的光线的颜色

换句话说，我们要知道，从“镜子”中看到了谁？这就需要计算反射光线：

![在这里插入图片描述](https://img-blog.csdnimg.cn/202010202130473.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

如图所示，我们只需要知晓
1. 入射光线方向
2. 反射点的法线方向

即可计算出反射光线的方向。而**因为眼坐标系是以相机为原点的，那么入射光线的方向，又等于眼坐标中的坐标**。

利用 GLSL 帮我们封装好的 `reflect` 函数，我们可以轻松求出反射光线的方向。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201020213459112.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

其中第一个参数是入射光线的方向，第二个参数是反射点的法线。

在求出反射光线之后，我们还希望知晓反射光线对应的天空颜色是什么，还记得我们在 [之前的博客](https://blog.csdn.net/weixin_44176696/article/details/108943499) 中是如何绘制天空的🐎？

1. 我们**给定一个眼坐标系下的坐标**（或者说是视线方向）
2. 然后我们将 1 中的坐标，和 **太阳在眼坐标系下的坐标** 进行距离比对
3. 距离越近，则 “染上” 越多的太阳的颜色（mix函数线性混合）

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201020214442482.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

这意味着我们只要知晓任意一条射线在**眼坐标系**中的方向，我们就有办法计算出其对应的天空颜色。如果我们输入一条反射光线，那么理应得到正确的反射天空颜色。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201020220321509.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)



因为太阳的位置可以用坐标显式地表示出来。这种计算方式像极了 “天空球” 。我们知晓任意一点的坐标，都可以 “查询” 天空球，得出该点对应的天空是什么颜色。

> 注：此处不是真正的天空球，而是通过太阳的位置和视线的方向，推算天空的颜色。**从观察中心出发的两条方向一致的射线，必将得到一致的结果**。

明白了这个原理后我们就可以着手编写（copy）绘制天空的代码了，我们编写两个函数，通过当前的眼坐标（其实实际传入的参数是反射光线的方向），来计算天空的颜色：

```
/*
 *  @function drawSkyFakeReflect    : 绘制天空的假反射
 *  @param positionInViewCoord      : 眼坐标
 *  @return                         : 天空基色
 */
vec3 drawSkyFakeReflect(vec4 positionInViewCoord) {
    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 雾和太阳颜色混合
    float sunMixFactor = clamp(1.0 - disToSun, 0, 1) * (1.0-isNight);
    vec3 finalColor = mix(mySkyColor, mySunColor, pow(sunMixFactor, 4));

    // 雾和月亮颜色混合
    float moonMixFactor = clamp(1.0 - disToMoon, 0, 1) * isNight;
    finalColor = mix(finalColor, mySunColor, pow(moonMixFactor, 4));

    return finalColor;
}

/*
 *  @function drawSkyFakeSun    : 绘制太阳的假反射
 *  @param positionInViewCoord  : 眼坐标
 *  @return                     : 太阳颜色
 */
vec3 drawSkyFakeSun(vec4 positionInViewCoord) {
    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005) {
        drawSun = mySunColor * 2 * (1.0-isNight);
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005) {
        drawMoon = mySunColor * 2 * isNight;
    }

    return drawSun + drawMoon;   
}
```

乍一看可能很多代码，其实都是绘制天空的函数 `drawSky`  里面复制过来的。只是因为我们不用进行距离判断，所以为了和天空绘制函数区别，单独提取出来：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021222824783.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

> 注：为啥要提取出来？因为天空的颜色和太阳颜色的混合方式不同。天空基色是通过菲涅尔透射系数进行线性混合，而太阳的颜色是直接叠加上去，故分开两个函数来写。


然后我们修改 `drawWater` 函数的代码，我们不仅要绘制水面，我们还要绘制天空的反射。首先我们注释掉之前绘制水面的代码：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021223553660.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
然后我们根据法线，计算反射光线的方向。我们添加一行：

```
// 计算反射光线方向
vec3 reflectDirection = reflect(positionInViewCoord.xyz, normal);
```

然后我们在透射混合之前，调用 `drawSkyFakeReflect` 函数，绘制带太阳染色的天空：

```
vec3 finalColor = drawSkyFakeReflect(vec4(reflectDirection, 0)); // 假反射 -- 天空颜色
finalColor *= wave; // 波浪纹理
```

然后我们在透射混合之后，调用 `drawSkyFakeSun`  函数，绘制太阳：

```
// 假反射 -- 太阳
finalColor += drawSkyFakeSun(vec4(reflectDirection, 0)); 
```

图示：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021223845642.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

然后重新加载光影包，我们可以看到清晰的假反射，的确和天空一一对应：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021224307521.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
## 添加抖动

现在我们的反射还有一些晓问题，比如虽然水面在不停地波动，但是水中的倒影却一直保持静止，这也太违和了。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021225312349.gif#pic_center)

解决方案也很简单，我们根据波浪的凹凸，给法线加一个扰动就可以了，我们在 drawWater 函数，计算反射光线之前添加：

```
// 按照波浪对法线进行偏移
vec3 newNormal = normal;
newNormal.z += 0.05 * (((wave-0.4)/0.6) * 2 - 1);
newNormal = normalize(newNormal);
```

我们对法线的 x 方向，根据波浪的扰动（wave变量），进行偏移。然后我们修改计算反射光线的代码:

```
// 计算反射光线方向
vec3 reflectDirection = reflect(positionInViewCoord.xyz, newNormal);
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023204803184.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


重新加载光影包，我们可以看到清晰的抖动了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201021235419620.gif#pic_center)


# 屏幕空间反射

现在我们拥有了一个勉强能看的水面，美中不足的是，我们的水面不能很好的反射方块：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023204559288.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


因为方块是动态的，并且能够被实时地更新。不像天空的颜色，我们希望获取方块的颜色，但是没有一个固定的公式来套用，我们无法通过单一的视线方向推导出反射方块的颜色。这就需要引入新的算法了。

**屏幕空间反射**，又称 SSR （Screen Space Reflect），我们通过光线追踪，模拟反射光线的行进过程，并且记录最终碰到的物体的颜色。一次朴素的SSR过程分为以下几个步骤：

1. 选取起始点
2. 算反射光线方向
3. 光线追踪 - - - 测试点沿着反射光线方向行进
4. 碰撞检测

我们通过一次连环画来详细描述这个过程。

第一步首先我们通过眼坐标系中的坐标，确定光线追踪的起始点：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023211333495.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

第二步随后我们利用反射体表面的法向量，计算出反射光线的方向：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023211518122.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

第三步我们让测试点从起始点开始，沿着反射光线的方向**逐步前进**：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023212229696.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

我们持续进行光线追踪，直到测试点 “命中” 了一个方块（即测试点在方块之后），我们停止迭代。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023212701367.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

如何判断测试点是否命中方块呢？我们通过比较：

1. 测试点 z 坐标（在屏幕坐标系下），记作 `z`
2. 深度缓冲中，测试点 xy 坐标对应的深度，记作 `depth`

来判断是否命中，如图：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023213212290.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

如果 z 大于 depth，则表示我们的测试点命中目标，反之则没命中。

如果命中目标，我们可以认为此时测试点所在位置的颜色，就是反射光线探测到的颜色。**（即我们利用测试点的屏幕坐标，对原画面纹理进行采样，获取该处目标物体的颜色）**

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023213526241.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
在了解了屏幕空间反射的基本的原理之后，我们可以着手编写一个简单的光线追踪器。我们在 composite.fsh 中加入：

```
/*
 *  @function rayTrace  : 光线追踪计算屏幕空间反射
 *  @param startPoint   : 光线追踪起始点
 *  @param direction    : 反射光线方向
 *  @return             : 反射光线碰到的方块的颜色 -- 即反射图像颜色
 */
vec3 rayTrace(vec3 startPoint, vec3 direction) {
    vec3 point = startPoint;    // 测试点

    // 20次迭代
    int iteration = 20;
    for(int i=0; i<iteration; i++) {
        point += direction * 0.2;   // 测试点沿着反射光线方向前进

        // 眼坐标转屏幕坐标 -- 这里直接一步到位
        vec4 positionInScreenCoord = gbufferProjection * vec4(point, 1.0);
        positionInScreenCoord.xyz /= positionInScreenCoord.w;
        positionInScreenCoord.xyz = positionInScreenCoord.xyz*0.5 + 0.5;
        
        // 剔除超出屏幕空间的射线 -- 因为我们需要从屏幕空间中取颜色
        if(positionInScreenCoord.x<0 || positionInScreenCoord.x>1 ||
           positionInScreenCoord.y<0 || positionInScreenCoord.y>1) {
            return vec3(0);
        }

        // 碰撞测试
        float depth = texture2D(depthtex0, positionInScreenCoord.st).x; // 深度
        // 成功命中或者达到最大迭代次数 -- 直接返回对应的颜色
        if(depth<positionInScreenCoord.z || i==iteration-1) {
            return texture2D(texture, positionInScreenCoord.st).rgb;
        }
    }

    return vec3(0);
}
```

在这个函数中，我们完成了一次简单的光线追踪。随后我们利用命中点的纹理坐标，即 texcoord.st（屏幕坐标），对原图像的纹理进行采样，然后返回对应的颜色。

值得注意的是，如果我们的测试点超出屏幕空间，即 [0, 1]，那么我们应该放弃测试，否则将会出现错误的结果，如图：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023215711821.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

现在我们拥有一个简易的光线追踪器，我们就可以开始着手编写水面反射的代码了。

我们在 composite.fsh 中，绘制水面的函数 `drawWater` 中，计算完波浪纹理之后，添加如下的调用：

```
// 屏幕空间反射
vec3 reflectColor = rayTrace(positionInViewCoord.xyz, reflectDirection);
finalColor = reflectColor;
```

图示：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023221457957.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

随后重新加载光影包，我们可以看到，反射出现了！！！


![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023221421624.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

但是与此同时，我们也发现之前精心绘制的水面不见了，这是因为我们直接使用反射光线来替代我们的水面，而反射光颜色有大部分都是黑色，即vec3(0)，这是因为**大部分测试都未命中**。

这么做显然是不合适的，我们希望将反射和基色混合一下再输出。我们将刚刚绘制反射的代码改为：

```
// 屏幕空间反射
vec3 reflectColor = rayTrace(positionInViewCoord.xyz, reflectDirection);
if(length(reflectColor)>0) {
    float fadeFactor = 1 - clamp(pow(abs(texcoord.x-0.5)*2, 2), 0, 1);
    finalColor = mix(finalColor, reflectColor, fadeFactor);
}
```

注意到 `fadeFactor` 变量，这个变量用来淡出屏幕边缘的反射，否则会形成非常尖锐的淡出效果。


我们根据 x 到屏幕中心（0.5）的距离，将反射颜色和基色进行混合。对比图：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023223913968.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

至此，我们拥有了一个比较好的（并不）屏幕空间反射的效果：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20201023233326339.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


















