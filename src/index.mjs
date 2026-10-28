// Low-level entry: loads the single-threaded Z3 WASM (no SharedArrayBuffer, no COOP/COEP)
// in the current thread. In browsers prefer ./browser.mjs, which runs it in a Worker.
import createZ3Module from "./z3-built.mjs";

/**
 * @param {{ wasmModule?: WebAssembly.Module, locateFile?: (f: string) => string }} [options]
 */
export async function init(options = {}) {
  const moduleArgs = {};
  if (options.locateFile) moduleArgs.locateFile = options.locateFile;
  if (options.wasmModule) {
    moduleArgs.instantiateWasm = (imports, receive) => {
      WebAssembly.instantiate(options.wasmModule, imports).then((instance) => receive(instance, options.wasmModule));
      return {};
    };
  }
  const m = await createZ3Module(moduleArgs);
  return {
    /** Z3's full version string, e.g. "5.3.2.0". */
    version: () => m.UTF8ToString(m._z3w_version()),
    /**
     * Run SMT-LIB2 text in a fresh Z3 context and return the solver's textual output.
     * Use `(set-option :timeout <ms>)` in the text for a time box.
     * @param {string} text
     */
    evalSmtlib2(text) {
      const input = m.stringToNewUTF8(text);
      try {
        const out = m._z3w_eval_smtlib2(input);
        try {
          return m.UTF8ToString(out);
        } finally {
          m._z3w_free(out);
        }
      } finally {
        m._free(input);
      }
    },
  };
}
