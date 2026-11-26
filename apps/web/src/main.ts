import './style.css'
import type { HelloResponse } from '@welcome/shared'

const button = document.querySelector<HTMLButtonElement>('#hello-button')!
const status = document.querySelector<HTMLElement>('#connection-status')!
const responsePanel = document.querySelector<HTMLElement>('#response')!
const message = document.querySelector<HTMLElement>('#response-message')!
const time = document.querySelector<HTMLElement>('#response-time')!

async function sayHello() {
  if (button.disabled) {
    return
  }
  button.disabled = true
  status.textContent = '正在向服务器发送问候…'
  try {
    const response = await fetch('/api/hello', { cache: 'no-store' })
    if (!response.ok) {
      throw new Error('接口返回 HTTP ' + response.status)
    }
    const result: HelloResponse = await response.json()
    message.textContent = result.message
    time.textContent = '服务器时间 ' + new Date(result.time).toLocaleString('zh-CN', { hour12: false })
    responsePanel.hidden = false
    status.textContent = '连接成功，服务器已回应'
  } catch (error) {
    message.textContent = error instanceof Error ? error.message : '请求失败，请重试'
    time.textContent = ''
    responsePanel.hidden = false
    status.textContent = '暂时未能连接，请再试一次'
  } finally {
    button.disabled = false
  }
}

button.addEventListener('click', sayHello)
