import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  base: './',
  plugins: [svelte()],
  build: {
    outDir: 'build/views',
    emptyOutDir: false,
    rollupOptions: {
      input: {
        picker: 'src/views/picker/index.html',
        settings: 'src/views/settings/index.html',
      },
      output: {
        dir: 'build/views',
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name][extname]',
      },
    },
  },
  server: {
    middlewareMode: false,
    watch: {
      ignored: ['**/node_modules/**', '**/.git/**', '**/build/**'],
    },
  },
});
