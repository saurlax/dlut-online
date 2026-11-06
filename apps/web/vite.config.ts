import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  appType: 'mpa',
  build: {
    outDir: 'out',
    rolldownOptions: {
      input: {
        home: resolve(import.meta.dirname, 'index.html'),
        game: resolve(import.meta.dirname, 'game/index.html'),
        notFound: resolve(import.meta.dirname, '404.html'),
      },
    },
  },
  server: {
    proxy: {
      '/api': { target: 'http://127.0.0.1:8415', ws: true },
      '/_': { target: 'http://127.0.0.1:8415' },
    },
  },
});
