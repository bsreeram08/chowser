# Chowser Docs

A modern landing page and documentation site for Chowser, built with React, Vite, and shadcn/ui.

## Tech Stack

- **Framework**: [React 19](https://react.dev/) + [Vite](https://vitejs.dev/)
- **Language**: [TypeScript](https://www.typescriptlang.org/)
- **Styling**: [Tailwind CSS v4](https://tailwindcss.com/)
- **UI Components**: [shadcn/ui](https://ui.shadcn.com/) (Radix UI)
- **Icons**: [Lucide React](https://lucide.dev/) & [Remix Icon](https://remixicon.com/)
- **Routing**: [React Router](https://reactrouter.com/)

## Getting Started

### Prerequisites

- Node.js (v18 or newer)
- npm, yarn, pnpm, or bun

### Installation

1. Clone the repository and navigate to the `docs` directory:
   ```bash
   cd docs
   ```
2. Install the dependencies:
   ```bash
   npm install
   # or with bun: bun install
   ```

### Running the Dev Server

Start the development server with hot-module replacement (HMR):

```bash
npm run dev
# or with bun: bun run dev
```

Visit `http://localhost:5173` in your browser.

### Building for Production

```bash
npm run build
# or with bun: bun run build
```

This will generate a `dist` folder ready for deployment.

## Features

- **Modern Landing Page**: Sleek UI to introduce the Chowser macOS app.
- **Agentic Setup Guide**: Comprehensive instructions for AI-driven configuration.
- **Responsive Design**: fully optimized for mobile and desktop screens.
- **Dark Mode**: built-in dark mode support via `next-themes`.

## Project Structure

```
docs/
├── public/                 # Static assets
│   ├── CNAME               # Custom domain configuration for GitHub Pages
│   └── agentic-setup.md    # Markdown file for the AI prompt
├── src/                    # Source code
│   ├── App.tsx             # Root React component
│   ├── main.tsx            # Entry point
│   ├── index.css           # Global styles & Tailwind configuration
│   ├── components/         # Reusable UI components (shadcn ui + custom)
│   ├── hooks/              # Custom React hooks
│   ├── lib/                # Utility functions
│   └── pages/              # Page components (Home, AgenticSetup, etc.)
├── package.json            # Project metadata and dependencies
├── vite.config.ts          # Vite configuration
└── tsconfig.json           # TypeScript configuration
```

## Contributing

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
