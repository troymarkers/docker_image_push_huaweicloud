# Docker Images Pusher huaweicloud

使用Github Action将国外的Docker镜像转存到华为云私有仓库，供国内服务器使用，免费易用<br>
- 支持DockerHub, gcr.io, k8s.io, ghcr.io等任意仓库<br>

本项目参考了大佬技术爬爬虾的 (https://github.com/tech-shrimp/me) 项目<br>

## 使用方式


### 配置华为云
#### 获取长期访问指令
华为云首页：https://www.huaweicloud.com/<br>
登录华为云，首页搜索容器，选择容器镜像服务 SWR<br>
![image](https://github.com/user-attachments/assets/29bf8d98-7d4e-437e-b172-82526202bc20)
<br>

点击控制台进入容器管理页面<br>
![image](https://github.com/user-attachments/assets/c46b2253-0a52-47ed-9d85-4ffadc4a8062)

<br>

在镜像服务控制台总览页面，选择右上角的登陆指令<br>
![image](https://github.com/user-attachments/assets/aff2a25f-1646-4fbe-9bf2-6ad289011cc1)

生成长期登陆指令并复制指令<br>
![image](https://github.com/user-attachments/assets/7f55a99a-a6ce-4d49-94d2-3853b20a0ab5)

例如长期登陆指令为：<br>
```
docker login -u cn-north-4@NKXXXXXXXXXXS -p 2xxxxxxxxxxxxxx6a2 swr.cn-north-4.myhuaweicloud.com
```


需要保存三个值，后面会用到：<br>
华为云用户名：cn-north-4@NKXXXXXXXXXXS<br>
华为云用户密码：2xxxxxxxxxxxxxx6a2<br>
华为云仓库地址：swr.cn-north-4.myhuaweicloud.com<br>

#### 创建组织

镜像服务控制台页面选择组织管理，然后创建组织，并复制组织名称<br>
![image](https://github.com/user-attachments/assets/4d5ba05f-00c2-4aac-aca2-0fc74da9269c)

现在已经获取到了到了四个值，以下四个变量分别代表：<br>

HW_REGISTRY：华为云仓库地址<br>
HW_ORG_NAME：华为云组织名称<br>
HW_REGISTRY_USER：华为云用户名<br>
HW_REGISTRY_PASSWORD：华为云用户密码<br>

### Fork本项目
Fork本项目<br>
#### 启动Action
进入自己的项目，点击Action，启用Github Action功能<br>
#### 配置环境变量
进入Settings->Secret and variables->Actions->New Repository secret<br>
将上一步的**四个值**<br>
HW_REGISTRY，HW_ORG_NAME，HW_REGISTRY_USER，HW_REGISTRY_PASSWORD<br>
配置成环境变量<br>
![image](https://github.com/user-attachments/assets/2aee2a32-9fb0-4d01-b026-c1909c414240)


### 添加镜像
#### txt文件内容
打开 `images.txt` 文件，每行一个镜像，格式为 `镜像名:版本号 [架构]`：<br>
- 官方镜像：直接写镜像名，如 `postgres:19beta1-trixie`、`nginx:stable-perl`<br>
- 第三方镜像：保持原命名空间，如 `bitnami/nginx:latest`<br>
- 不写版本号默认使用 `latest`，如 `redis` 等价于 `redis:latest`<br>
- 架构可选：不写默认 `amd64`，也可指定 `arm64`、`arm/v7` 等<br>
- 架构简写自动补全：写 `arm64` 等价于 `linux/arm64`，写 `linux/arm/v7` 保持原样<br>
- 以 `#` 开头的行视为**注释**，不会同步，可用于：<br>
  &nbsp;&nbsp;• 添加分类标题，按服务分组管理镜像<br>
  &nbsp;&nbsp;• 临时禁用某个镜像而不删除该行<br>
  &nbsp;&nbsp;• 在文件顶部添加格式说明和示例<br>

#### 标签规则
- **不指定架构**（默认）：仅推送 `{版本}-amd64` 标签，如 `19beta1-trixie-amd64`<br>
- **指定架构**：同时推送架构标签和通用标签，如 `stable-perl-arm64` + `stable-perl`<br>

#### 示例
`images.txt` 内容如下：
```
# ============================================
# 数据库（默认 amd64）
# ============================================
postgres:19beta1-trixie
redis:7-alpine

# ============================================
# 指定 ARM 架构
# ============================================
nginx:stable-perl arm64
alpine:3.21 linux/arm/v7

# ============================================
# 第三方镜像
# ============================================
bitnami/kafka:3.6

# ============================================
# 以下为被注释的镜像，不会同步
# ============================================
# mysql:8.0
# node:18-alpine
```

提交文件后，会自动执行 Github Action，向华为云镜像仓库上传镜像。<br>

> **提示**：修改 `images.txt`、`push_images.sh` 或 `.github/workflows/docker.yaml` 均会触发自动同步。

### 使用镜像
回到华为云，镜像仓库，点击任意镜像，可查看镜像状态，可以改成公开，拉取镜像免登录。<br>
![image](https://github.com/user-attachments/assets/352d1d64-728e-49a9-809f-d44486b43b0d)
<br>
要在服务器上拉取华为云镜像仓库中的镜像, 具体使用方法请打开仓库中的镜像详情查看。<br>
![image](https://github.com/user-attachments/assets/3671a5f6-2c12-4b86-b469-495b3dae1164)


### 工作流触发条件

编辑 `.github/workflows/docker.yaml` 可自定义触发方式。默认配置：

```yaml
on:
  workflow_dispatch:                         # 手动触发
  push:
    branches:
      - main
    paths:
      - 'images.txt'                        # images.txt 变更时触发
```

#### 定时执行
在 `on:` 下添加 `schedule` 即可定时同步（cron 使用 UTC 时区）：

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'                     # 每天 UTC 00:00（北京时间 08:00）
    - cron: '0 12 * * *'                    # 每天 UTC 12:00（北京时间 20:00）
  push:
    branches:
      - main
    paths:
      - 'images.txt'
```

#### PR 验证
添加 `pull_request` 触发器可在发起 PR 时自动验证镜像配置：

```yaml
on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - 'images.txt'
  pull_request:                             # PR 时验证
    branches:
      - main
    paths:
      - 'images.txt'
```

> **注意**：`schedule` 仅对默认分支（main）生效，最小间隔 5 分钟。`pull_request` 来自 fork 的 PR 无法访问 Secrets，推送会失败，仅用于格式验证。GitHub 在负载高时可能会延迟触发。
