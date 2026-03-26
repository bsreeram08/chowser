import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { writeFileSync, mkdirSync } from 'fs';
import { resolve } from 'path';

function generateViewHtml(view: string): import('vite').Plugin {
  return {
    name: 'generate-view-html',
    closeBundle() {
      const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script type="module" src="./${view}.js"></script>
    <link rel="stylesheet" href="./${view}.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>`;
      const outDir = resolve(__dirname, `build/views/${view}`);
      mkdirSync(outDir, { recursive: true });
      writeFileSync(`${outDir}/index.html`, html);
    },
  };
}

export default defineConfig(() => {
  const view = process.env.VIEW;

  if (view === 'picker' || view === 'settings') {
    return {
      plugins: [svelte(), generateViewHtml(view)],
      build: {
        outDir: `build/views/${view}`,
        emptyOutDir: true,
        rollupOptions: {
          input: { [view]: `src/views/${view}/index.html` },
          output: {
            dir: `build/views/${view}`,
            entryFileNames: '[name].js',
            chunkFileNames: '[name]-chunk.js',
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
    };
  }

  return {
    plugins: [svelte()],
    build: {
      outDir: 'build/views',
      emptyOutDir: true,
    },
    server: {
      middlewareMode: false,
      watch: {
        ignored: ['**/node_modules/**', '**/.git/**', '**/build/**'],
      },
    },
  };
});
