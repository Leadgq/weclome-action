#!/usr/bin/env bash
set -euo pipefail
cd /opt/welcome-demo
release_id="$(date -u +%Y%m%dT%H%M%SZ)"
release_dir="/opt/welcome-demo/releases/$release_id/web"
backup_dir="/opt/welcome-demo-backups/$release_id"
mkdir -p "$backup_dir" "$release_dir"
cp /etc/nginx/conf.d/welcome-demo.conf "$backup_dir/nginx.conf"
docker inspect --format '{{.Image}}' welcome-demo-api > "$backup_dir/api-image-id.txt"
old_image="$(cat "$backup_dir/api-image-id.txt")"
docker image tag "$old_image" "welcome-demo-api:rollback-$release_id"
if [ -e current-web ] && [ ! -L current-web ]; then
  echo 'current-web must be a symlink, refusing to overwrite a directory'
  exit 1
fi
previous_web="$(readlink current-web || true)"
printf '%s\n' "$previous_web" > "$backup_dir/previous-web.txt"

# 先构建，线上仍使用旧版本。
docker build --target web --output "type=local,dest=$release_dir" .
chmod -R a+rX "$release_dir"
docker compose build api

rollback() {
  echo 'Deployment failed; restoring previous API image and Nginx configuration'
  docker image tag "$old_image" welcome-demo-api:latest
  docker compose up -d --no-build api
  cp "$backup_dir/nginx.conf" /etc/nginx/conf.d/welcome-demo.conf
  if [ -n "$previous_web" ]; then
    ln -sfn "$previous_web" /opt/welcome-demo/current-web
  fi
  nginx -t && systemctl reload nginx
}
trap rollback ERR

docker compose up -d --no-build api
ready=0
for attempt in $(seq 1 20); do
  if curl --fail --silent http://127.0.0.1:3002/api/health; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo 'API health check failed'
  false
fi
ln -sfn "$release_dir" /opt/welcome-demo/current-web
cp nginx.conf /etc/nginx/conf.d/welcome-demo.conf
nginx -t
systemctl reload nginx
curl --fail --silent -H "Host: 8.153.182.126" http://127.0.0.1/api/health
curl --fail --silent -H "Host: 8.153.182.126" http://127.0.0.1/ > /dev/null
trap - ERR
printf '\nRelease: %s\nBackup: %s\nURL: http://8.153.182.126/\n' "$release_id" "$backup_dir"
