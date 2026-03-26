import type { ElectrobunConfig } from "electrobun";

const config: ElectrobunConfig = {
  app: {
    name: "Chowser",
    identifier: "in.sreerams.chowser-electrobun",
    version: "0.1.0",
    description:
      "Smart browser router — intercept links and route them to the right browser",
    urlSchemes: ["http", "https", "chowser"],
  },
  build: {
    bun: {
      entrypoint: "src/bun/index.ts",
    },
    views: {},
    copy: {
      "build/views/picker": "views/picker",
      "build/views/settings": "views/settings",
      "icon.iconset/icon_16x16.png": "icons/icon_16x16.png",
      "icon.iconset/icon_16x16@2x.png": "icons/icon_16x16@2x.png",
    },
    mac: {
      icons: "icon.iconset",
      entitlements: {
        "com.apple.security.cs.allow-jit": true,
        "com.apple.security.cs.allow-unsigned-executable-memory": true,
        "com.apple.security.cs.disable-library-validation": true,
      },
    },
    win: {
      icon: "assets/icons/icon-512.png",
    },
    linux: {
      icon: "assets/icons/icon-256.png",
    },
  },
  runtime: {
    exitOnLastWindowClosed: false,
  },
};

export default config;
