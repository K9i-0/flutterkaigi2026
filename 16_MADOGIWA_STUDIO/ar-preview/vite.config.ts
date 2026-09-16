import path from "node:path";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
// Static-only preview: no Worker, database, admin or upload endpoints.
export default defineConfig({
  root: path.resolve(import.meta.dirname),
  publicDir: false,
  plugins: [react()],
  server: { port: 5175, strictPort: true },
  build: { outDir: path.resolve(import.meta.dirname, "../dist-ar-preview"), emptyOutDir: true },
});
