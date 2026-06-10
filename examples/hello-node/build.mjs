import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const message = readFileSync("src/message.txt", "utf8").trim();
const nodeVersion = process.versions.node;

mkdirSync("dist", { recursive: true });
writeFileSync(
  "dist/index.html",
  `<!doctype html>
<meta charset="utf-8">
<title>hello-node</title>
<h1>${message}</h1>
<p>built with node ${nodeVersion}</p>
`,
);
