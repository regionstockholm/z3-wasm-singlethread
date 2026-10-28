// Minimal, auditable C surface over the Z3 C API for a single-threaded WASM build.
// Every call runs in a fresh Z3 context: no state survives between calls.
#include <cstdlib>
#include <cstring>
#include <string>
#include <emscripten/emscripten.h>
#include "z3.h"

static void z3w_noop_error_handler(Z3_context, Z3_error_code) {}

static char* z3w_dup(const std::string& s) {
  char* out = static_cast<char*>(std::malloc(s.size() + 1));
  if (out) std::memcpy(out, s.c_str(), s.size() + 1);
  return out;
}

extern "C" {

// Evaluate SMT-LIB2 text (e.g. "...(check-sat)(get-model)") and return Z3's textual output.
// API-level errors are returned as an SMT-LIB style "(error \"...\")" line.
// The returned buffer is malloc'd; release it with z3w_free.
EMSCRIPTEN_KEEPALIVE char* z3w_eval_smtlib2(const char* text) {
  Z3_config cfg = Z3_mk_config();
  Z3_context ctx = Z3_mk_context(cfg);
  Z3_del_config(cfg);
  Z3_set_error_handler(ctx, z3w_noop_error_handler);
  std::string result;
  const char* out = Z3_eval_smtlib2_string(ctx, text);
  Z3_error_code code = Z3_get_error_code(ctx);
  if (code != Z3_OK) {
    std::string msg = Z3_get_error_msg(ctx, code);
    // Parser errors already arrive as an SMT-LIB "(error ...)" line; wrap anything else.
    result = msg.rfind("(error", 0) == 0 ? msg : "(error \"" + msg + "\")";
    if (result.empty() || result.back() != '\n') result += '\n';
  } else if (out) {
    result = out;
  }
  Z3_del_context(ctx);
  return z3w_dup(result);
}

// Full Z3 version string, e.g. "5.3.2.0".
EMSCRIPTEN_KEEPALIVE const char* z3w_version() { return Z3_get_full_version(); }

EMSCRIPTEN_KEEPALIVE void z3w_free(char* p) { std::free(p); }
}
