import path from "node:path";
import tailwindcss from "@tailwindcss/vite";
import { cloudflare } from "@cloudflare/vite-plugin";
import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { localClips } from "./tools/local-clips-plugin";

export default defineConfig({
  plugins: [
    localClips(),
    cloudflare({ viteEnvironment: { name: "ssr" } }),
    tanstackStart(),
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: { "@": path.resolve(import.meta.dirname, "./src") },
  },
});
