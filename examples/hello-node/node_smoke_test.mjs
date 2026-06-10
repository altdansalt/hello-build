import { readFileSync } from "node:fs";
import { strict as assert } from "node:assert";

const major = Number(process.versions.node.split(".")[0]);
const message = readFileSync("src/message.txt", "utf8").trim();

assert.equal(major, 22);
assert.equal(message, "Hello from Bazel Node");
