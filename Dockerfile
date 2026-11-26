FROM node:22-bookworm-slim AS base
WORKDIR /workspace
RUN npm install --global pnpm@10.30.3 --registry=https://registry.npmjs.org

FROM base AS build
COPY . .
RUN pnpm install --frozen-lockfile --registry=https://registry.npmjs.org
RUN pnpm build

FROM build AS api-package
RUN pnpm --filter @welcome/api deploy --prod /out/api

FROM node:22-bookworm-slim AS api
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3002
COPY --from=api-package --chown=node:node /out/api/ ./
USER node
CMD ["node", "dist/server.js"]

FROM scratch AS web
COPY --from=build /workspace/apps/web/dist/ /
