import "./style.css";
import { GyunGyunQuest } from "./game";

const root = document.querySelector<HTMLElement>("#app");

if (!root) throw new Error("#app が見つかりません");

new GyunGyunQuest(root);
