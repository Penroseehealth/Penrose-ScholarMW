import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Relative base so the same dist/ works standalone and under /mathsdrill/ inside Penrose.
export default defineConfig({
  base: './',
  plugins: [react()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
  },
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    allowedHosts: [
      'pv-286168ac3f78-85433e0d-405b-4dba-afaf-751e58db0ce4.style.dev',
      'localhost',
      '127.0.0.1',
    ],
  },
});
