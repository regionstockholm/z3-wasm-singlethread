export interface Z3Single {
  /** Z3's full version string, e.g. "5.3.2.0". */
  version(): string;
  /** Run SMT-LIB2 text in a fresh Z3 context; returns Z3's output (e.g. "sat\n(model ...)"). */
  evalSmtlib2(text: string): string;
}
export interface InitOptions {
  /** A pre-compiled module (e.g. shared with a Worker) to skip fetching/compiling the .wasm again. */
  wasmModule?: WebAssembly.Module;
  /** Override where z3-built.wasm is loaded from. */
  locateFile?: (file: string) => string;
}
export function init(options?: InitOptions): Promise<Z3Single>;
