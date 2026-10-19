import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  computerDisplayName,
  computerPlatformLabel,
} from "../../docs/app/app-formatters.js";

test("paired computers are labelled with their operating system", () => {
  assert.equal(computerPlatformLabel("windows"), "Windows");
  assert.equal(computerPlatformLabel("macos"), "macOS");
  assert.equal(computerPlatformLabel("linux"), "Linux");
  assert.equal(computerPlatformLabel("plan9"), "");
  assert.equal(
    computerDisplayName({ hostName: "JARVIS", hostPlatform: "windows" }),
    "JARVIS · Windows",
  );
  assert.equal(computerDisplayName({ hostName: "JARVIS" }), "JARVIS");
  assert.equal(computerDisplayName(null), "DingDong 电脑");
});

test("Agent notifications name the computer that sent them", () => {
  const worker = readFileSync(
    new URL("../../docs/app/service-worker.js", import.meta.url),
    "utf8",
  );
  assert.match(
    worker,
    /withComputerName\(\s*systemAgentNotificationTitle\(message\),\s*pair\.hostName,?\s*\)/,
  );
});

test("the Android app offer only trusts HTTPS GitHub or same-site downloads", () => {
  const installation = readFileSync(
    new URL("../../docs/app/app-installation.js", import.meta.url),
    "utf8",
  );
  assert.match(installation, /url\.protocol === "https:"/);
  assert.match(installation, /url\.hostname === "github\.com"/);
  assert.match(installation, /isAndroid\(\) && state\.androidApp/);
});
