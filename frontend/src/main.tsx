import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { setupFetchInterceptor } from './utils/auth'
import { initTheme } from './utils/theme'

// Apply saved/OS theme synchronously before initial render
initTheme();

// Kích hoạt interceptor cho window.fetch
setupFetchInterceptor();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
