import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
export default defineConfig({
  root: fileURLToPath(new URL(".", import.meta.url)),
  plugins: [react()],
  publicDir: fileURLToPath(new URL("../public", import.meta.url)),
  server: {
    host: "0.0.0.0",
    port: 4173,
    strictPort: true,
    proxy: Object.fromEntries(["/api/episodes", "/api/gallery-items", "/media/", "/posters/", "/gallery-images/"].map(path => [path, { target: "https://madogiwa.work", changeOrigin: true }])),
    fs: { allow: [fileURLToPath(new URL("../..", import.meta.url))] },
  },
  build: { outDir: "dist" },
});
