// Dedicated-worker side of ./browser.mjs. Receives the compiled WebAssembly.Module once,
// then evaluates SMT-LIB2 requests. No shared memory is used.
import { init } from "./index.mjs";

let z3Promise = null;
self.onmessage = async (event) => {
  const { id, type, wasmModule, text } = event.data;
  try {
    if (type === "init") {
      z3Promise = init({ wasmModule });
      const z3 = await z3Promise;
      self.postMessage({ id, ok: true, result: z3.version() });
    } else if (type === "eval") {
      const z3 = await z3Promise;
      self.postMessage({ id, ok: true, result: z3.evalSmtlib2(text) });
    }
  } catch (err) {
    self.postMessage({ id, ok: false, error: String(err?.message ?? err) });
  }
};
