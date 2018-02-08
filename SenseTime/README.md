# 金山云-商汤科技动态贴纸（AR直播）

## 1.概述

金山视频云全模块化的移动直播推流方案[UnionMobileStreaming](https://github.com/ksvc/UnionMobileStreaming_iOS)，是为了应对移动直播业务需求的任意拓宽，商汤在图像识别和图像处理有多年的技术积累，两家在各自领域的强者结合一定会产生出不一样的效果，下面我们就介绍一下，集成了金山全模块化采集、编码、推流功能和商汤人脸识别、图像处理功能的例子。


## 2.集成

### 2.1 需要从商汤获取安装包。[详细文档介绍](https://ks3-cn-beijing.ksyun.com/ksy.vcloud.sdk/Ios/%E7%89%B9%E6%95%88%E8%B4%B4%E7%BA%B8%E8%AF%B4%E6%98%8E%E6%96%87%E6%A1%A3%20v3.2.2.pdf)
### 2.2 需要从商汤获取license.
### 2.3 开源了金山封装的STFilterVC，把贴纸、美颜等特效做成一个滤镜，和其他美颜滤镜相同的使用方式。

## 3.STFilterVC接入步骤

### 3.1初始化(需要传入license）
验证license，初始化结果纹理和纹理缓存，初始化贴纸、美颜等特效句柄。

### 3.2接入相机采集到的数据
用UnionGPUPicOutput类来接入采集的数据，回调数据交给商汤sdk进行处理。

### 3.3传出商汤sdk处理后的数据
利用GPUImageTextureInput类来绑定输出纹理id(_textureFilterOutput)，将商汤sdk处理后的数据交给GPUImageTextureInput来预览和推流。

注意客户可自行选择业务需要的贴纸和美颜。 


## 4. 反馈与建议
### 4.1 金山云
* 主页：[金山云](http://www.ksyun.com/)
* 邮箱：<zengfanping@kingsoft.com>
* QQ讨论群：574179720
* Issues:https://github.com/ksvc/UnionDiversityLive_iOS/issues

### 4.2 商汤科技
* 主页：[SenseMe](http://www.sensetime.com/aboutUs/)
* 咨询电话：010-52725279（周一至周五 9:30 - 18:00）
* 商务合作：business@sensetime.com
* 媒体合作：media@sensetime.com
* 市场合作：mkt@sensetime.com