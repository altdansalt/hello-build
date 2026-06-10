import { readFileSync } from "node:fs";
import { strict as assert } from "node:assert";

const html = readFileSync("dist/index.html", "utf8");

assert.match(html, /<h1>Hello from Bazel Node<\/h1>/);
assert.match(html, /built with node 22\./);
