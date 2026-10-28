// Smoke test, runnable unchanged with Node (>= 20) and Deno:
//   node test/smoke.mjs dist        deno run --allow-read test/smoke.mjs dist
const dist = (globalThis.Deno ? Deno.args : process.argv.slice(2))[0] ?? "dist";
const base = new URL(`../${dist}/`, import.meta.url);
const { init } = await import(new URL("index.mjs", base).href);

const t0 = performance.now();
const z3 = await init();
const initMs = Math.round(performance.now() - t0);
const results = { runtime: globalThis.Deno ? `deno ${Deno.version.deno}` : `node ${process.version}`, initMs };
const fail = (msg) => {
  console.error("SMOKE FAIL:", msg, JSON.stringify(results));
  throw new Error(msg);
};

results.version = z3.version();
const buildInfo = await (globalThis.Deno
  ? Deno.readTextFile(new URL("BUILDINFO", base))
  : (await import("node:fs/promises")).readFile(new URL("BUILDINFO", base), "utf8"));
const tag = /z3_tag=z3-(\S+)/.exec(buildInfo)?.[1];
const commit = /z3_commit=(\S+)/.exec(buildInfo)?.[1];
// Z3 embeds the git commit it was built from; it must be the pinned one.
if (!results.version.startsWith(tag) || !results.version.includes(commit)) {
  fail(`version ${results.version} does not match tag ${tag} / commit ${commit}`);
}

const run = (label, text, expect) => {
  const a = performance.now();
  const out = z3.evalSmtlib2(text);
  results[label] = { ms: Math.round(performance.now() - a), out: out.trim().split("\n")[0] };
  if (!expect(out)) fail(`${label}: unexpected output ${JSON.stringify(out)}`);
};

// Integer arithmetic, sat + model.
run("int_sat", "(declare-const x Int)(declare-const y Int)(assert (= (+ x y) 10))(assert (= (- x y) 4))(check-sat)(get-value (x y))",
  (o) => o.startsWith("sat") && /\(x 7\)/.test(o) && /\(y 3\)/.test(o));
// Unsat arithmetic (exercises theory_lra timers that need POLLING_TIMER in a no-thread build).
run("real_unsat", "(declare-const r Real)(assert (> r 1.5))(assert (< r 1.0))(check-sat)", (o) => o.trim() === "unsat");
// The decision-table gap query from intEHRgrator (#41): needs a non-integer counterexample.
run("sbp_gap", "(declare-fun sbp () Real)(assert (not (or (< sbp 90.0) (and (>= sbp 90.0) (<= sbp 139.0)) (>= sbp 140.0))))(check-sat)(get-value (sbp))",
  (o) => o.startsWith("sat") && /139|279/.test(o));
// Strings.
run("strings", '(declare-const s String)(assert (= (str.len s) 3))(assert (str.prefixof "ab" s))(check-sat)(get-value (s))',
  (o) => o.startsWith("sat") && /"ab./.test(o));
// Time box: a query Z3 cannot finish quickly must come back "unknown" within the timeout.
run("timeout", "(set-option :timeout 500)(declare-const x Int)(declare-const y Int)(declare-const z Int)(assert (= (+ (* x x x) (* y y y) (* z z z)) 42))(assert (> x 1000))(check-sat)",
  (o) => o.trim() === "unknown");
if (results.timeout.ms > 5000) fail("timeout not honoured");
// Syntax errors come back as text, not as a crash.
run("error", "(assert (= 1", (o) => /^\(error "line 1/.test(o));

console.log(JSON.stringify(results, null, 2));
console.log("SMOKE OK");
