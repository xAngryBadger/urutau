import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  // eslint-disable-next-line no-undef
  const env = loadEnv(mode, process.cwd(), '');

  if (mode === 'production' && !env.VITE_POCKETBASE_URL) {
    console.warn(
      '\x1b[33m[urutau-admin] WARNING: VITE_POCKETBASE_URL is not set in .env.production.' +
      ' The built app will fall back to window.location.origin, which will fail on GitHub Pages.' +
      ' Set VITE_POCKETBASE_URL before deploying.\x1b[0m',
    );
  }

  return {
    plugins: [react()],
    base: mode === 'production' ? (env.VITE_BASE_PATH || '/urutau-admin/') : '/',
  };
})
