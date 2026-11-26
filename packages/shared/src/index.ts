export interface HelloResponse {
  message: string
  time: string
}

export interface HealthResponse {
  status: 'ok'
  service: 'welcome-demo'
}

export function createHelloResponse(): HelloResponse {
  return {
    message: '你好呀！你的问候已抵达服务器，欢迎来到初见。',
    time: new Date().toISOString()
  }
}
