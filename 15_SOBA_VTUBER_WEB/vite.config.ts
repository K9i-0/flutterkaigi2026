import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  server: {
    port: 5215,
    strictPort: true,
    host: "127.0.0.1",
    fs: {
      allow: [".."],
    },
  },
});
