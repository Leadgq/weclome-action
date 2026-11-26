# GitHub Actions 自动发布

工作流为 `.github/workflows/deploy.yml`。
推送到 master，或在 Actions 页面手动运行 master 分支时触发。

## 发布流程

1. 检出当前提交，准备 Node.js 22 和 package.json 指定版本的 pnpm。
2. 按锁文件安装依赖，构建 shared、api、web，再检查类型。
3. 打包明确列出的源码与配置，通过 SSH 上传到服务器。
4. 服务器加发布锁、备份旧源码，解压新源码。
5. 调用 deploy/server.sh，在 Docker 内重新构建 Linux 产物，更新后端和 Nginx。
6. 部署脚本检查站点和接口；切换失败时自动尝试恢复旧镜像与 Nginx 配置。

GitHub 上的构建用于尽早发现错误。服务器上的 Docker 构建用于生成实际运行产物，因此会构建两次。
前端仍由服务器 Nginx 提供，后端仍是 welcome-demo-api 容器。

## 首次配置

打开仓库 Settings → Secrets and variables → Actions → Secrets → New repository secret。

| Secret 名称 | 内容 |
| --- | --- |
| DEPLOY_HOST | 8.153.182.126 |
| DEPLOY_USER | root，当前脚本需要管理 Docker 和 Nginx 的权限 |
| DEPLOY_SSH_KEY | 能登录这台服务器的完整 SSH 私钥，包含 BEGIN/END 行 |
| DEPLOY_KNOWN_HOSTS | 已核实的服务器 SSH 主机公钥记录，格式与 known_hosts 相同 |

建议为 Actions 单独创建部署密钥，将公钥添加到服务器授权列表，私钥仅保存为 GitHub Secret。
不要把私钥提交到仓库，也不要把私钥内容发到聊天中。
DEPLOY_KNOWN_HOSTS 是服务器身份记录，不是你的登录公钥；可从此前已验证连接的 known_hosts 中取出对应记录。
如果使用非 22 端口，在 Variables 中新增 DEPLOY_PORT，并保证 known_hosts 对应这个端口。

服务器需要已有 /opt/welcome-demo、正在运行的 welcome-demo-api，以及 Docker Compose、Nginx、curl、flock 和 tar。
本次已部署的服务器满足这些前提，本工作流用于更新现有网站。
阿里云安全组需要允许 GitHub runner 连接 SSH 端口；连接超时时检查入方向规则。

## 查看结果

进入仓库 Actions → Deploy welcome-demo，查看每个步骤的日志。
没有配置 Secret 时，工作流会明确提示缺少哪个配置，不会部署。
配置完成后，可以在 Actions 页面使用 Run workflow，选择 master 验证第一次自动发布。

普通推送不需要手动登录服务器执行命令。
工作流串行发布，不会因新推送取消正在运行的发布。
不要在本机另一个终端并行解压源码到 /opt/welcome-demo；工作流持有服务器发布锁时应等待它完成。
