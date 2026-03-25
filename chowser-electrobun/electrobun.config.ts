import type { ElectrobunConfig } from "electrobun";

const config: ElectrobunConfig = {
  app: {
    name: "Chowser",
    identifier: "in.sreerams.chowser-electrobun",
    version: "0.1.0",
    description:
      "Smart browser router — intercept links and route them to the right browser",
    // Register as a handler for http, https, and chowser:// deep links.
    // After installing and running the app, go to System Settings → Desktop & Dock
    // (or use the in-app "Set as Default Browser" button) to make Chowser the
    // default handler for http and https.
    urlSchemes: ["http", "https", "chowser"],
  },
  build: {
    bun: {
      entrypoint: "src/bun/index.ts",
    },
    views: {
      picker: {
        entrypoint: "build/views/src/views/picker/index.html",
      },
      settings: {
        entrypoint: "build/views/src/views/settings/index.html",
      },
    },
    mac: {
      // Path to the .iconset folder containing app icon PNGs
      icons: "icon.iconset",
      entitlements: {
        // Required for Bun JIT to work with Hardened Runtime (needed for notarization)
        "com.apple.security.cs.allow-jit": true,
        "com.apple.security.cs.allow-unsigned-executable-memory": true,
        "com.apple.security.cs.disable-library-validation": true,
      },
    },
    win: {
      // Icon for Windows installer (ICO format recommended)
      icon: "icon.iconset/icon_256x256.png",
    },
    linux: {
      // Icon for Linux application
      icon: "icon.iconset/icon_256x256.png",
    },
  },
  runtime: {
    // Keep the app alive even when all windows are closed — it lives in the menu bar
    exitOnLastWindowClosed: false,
  },
};

export default config;
