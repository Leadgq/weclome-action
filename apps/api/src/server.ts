import { createServer } from 'node:http'
import { createHelloResponse } from '@welcome/shared'
import type { HealthResponse, HelloResponse } from '@welcome/shared'

const port = Number(process.env.PORT || 3002)
const server = createServer((request, response) => {
  response.setHeader('Content-Type', 'application/json; charset=utf-8')
  response.setHeader('Cache-Control', 'no-store')
  response.setHeader('X-Content-Type-Options', 'nosniff')
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.setHeader('Allow', 'GET, HEAD')
    response.writeHead(405)
    response.end(JSON.stringify({ message: '仅支持 GET 和 HEAD 请求' }))
    return
  }
  const path = new URL(request.url || '/', 'http://localhost').pathname
  let data: HelloResponse | HealthResponse
  if (path === '/api/hello') {
    data = createHelloResponse()
  } else if (path === '/api/health') {
    data = { status: 'ok', service: 'welcome-demo' }
  } else {
    response.writeHead(404)
    response.end(JSON.stringify({ message: '接口不存在' }))
    return
  }
  response.writeHead(200)
  response.end(request.method === 'HEAD' ? undefined : JSON.stringify(data))
})

server.listen(port, '127.0.0.1', () => {
  console.log('Welcome demo API listening on 127.0.0.1:' + port)
})
process.on('SIGTERM', () => {
  server.close(() => process.exit(0))
})
