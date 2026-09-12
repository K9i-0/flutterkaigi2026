import { createRoot } from "react-dom/client";
import { readSiteTheme } from "./site-theme";
const params = new URLSearchParams(location.search);
const comparison =
  params.has("compare") ||
  ["cinema", "club"].includes(params.get("view") ?? "");
const root = createRoot(document.getElementById("root")!);
if (comparison) {
  void import("./main").then(({ default: Comparison }) =>
    root.render(<Comparison />),
  );
} else {
  document.documentElement.dataset.theme = readSiteTheme();
  void import("./review").then(({ default: Journal }) =>
    root.render(<Journal />),
  );
}
