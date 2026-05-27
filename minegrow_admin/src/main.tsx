import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

// Wake the Render backend from cold start as early as possible.
const baseUrl = (import.meta.env.VITE_BASE_URL || '').replace(/\/api\/v\d+\/?$/, '');
if (baseUrl) fetch(`${baseUrl}/health`).catch(() => {});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
