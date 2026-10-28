export interface Z3Worker {
  version(): string;
  /** Run SMT-LIB2 text in a fresh Z3 context inside the worker. */
  evalSmtlib2(text: string): Promise<string>;
  /** Terminate the running evaluation (pending promises reject) and start a fresh worker. */
  cancel(): Promise<void>;
  terminate(): void;
}
export function createZ3Worker(): Promise<Z3Worker>;
