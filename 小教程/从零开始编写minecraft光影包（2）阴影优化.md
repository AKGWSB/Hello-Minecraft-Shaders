**完整资源：**

 [我的Github地址](https://github.com/AKGWSB/Hello-Minecraft-Shaders/tree/master)

**前情提要：**

[从0开始编写minecraft光影包（0）GLSL，坐标系，光影包结构介绍](https://blog.csdn.net/weixin_44176696/article/details/108152896)

[从零开始编写minecraft光影包（1）基础阴影绘制](https://blog.csdn.net/weixin_44176696/article/details/108625077)

@[TOC](目录)


# 前言
今天~~没啥课了~~ ，继续填坑

上回提到基础阴影的种种问题，比如：

比如分辨率堪忧，阴影的细节不够还原

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200916232749730.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

或者是阴影的误判：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200916232911209.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
# 阴影绘制误判解决方案

通过观察发现，误判的情况往往发生在光线平行于方块表面时：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917105510671.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

而且mc默认的太阳，运行轨迹永远是在正上方的：


![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917105818532.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
正上方的太阳有一个问题，就是无论何时，太阳光方向，都能和所以方块的侧面平行：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917110237196.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


这个问题有一个简单的解决方案，那就是修改太阳的偏移角度，而 shadermod 中设置了一个**可控变量**来描述

> 所谓可控变量，就是通过设置这些变量，来修改一些默认的光影设置。比如太阳的运行轨迹，就是shadermod默认生成的，但是可以通过改变可控变量，进行修改。

通过可控变量修改太阳运行轨迹的方法很简单，在**顶点着色器**（任意一个）中加入：

```
const float	sunPathRotation	= -40.0;
```

即可修改太阳的偏移角度（0就是mc的默认值）：

修改之后，太阳会按照偏移的较度运行，入射光和方块表明平行的情况相对较少了。。。 但是注意，修改太阳偏移角之后，一天中总有某个时间段，太阳入射光平行于方块表明，但是这个时间段~~短到可以接受~~  

~~好吧其实我是懒狗，加一个法线判断一下就好了，关于法线打算留到水面反射的绘制再进行讲解，那时候再补上吧。。咕了~~ 

可以看到，入射光和方块表明平行的情况少了，但是任然存在阴影分辨率不足的问题：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917111137557.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


# 提高shadow纹理的分辨率

[上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108625077)讲到阴影的绘制，离不开shadow纹理，所以shadow纹理的精细度，决定了阴影的质量。和太阳偏移角一样，我们可以通过设置可控变量来实现修改：

在任意顶点着色器中加入：

```
const int shadowMapResolution = 4096;  
```

其中shadow纹理默认的分辨率是1024，我们将其变为原来的4倍：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917112018702.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

可以看到效果还是十分有效的，因为精度提高，误判减少了，而且阴影分辨率变高了：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917112332572.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

~~但是，这一切值得吗~~ 

因为shadow纹理是shadermod预先绘制的，那么提高分辨率，性能就会下降，会掉帧。。。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917112633637.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
所以，单纯提升shadow纹理的分辨率，不是一个好的方法，那么有没有什么方法，能够不改变纹理分辨率，而提升细节呢？这就需要引入鱼眼镜头这个概念了

# 鱼眼镜头

熟话说一个萝卜一个坑，纹理分辨率不变，就这么大，如何提升细节？ 没法。我们没法提升每一个像素的细节。

但是我们能够为靠近纹理中间（）的采样分配更多的空间，而挤压屏幕边缘的采样并且分配较少的空间，因为玩家往往关注场景中心的内容

~~这波啊这波是抓大放小~~

> 根据上一篇博客提到的特性，因为shaodow纹理是太阳的视角，而太阳总是在玩家的头顶，所以**shadow纹理的中心对齐玩家所在的场景中心**
> ![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917114432928.gif#pic_center)


 我们在**顶点着色器**中，对 `gl_Position` 也就是裁剪坐标进行变换，我们利用 length() 函数，计算二维屏幕上，像素到屏幕中心的距离，根据距离做出变换：

1. 距离屏幕中心**近**的采样点，我们放大其坐标，即分配纹理上更**多**的“坑位”给它
2. 距离屏幕中心**远**的采样点，我们挤压其坐标，即分配纹理上更**少**的“坑位”给它



![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917164149426.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

可以观察屏幕中间的黑色方块，在没有鱼眼镜头的情况下，众生平等，但是鱼眼镜头会加深中心采样点的细节。可以看到，同样大小的屏幕，鱼眼镜头处理过中心黑色方块，占用的空间更大，拥有更多的细节。

> 这正好符合我们对shadow纹理的期望，即纹理的中心处拥有更多的的细节。

# 使用鱼眼镜头变换绘制shadow纹理

还记得[上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108625077)提到的shadow纹理吗？

我们编写 shadow.fsh 和 shadow.vsh，负责shadow纹理的绘制。

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917172318931.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


在顶点着色器中，我们根据像素点到屏幕中心的距离，对 gl_Position 也就是标准化的裁剪坐标进行缩放，然后在片段着色器中直接输出即可。

记住：
1. 距离屏幕中心**近**的采样点，我们放大其坐标，即分配纹理上更**多**的“坑位”给它
2. 距离屏幕中心**远**的采样点，我们挤压其坐标，即分配纹理上更**少**的“坑位”给它


shadow.vsh :

```
#version 120

varying vec4 texcoord;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

void main() {
    gl_Position = ftransform();
    gl_Position.xy = getFishEyeCoord(gl_Position.xy);
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
```

shadow.fsh :

```
#version 120

uniform sampler2D texture;
varying vec4 texcoord;

void main() {
    vec4 color = texture2D(texture, texcoord.st);
    gl_FragData[0] = color;
}
```

如果我们使用

```
gl_FragData[0] =  texture2D(shadow, texcoord.st);
```
直接输出shadow纹理中的数据的话，可以看到：

如图：**我们将时间调整到6000，此时太阳在正上方**。得到如下的俯视图和shadow纹理（注意黄圈中树的排布）：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917173754943.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

我们对比鱼眼变换前后的shadow纹理：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917174220310.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

可以看到，进行鱼眼镜头变换之后，纹理中心的采样点，占据的空间大，像素多，自然包含更多的信息。

> 原本需要 10 * 10 的像素描述一棵树的深度信息，现在用 20 * 20，包含更多的深度信息



# 使用变换后的坐标查询shadow纹理

因为shadow纹理的绘制阶段，我们扭曲了坐标，那么相应的，在查询shadow的时候，也要对坐标做对应的变换，还记得刚刚的**坐标变换函数**吗，添加到compsite.fsh中：

```
vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}
```

我们在绘制阴影的函数中，计算完ndc坐标之后，加入一行：

```
positionInSunNdcCoord.xy = getFishEyeCoord(positionInSunNdcCoord.xy);
```

~~大概在这个位置~~ 

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917184022421.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
再次加载光影包，可以发现，**shadow纹理分辨率相同的情况下**，阴影的品质有了很大的提高：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917185603469.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 软阴影
在现实世界中，阴影的边缘很少呈现出尖锐的跳变，取而代之，现实中的阴影，都是有模糊的边界作为过渡的：

~~如图：宿舍楼下随手抓拍~~ 

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917190247511.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
说到模糊，就不得不提一下高斯模糊，即使用
```
0.1, 0.1, 0.1
0.1, 0.1, 0.1
0.1, 0.1, 0.1
```
作为 3 x 3 卷积核对图像进行卷积，卷积，~~想必懂的都懂~~ ，这里放一张我专业英语作业里面画的图~~偷懒了。。~~ 

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917190953561.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

说白了就是一个像素和他周围 8 个像素像素值取平均（平滑滤波），这叫做半径为 1 的高斯模糊。增加高斯模糊的半径可以提升模糊的品质。

对于阴影的判断只有 0 和 1，表示不在 / 在阴影中，所以边缘非常尖锐，我们希望通过模糊来实现边缘的平滑过渡。

我们对每一次shadow纹理中的采样：
1. 访问它旁边的8个点
2. 统计在阴影中的点的数目 sum
3. 数目多则该点应该更加黑（在阴影中），反之应该更加白（靠近阴影边缘）。
4. 根据 sum 数值，改变像素的亮度

还记得[上一篇博客](https://blog.csdn.net/weixin_44176696/article/details/108625077)提到的判断阴影的方法吗？通过距离判断。在 composite.fsh 中，getShadow 函数内，将下面的判断阴影的代码

```
// 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
if(closest+0.0001 <= currentDepth) {
    color.rgb *= 0.5;   // 涂黑
}
```

改为

```
int radius = 1;
float sum = pow(radius*2+1, 2);
float shadowStrength = 0.6;	// 阴影强度
for(int x=-radius; x<=radius; x++) {
    for(int y=-radius; y<=radius; y++) {
        // 采样偏移
        vec2 offset = vec2(x,y) / shadowMapResolution;
        // 光照图中最近的点的深度
        float closest = texture2D(shadow, positionInSunScreenCoord.xy + offset).x;   
        // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
        if(closest+0.001 <= currentDepth) {
            sum -= 1; // 涂黑
        }
    }
}
sum /= pow(radius*2+1, 2);
color.rgb *= sum*shadowStrength + (1-shadowStrength);  
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917193751398.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)


其中 radius 是高斯模糊的半径，sum是统计不在阴影中的点的个数。shadowStrength 是阴影强度。

重载光影，相比于未模糊的版本（左），我们得到了一个很好的模糊效果（右）

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917192628567.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

# 修复小瑕疵
虽然有了一个好的阴影效果，但是还是有两个小瑕疵

1. 天空被错误的染黑
2. 远处的阴影因为鱼眼镜头的挤压，绘制的十分突兀

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917193235935.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

我们通过 “我的世界坐标” 计算像素的的距离：

```
float dis = length(positionInWorldCoord.xyz) / far;
```

别忘了在开头引入 far 变量，这个变量是shadermod提供的变量，表示当前视距下最远距离，用以归一化距离到 [0, 1] 区间：

```
uniform float far;
```

然后通过距离判断，过于远的点，比如天空，就不绘制阴影了：

此外，shadowStrength 取决于 dis，即当前点的距离，越远的点阴影越淡，以过渡远处的阴影。

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020091719421810.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)

再次重载光影包：

![在这里插入图片描述](https://img-blog.csdnimg.cn/2020091719453573.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
我们终于得到了一个姑且能看的阴影效果了。。。

# 完整代码
 [我的Github地址](https://github.com/AKGWSB/Hello-Minecraft-Shaders/tree/master)

# shadow.vsh
```
#version 120

varying vec4 texcoord;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

void main() {
    gl_Position = ftransform();
    gl_Position.xy = getFishEyeCoord(gl_Position.xy);
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
```
# shadow.fsh
```
#version 120

uniform sampler2D texture;
varying vec4 texcoord;

void main() {
    vec4 color = texture2D(texture, texcoord.st);
    gl_FragData[0] = color;
}
```
# composite.vsh
```
#version 120

varying vec4 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
```
# composite.fsh
```
#version 120

const int shadowMapResolution = 1024;   // 阴影分辨率 默认 1024
const float	sunPathRotation	= -40.0;    // 太阳偏移角 默认 0

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying vec4 texcoord;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

/*
 * @function getShadow         : getShadow 渲染阴影
 * @param color                : 原始颜色
 * @param positionInWorldCoord : 该点在世界坐标系下的坐标
 * @return                     : 渲染阴影之后的颜色
 */
vec4 getShadow(vec4 color, vec4 positionInWorldCoord) {
    // 我的世界坐标 转 太阳的眼坐标
    vec4 positionInSunViewCoord = shadowModelView * positionInWorldCoord;
    // 太阳的眼坐标 转 太阳的裁剪坐标
    vec4 positionInSunClipCoord = shadowProjection * positionInSunViewCoord;
    // 太阳的裁剪坐标 转 太阳的ndc坐标
    vec4 positionInSunNdcCoord = vec4(positionInSunClipCoord.xyz/positionInSunClipCoord.w, 1.0);

    positionInSunNdcCoord.xy = getFishEyeCoord(positionInSunNdcCoord.xy);

    // 太阳的ndc坐标 转 太阳的屏幕坐标
    vec4 positionInSunScreenCoord = positionInSunNdcCoord * 0.5 + 0.5;

    float currentDepth = positionInSunScreenCoord.z;    // 当前点的深度
    float dis = length(positionInWorldCoord.xyz) / far;

    /*
    float closest = texture2D(shadow, positionInSunScreenCoord.xy).x; 
    // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
    if(closest+0.0001 <= currentDepth && dis<0.99) {
        color.rgb *= 0.5;   // 涂黑
    }
    */
    
    int radius = 1;
    float sum = pow(radius*2+1, 2);
    float shadowStrength = 0.6 * (1-dis);
    for(int x=-radius; x<=radius; x++) {
        for(int y=-radius; y<=radius; y++) {
            // 采样偏移
            vec2 offset = vec2(x,y) / shadowMapResolution;
            // 光照图中最近的点的深度
            float closest = texture2D(shadow, positionInSunScreenCoord.xy + offset).x;   
            // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
            if(closest+0.001 <= currentDepth && dis<0.99) {
                sum -= 1; // 涂黑
            }
        }
    }
    sum /= pow(radius*2+1, 2);
    color.rgb *= sum*shadowStrength + (1-shadowStrength);  
    

    return color;
}


/* DRAWBUFFERS: 0 */
void main() {
    //vec4 color = texture2D(shadow, texcoord.st);
    vec4 color = texture2D(texture, texcoord.st);

    float depth = texture2D(depthtex0, texcoord.st).x;
    
    // 利用深度缓冲建立带深度的ndc坐标
    vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth*2-1, 1);

    // 逆投影变换 -- ndc坐标转到裁剪坐标
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;

    // 透视除法 -- 裁剪坐标转到眼坐标
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0);

    // 逆 “视图模型” 变换 -- 眼坐标转 “我的世界坐标” 
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;

    color = getShadow(color, positionInWorldCoord);
    
    gl_FragData[0] = color;
}
```
# 小结

本次博客使用两种方法优化阴影
1. 改shadow纹理分辨率（不推荐，性能损失太大）
2. 使用鱼眼镜头变换得到更好品质的阴影（推荐）

当然，也可以通过两者结合，使用鱼眼镜头的同时调高shadow纹理分辨率，如果你在高品质的mc画质下，会有惊艳的效果：

如图：使用 
```
const int shadowMapResolution = 4096;   // 阴影分辨率 默认 1024
```

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917195240679.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
其实使用 1024 分辨率的，已经可以达到很好的效果了 ~~差不多得了~~ 

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200917195801429.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_70,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dlaXhpbl80NDE3NjY5Ng==,size_16,color_FFFFFF,t_70#pic_center)
~~—。。。咕。。。~~ 
