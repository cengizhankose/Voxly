import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Tauri expects a fixed port, fail if unavailable
export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    watch: {
      // Don't watch the Rust backend
      ignored: ["**/src-tauri/**"],
    },
  },
  build: {
    target: "safari15",
    minify: "esbuild",
    sourcemap: false,
  },
});
