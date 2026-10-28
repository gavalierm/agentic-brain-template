// Test hooku bin/repeat_guard.mjs: prehrá vstupy a overí kód a stderr.
// Stav hooku ide do dočasného priečinka (TMPDIR), nie do skutočného.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const GUARD = join(dirname(fileURLToPath(import.meta.url)), "..", "bin", "repeat_guard.mjs");
const SANDBOX = mkdtempSync(join(tmpdir(), "repeat-guard-test-"));
let counter = 0;

function newSession() {
  return `test-${process.pid}-${++counter}`;
}

function run(session, command) {
  const input = JSON.stringify({ session_id: session, tool_input: { command } });
  return runRaw(input);
}

function runRaw(input) {
  const r = spawnSync("node", [GUARD], { input, encoding: "utf8", env: { ...process.env, TMPDIR: SANDBOX } });
  return { code: r.status, stderr: r.stderr };
}

test.after(() => rmSync(SANDBOX, { recursive: true, force: true }));

test("dva behy curl s rôznymi argumentmi prejdú, tretí skončí 2", () => {
  const s = newSession();
  assert.equal(run(s, "curl -s https://example.org/a").code, 0);
  assert.equal(run(s, "curl -s https://example.org/b").code, 0);
  const third = run(s, "curl -s https://example.org/c");
  assert.equal(third.code, 2);
  assert.match(third.stderr, /Tretí ručný beh `curl` v relácii je mechanický krok/);
  assert.match(third.stderr, /agentic-brain\/skills\/<meno>\/scripts\//);
});

test("zamietnutý príkaz zopakovaný je znova zamietnutý", () => {
  const s = newSession();
  run(s, "curl a");
  run(s, "curl b");
  assert.equal(run(s, "curl c").code, 2);
  assert.equal(run(s, "curl c").code, 2);
});

test("rovnaký príkaz zopakovaný sa nepočíta ako nový", () => {
  const s = newSession();
  for (let i = 0; i < 5; i++) assert.equal(run(s, "curl -s https://example.org/a").code, 0);
});

test("program zo zoznamu allow prejde aj tretíkrát", () => {
  const s = newSession();
  for (const a of ["status", "log", "diff", "branch", "fetch"]) assert.equal(run(s, `git ${a}`).code, 0);
});

test("príkaz zo skills/*/scripts/ a z agentic-brain/bin/ sa nepočíta", () => {
  const s = newSession();
  for (const a of ["1", "2", "3", "4"]) {
    assert.equal(run(s, `./agentic-brain/skills/web/scripts/stiahni.sh ${a}`).code, 0);
    assert.equal(run(s, `"$CLAUDE_PROJECT_DIR/agentic-brain/bin/hladaj" ${a}`).code, 0);
  }
  assert.equal(run(s, "curl a").code, 0);
  assert.equal(run(s, "curl b").code, 0);
});

test("rúra a && sa delia na časti, každý program sa počíta", () => {
  const s = newSession();
  assert.equal(run(s, "cd x && curl -s a | head -n 1").code, 0);
  assert.equal(run(s, "curl -s b | grep x").code, 0);
  assert.equal(run(s, "cd y && curl -s c").code, 2);
});

test("premenné a sudo pred programom sa odstránia", () => {
  const s = newSession();
  assert.equal(run(s, "A=1 curl a").code, 0);
  assert.equal(run(s, "sudo curl b").code, 0);
  assert.equal(run(s, "A=2 sudo -u nikto curl c").code, 2);
});

test("rúra v úvodzovkách nerozdelí príkaz", () => {
  const s = newSession();
  assert.equal(run(s, 'curl "a|b"').code, 0);
  assert.equal(run(s, 'curl "c && d"').code, 0);
  assert.equal(run(s, "curl 'e;f'").code, 2);
});

test("presmerovanie 2>&1 nevytvorí zdanlivý program", () => {
  const s = newSession();
  for (let i = 0; i < 4; i++) assert.equal(run(s, `echo ${i} 2>&1`).code, 0);
});

test("relácie sú oddelené", () => {
  const a = newSession();
  const b = newSession();
  run(a, "curl 1");
  run(a, "curl 2");
  assert.equal(run(b, "curl 3").code, 0);
  assert.equal(run(a, "curl 4").code, 2);
});

test("neplatný JSON prejde kódom 0", () => {
  assert.equal(runRaw("toto nie je json").code, 0);
  assert.equal(runRaw("").code, 0);
  assert.equal(runRaw("[1,2").code, 0);
});

test("JSON bez príkazu prejde kódom 0", () => {
  assert.equal(runRaw(JSON.stringify({ session_id: "x" })).code, 0);
  assert.equal(runRaw(JSON.stringify({ session_id: "x", tool_input: { command: 5 } })).code, 0);
  assert.equal(runRaw(JSON.stringify({ tool_input: { command: "" } })).code, 0);
});

test("stav je v tmpdir pod menom relácie", () => {
  const s = newSession();
  run(s, "curl a");
  assert.ok(readdirSync(SANDBOX).includes(`agentic-brain-repeat-${s}.json`));
});
