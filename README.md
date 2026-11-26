# 初见 · pnpm 多包 TypeScript 部署练习

从昨天的欢迎页 Demo 改造而来，保留页面和两个 API，不需要数据库。

## 结构

- apps/web：Vite + TypeScript，沿用原 HTML/CSS 页面。
- apps/api：Node.js HTTP + TypeScript，监听 127.0.0.1:3002。
- packages/shared：共用接口类型，以及后端实际调用的问候函数。
- pnpm-workspace.yaml：包范围、工作区依赖注入和构建后同步设置。
- pnpm-lock.yaml：根目录统一锁文件。
- Dockerfile：build、api-package、api、web 多阶段目标。
- deploy/server.sh：构建、备份、发布和失败回退。

原 api/、web/ 保留作对照，不参与新构建。现在修改 apps/ 和 packages/。

## 本地运行

需要 Node.js 22 和 pnpm 10.30.3，在工程根目录执行。

```powershell
pnpm install --frozen-lockfile
pnpm build
pnpm typecheck
```

打开两个终端，分别执行 pnpm dev:api 和 pnpm dev:web，访问 Vite 打印的地址。
shared 改动后重新执行 pnpm --filter @welcome/shared build，或重启两条开发命令。

## 与昨天相比，部署多了什么

1. Docker 构建上下文为整个仓库，后端才能获得 shared。
2. pnpm install --frozen-lockfile 按统一锁文件安装。
3. pnpm build 按依赖关系先编译 shared，再编译 api 和 web。
4. pnpm --filter @welcome/api deploy --prod /out/api 导出后端和生产依赖，包含 shared。
5. 最终后端镜像仅复制 /out/api，用 node dist/server.js 启动，不需要 TypeScript 和 pnpm。
6. web 目标导出前端静态产物，交给宿主机 Nginx，无需常驻前端 Node 服务。

pnpm 10 的 deploy 配合 injectWorkspacePackages 和 syncInjectedDepsAfterScripts 使用。
不要直接把整个工作区的 node_modules 复制到后端镜像。
参考 [pnpm 10 Docker 示例](https://pnpm.io/10.x/docker) 和 [deploy 命令](https://pnpm.io/10.x/cli/deploy)。

## 服务器发布

源码上传到 /opt/welcome-demo，排除 node_modules、dist、.deploy 和旧 api/、web/。
Windows 的 node_modules 不要上传到 Linux。

```bash
cd /opt/welcome-demo
bash deploy/server.sh
```

脚本中的核心命令如下。

```bash
# 用 Docker 构建前端并导出静态文件，版本号替换为本次时间戳
docker build --target web --output type=local,dest=/opt/welcome-demo/releases/版本号/web .
# 构建并更新后端
docker compose build api
docker compose up -d --no-build api
# 检查并重载 Nginx
nginx -t
systemctl reload nginx
```

访问 <http://8.153.182.126/>，点击“发送 Hello”。
Nginx 的 current-web 是指向本次前端发布目录的软链接，/api/ 代理到后端 3002。

```bash
cd /opt/welcome-demo
docker compose ps
docker compose logs --tail 50 api
curl http://127.0.0.1:3002/api/health
readlink /opt/welcome-demo/current-web
```

## 备份与回退

本地改造前备份在同级 welcome-demo-backup-时间戳。
服务器首次改造前的源码压缩包位置见 deploy/实际部署记录.md。
部署脚本每次保留 welcome-demo-api:rollback-时间戳 镜像、旧 Nginx 配置和 previous-web.txt。
切换或检查失败时，脚本自动尝试恢复旧镜像和站点配置；构建失败时旧站点继续运行。

手动回退时使用脚本输出的时间戳。

```bash
cd /opt/welcome-demo
docker image tag welcome-demo-api:rollback-时间戳 welcome-demo-api:latest
docker compose up -d --no-build api
cp /opt/welcome-demo-backups/时间戳/nginx.conf /etc/nginx/conf.d/welcome-demo.conf
# 后续发布回退还需要将 current-web 指向 previous-web.txt 记录的旧路径
nginx -t
systemctl reload nginx
```
