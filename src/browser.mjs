// Browser entry: Z3 runs in a plain dedicated Worker, so solving never blocks the page and
// can be cancelled by terminating the worker. The .wasm is fetched and compiled once.
const wasmUrl = new URL("./z3-built.wasm", import.meta.url);
const workerUrl = new URL("./worker.mjs", import.meta.url);

export async function createZ3Worker() {
  const wasmModule = await WebAssembly.compileStreaming(fetch(wasmUrl));
  let worker = null;
  let nextId = 0;
  const pending = new Map();
  let version = "";

  function spawn() {
    worker = new Worker(workerUrl, { type: "module" });
    worker.onmessage = (e) => {
      const p = pending.get(e.data.id);
      if (!p) return;
      pending.delete(e.data.id);
      e.data.ok ? p.resolve(e.data.result) : p.reject(new Error(e.data.error));
    };
    return call({ type: "init", wasmModule });
  }
  function call(msg) {
    const id = nextId++;
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      worker.postMessage({ ...msg, id });
    });
  }

  version = await spawn();
  return {
    version: () => version,
    evalSmtlib2: (text) => call({ type: "eval", text }),
    /** Abort the running evaluation: pending calls reject with "cancelled"; a fresh worker is started. */
    async cancel() {
      worker.terminate();
      for (const p of pending.values()) p.reject(new Error("cancelled"));
      pending.clear();
      await spawn();
    },
    terminate() {
      worker.terminate();
      for (const p of pending.values()) p.reject(new Error("terminated"));
      pending.clear();
    },
  };
}
