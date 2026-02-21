#!/usr/bin/env python3
"""Generate C ABI contracts and non-trivial backend stubs for NYX native_* hooks."""

from __future__ import annotations

import json
import pathlib
import re
from dataclasses import dataclass

ROOT = pathlib.Path.cwd()
ENGINE_FILES = [
    "engines/nycore/nycore.ny",
    "engines/nyrender/nyrender.ny",
    "engines/nyphysics/nyphysics.ny",
    "engines/nyworld/nyworld.ny",
    "engines/nyai/nyai.ny",
    "engines/nynet/nynet.ny",
    "engines/nyaudio/nyaudio.ny",
    "engines/nyanim/nyanim.ny",
    "engines/nylogic/nylogic.ny",
    "engines/nygame/nygame.ny",
]

OUT_DIR = ROOT / "native" / "backends" / "generated"
OUT_JSON = OUT_DIR / "native_hooks_inventory.json"
OUT_MD = OUT_DIR / "native_hooks_inventory.md"
OUT_H = OUT_DIR / "nyx_native_hooks.h"
OUT_C = OUT_DIR / "nyx_native_hooks_stub.c"
FEATURE_CONTRACT = ROOT / "configs" / "production" / "aaa_engine_feature_contract.json"


@dataclass
class Param:
    name: str
    nyx_type: str
    c_type: str


@dataclass
class Fn:
    file: str
    line: int
    function: str
    return_nyx_type: str
    return_c_type: str
    params: list[Param]
    signature: str

    def as_dict(self) -> dict:
        return {
            "file": self.file,
            "line": self.line,
            "function": self.function,
            "returnNyxType": self.return_nyx_type,
            "returnCType": self.return_c_type,
            "params": [
                {"name": p.name, "nyxType": p.nyx_type, "cType": p.c_type} for p in self.params
            ],
            "signature": self.signature,
        }


def split_params(text: str) -> list[str]:
    out: list[str] = []
    cur: list[str] = []
    angle = 0
    paren = 0
    bracket = 0
    for ch in text:
        if ch == "<":
            angle += 1
        elif ch == ">":
            angle = max(0, angle - 1)
        elif ch == "(":
            paren += 1
        elif ch == ")":
            paren = max(0, paren - 1)
        elif ch == "[":
            bracket += 1
        elif ch == "]":
            bracket = max(0, bracket - 1)
        if ch == "," and angle == 0 and paren == 0 and bracket == 0:
            piece = "".join(cur).strip()
            if piece:
                out.append(piece)
            cur = []
            continue
        cur.append(ch)
    piece = "".join(cur).strip()
    if piece:
        out.append(piece)
    return out


def normalize_type(t: str) -> str:
    return re.sub(r"\s+", "", t).lower()


def map_type(nyx_type: str, is_return: bool) -> str:
    t = (nyx_type or "").strip()
    norm = normalize_type(t)
    if not t or norm == "void":
        return "void"
    if norm in ("bool",):
        return "int"
    if re.fullmatch(r"(i8|i16|i32|i64|u8|u16|u32|u64|int)", norm):
        return "long long"
    if re.fullmatch(r"(f32|f64|float)", norm):
        return "double"
    if norm in ("str", "string"):
        return "const char *"
    if norm == "bytes":
        return "NyxBytes"
    if norm in ("list<string>", "vec<string>"):
        return "NyxStringList"
    if re.fullmatch(r"\(i32,i32\)", norm):
        return "NyxTuple2I32"
    if norm.startswith("result<") or norm.startswith("option<"):
        return "void *"
    if "list<" in norm or "vec<" in norm or "map<" in norm:
        return "void *"
    if norm in ("windowhandle", "texture", "font", "mesh", "model", "shader", "audiobuffer", "audiocontext"):
        return "void *"
    return "void *"


def sanitize_ident(name: str, fallback: str) -> str:
    n = re.sub(r"[^A-Za-z0-9_]", "_", name.strip())
    if not n:
        n = fallback
    if re.match(r"^[0-9]", n):
        n = "_" + n
    if n in {"auto", "register", "default", "char", "float", "double", "int", "long", "short"}:
        n += "_arg"
    return n


def dedupe_ordered(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def load_capability_contract() -> dict[str, dict[str, list[str]]]:
    if not FEATURE_CONTRACT.exists():
        return {}
    raw = json.loads(FEATURE_CONTRACT.read_text(encoding="utf-8"))
    engines = raw.get("engines", {})
    out: dict[str, dict[str, list[str]]] = {}
    for engine, profiles in engines.items():
        entry: dict[str, list[str]] = {}
        for profile in ("core", "nocode", "production"):
            vals = profiles.get(profile, [])
            if isinstance(vals, list):
                entry[profile] = dedupe_ordered([str(v) for v in vals if str(v).strip()])
            else:
                entry[profile] = []
        out[str(engine)] = entry
    return out


def c_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def emit_capability_contract_prelude(contract: dict[str, dict[str, list[str]]]) -> str:
    entries: list[tuple[str, str, str]] = []
    for engine, profiles in contract.items():
        for profile in ("core", "nocode", "production"):
            for capability in profiles.get(profile, []):
                entries.append((engine, profile, capability))

    out: list[str] = []
    out.append("typedef struct NyxCapabilityContractEntry {")
    out.append("    const char *engine;")
    out.append("    const char *profile;")
    out.append("    const char *capability;")
    out.append("} NyxCapabilityContractEntry;")
    out.append("")
    if entries:
        out.append("static const NyxCapabilityContractEntry g_nygame_capability_contract[] = {")
        for engine, profile, capability in entries:
            out.append(
                f'    {{"{c_escape(engine)}", "{c_escape(profile)}", "{c_escape(capability)}"}},'
            )
        out.append("};")
        out.append(
            "static const size_t g_nygame_capability_contract_len = "
            "sizeof(g_nygame_capability_contract) / sizeof(g_nygame_capability_contract[0]);"
        )
    else:
        out.append("static const NyxCapabilityContractEntry g_nygame_capability_contract[] = {")
        out.append("    {NULL, NULL, NULL},")
        out.append("};")
        out.append("static const size_t g_nygame_capability_contract_len = 0;")
    out.append("")
    out.append("static int nyx_contract_has_capability(const char *engine, const char *capability) {")
    out.append("    if (!engine || !capability || engine[0] == 0 || capability[0] == 0) return 0;")
    out.append("    for (size_t i = 0; i < g_nygame_capability_contract_len; i++) {")
    out.append("        const NyxCapabilityContractEntry *it = &g_nygame_capability_contract[i];")
    out.append("        if (strcmp(it->engine, engine) != 0) continue;")
    out.append("        if (strcmp(it->capability, capability) == 0) return 1;")
    out.append("    }")
    out.append("    return 0;")
    out.append("}")
    out.append("")
    out.append("static int nyx_contract_has_profile(const char *engine, const char *profile) {")
    out.append("    if (!engine || !profile || engine[0] == 0 || profile[0] == 0) return 0;")
    out.append("    int saw = 0;")
    out.append("    for (size_t i = 0; i < g_nygame_capability_contract_len; i++) {")
    out.append("        const NyxCapabilityContractEntry *it = &g_nygame_capability_contract[i];")
    out.append("        if (strcmp(it->engine, engine) != 0) continue;")
    out.append("        if (strcmp(it->profile, profile) != 0) continue;")
    out.append("        saw = 1;")
    out.append("        if (!nyx_contract_has_capability(engine, it->capability)) return 0;")
    out.append("    }")
    out.append("    return saw ? 1 : 0;")
    out.append("}")
    out.append("")
    return "\n".join(out)


def is_declaration_line(line: str) -> bool:
    # Native declarations are top-level lines beginning with native_ and ending with ;
    # Avoid indented call sites inside function bodies.
    if not line:
        return False
    if line.startswith(" ") or line.startswith("\t"):
        return False
    return line.startswith("native_") and line.rstrip().endswith(";")


def parse_file(rel_path: str) -> list[Fn]:
    p = ROOT / rel_path
    text = p.read_text(encoding="utf-8")
    lines = text.splitlines()
    rx = re.compile(r"^(native_[A-Za-z0-9_]+)\((.*)\)\s*(?:->\s*([^;]+))?;")
    out: list[Fn] = []
    for idx, line in enumerate(lines, start=1):
        if not is_declaration_line(line):
            continue
        m = rx.match(line)
        if not m:
            continue
        fn_name = m.group(1)
        params_raw = (m.group(2) or "").strip()
        ret_raw = (m.group(3) or "").strip() or "void"

        params: list[Param] = []
        if params_raw:
            for i, piece in enumerate(split_params(params_raw)):
                if ":" in piece:
                    name, ty = piece.split(":", 1)
                    name = sanitize_ident(name, f"arg{i}")
                    nyx_type = ty.strip()
                else:
                    # Untyped declaration fallback
                    name = f"arg{i}"
                    nyx_type = piece.strip()
                params.append(Param(name=name, nyx_type=nyx_type, c_type=map_type(nyx_type, False)))

        out.append(
            Fn(
                file=rel_path,
                line=idx,
                function=fn_name,
                return_nyx_type=ret_raw,
                return_c_type=map_type(ret_raw, True),
                params=params,
                signature=line.strip(),
            )
        )
    return out


def default_return(c_type: str) -> str:
    if c_type == "void":
        return ""
    if c_type == "int":
        return "return 0;"
    if c_type == "long long":
        return "return 0;"
    if c_type == "double":
        return "return 0.0;"
    if c_type == "const char *":
        return 'return "";'
    if c_type == "NyxBytes":
        return "return nyx_empty_bytes();"
    if c_type == "NyxStringList":
        return "return nyx_empty_string_list();"
    if c_type == "NyxTuple2I32":
        return "return nyx_zero_tuple2_i32();"
    return "return NULL;"


def emit_header(functions: list[Fn]) -> str:
    out: list[str] = []
    out.append("/* Auto-generated by scripts/generate_native_backend_stubs.py */")
    out.append("#ifndef NYX_NATIVE_HOOKS_H")
    out.append("#define NYX_NATIVE_HOOKS_H")
    out.append("")
    out.append("#include <stddef.h>")
    out.append("#include <stdint.h>")
    out.append("")
    out.append("#ifdef __cplusplus")
    out.append('extern "C" {')
    out.append("#endif")
    out.append("")
    out.append("typedef struct NyxBytes {")
    out.append("    const unsigned char *data;")
    out.append("    long long len;")
    out.append("} NyxBytes;")
    out.append("")
    out.append("typedef struct NyxStringList {")
    out.append("    const char **items;")
    out.append("    long long len;")
    out.append("} NyxStringList;")
    out.append("")
    out.append("typedef struct NyxTuple2I32 {")
    out.append("    int a;")
    out.append("    int b;")
    out.append("} NyxTuple2I32;")
    out.append("")
    for fn in functions:
        params = ", ".join(f"{p.c_type} {p.name}" for p in fn.params) if fn.params else "void"
        out.append(f"{fn.return_c_type} {fn.function}({params});")
    out.append("")
    out.append("#ifdef __cplusplus")
    out.append("}")
    out.append("#endif")
    out.append("")
    out.append("#endif")
    out.append("")
    return "\n".join(out)


SPECIAL_PRELUDE = r'''
static unsigned long long nyx_fnv1a(const unsigned char *data, long long len) {
    unsigned long long h = 1469598103934665603ULL;
    if (!data || len <= 0) {
        return h;
    }
    for (long long i = 0; i < len; i++) {
        h ^= (unsigned long long)data[i];
        h *= 1099511628211ULL;
    }
    return h;
}

static unsigned long long nyx_hash_cstr(const char *s) {
    if (!s) {
        return nyx_fnv1a(NULL, 0);
    }
    const unsigned char *p = (const unsigned char *)s;
    long long n = 0;
    while (p[n] != 0) n++;
    return nyx_fnv1a(p, n);
}

static void nyx_copy_str(char *dst, size_t cap, const char *src, const char *fallback) {
    if (!dst || cap == 0) return;
    const char *in = src && *src ? src : fallback;
    if (!in) in = "";
    size_t i = 0;
    while (i + 1 < cap && in[i] != 0) {
        dst[i] = in[i];
        i++;
    }
    dst[i] = 0;
}

static double nyx_clamp(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static NyxBytes nyx_empty_bytes(void) {
    NyxBytes b;
    b.data = NULL;
    b.len = 0;
    return b;
}

static NyxStringList nyx_empty_string_list(void) {
    NyxStringList s;
    s.items = NULL;
    s.len = 0;
    return s;
}

static NyxTuple2I32 nyx_zero_tuple2_i32(void) {
    NyxTuple2I32 t;
    t.a = 0;
    t.b = 0;
    return t;
}

#define NYX_BLOB_SLOTS 32
#define NYX_BLOB_CAP 1024
static unsigned char g_blob_slots[NYX_BLOB_SLOTS][NYX_BLOB_CAP];
static long long g_blob_lens[NYX_BLOB_SLOTS];
static int g_blob_cursor = 0;

static NyxBytes nyx_blob_from_text(const char *text) {
    NyxBytes out;
    if (!text) return nyx_empty_bytes();
    int slot = g_blob_cursor++ % NYX_BLOB_SLOTS;
    long long i = 0;
    while (i + 1 < NYX_BLOB_CAP && text[i] != 0) {
        g_blob_slots[slot][i] = (unsigned char)text[i];
        i++;
    }
    g_blob_slots[slot][i] = 0;
    g_blob_lens[slot] = i;
    out.data = g_blob_slots[slot];
    out.len = i;
    return out;
}

static NyxBytes nyx_blob_from_bytes(const unsigned char *data, long long len) {
    NyxBytes out;
    if (!data || len <= 0) return nyx_empty_bytes();
    int slot = g_blob_cursor++ % NYX_BLOB_SLOTS;
    long long n = len < (NYX_BLOB_CAP - 1) ? len : (NYX_BLOB_CAP - 1);
    for (long long i = 0; i < n; i++) {
        g_blob_slots[slot][i] = data[i];
    }
    g_blob_slots[slot][n] = 0;
    g_blob_lens[slot] = n;
    out.data = g_blob_slots[slot];
    out.len = n;
    return out;
}

static const char *nyx_hex_u64(unsigned long long v) {
    static char ring[32][32];
    static int cursor = 0;
    int slot = cursor++ % 32;
    (void)snprintf(ring[slot], sizeof(ring[slot]), "%016llx", v);
    return ring[slot];
}

static double nyx_parse_first_double(NyxBytes blob, double fallback) {
    if (!blob.data || blob.len <= 0) return fallback;
    char local[128];
    long long n = blob.len < 127 ? blob.len : 127;
    for (long long i = 0; i < n; i++) local[i] = (char)blob.data[i];
    local[n] = 0;
    char *endp = NULL;
    double v = strtod(local, &endp);
    if (endp == local) return fallback;
    return v;
}

#define NYX_LIST_SLOTS 16
#define NYX_LIST_ITEMS 8
#define NYX_LIST_STR 64
static const char *g_list_items[NYX_LIST_SLOTS][NYX_LIST_ITEMS];
static char g_list_storage[NYX_LIST_SLOTS][NYX_LIST_ITEMS][NYX_LIST_STR];
static int g_list_cursor = 0;

static NyxStringList nyx_string_list_from4(const char *a, const char *b, const char *c, const char *d) {
    NyxStringList out;
    int slot = g_list_cursor++ % NYX_LIST_SLOTS;
    const char *vals[4] = {a, b, c, d};
    long long count = 0;
    for (int i = 0; i < 4; i++) {
        if (!vals[i] || vals[i][0] == 0) continue;
        nyx_copy_str(g_list_storage[slot][count], NYX_LIST_STR, vals[i], "");
        g_list_items[slot][count] = g_list_storage[slot][count];
        count++;
    }
    out.items = g_list_items[slot];
    out.len = count;
    return out;
}

typedef struct NyxRenderState {
    int booted;
    char backend[32];
    long long width;
    long long height;
    char tier[16];
    long long registered_materials;
    long long gpu_memory_mb;
    double last_gpu_ms;
} NyxRenderState;

static NyxRenderState g_render = {0, "vulkan", 1920, 1080, "high", 0, 4096, 8.0};

typedef struct NyxPhysicsState {
    int booted;
    char float_mode[32];
    char template_id[32];
    double step_ms;
    unsigned long long last_checksum;
} NyxPhysicsState;

static NyxPhysicsState g_physics = {0, "deterministic_fp32", "realistic", 2.5, 0ULL};

typedef struct NyxAIState {
    double frame_ms;
    long long last_sandbox_steps;
    unsigned long long last_intent_hash;
} NyxAIState;

static NyxAIState g_ai = {1.2, 0, 0ULL};

typedef struct NyxNetState {
    double tick_ms;
    double packet_loss_pct;
    unsigned long long last_world_hash;
    long long desync_count;
} NyxNetState;

static NyxNetState g_net = {2.0, 0.2, 0ULL, 0};

typedef struct NyxAudioState {
    char active_backend[16];
    double master_volume;
    double listener[3];
    long long active_sources;
    long long filters;
    long long reverbs;
    long long voice_peers;
    double dsp_ms;
    double lufs;
} NyxAudioState;

static NyxAudioState g_audio = {{'w','a','s','a','p','i',0}, 1.0, {0.0, 0.0, 0.0}, 0, 0, 0, 1, 1.0, -16.0};

typedef struct NyxLogicState {
    long long executed_actions;
    long long mutation_count;
    double profile_ms;
    unsigned long long last_rule_hash;
} NyxLogicState;

static NyxLogicState g_logic = {0, 0, 0.8, 0ULL};

static int g_nygame_last_sync_ok = 0;
'''


SPECIAL_IMPLS: dict[str, str] = {
    # Render
    "native_render_boot": """
nyx_copy_str(g_render.backend, sizeof(g_render.backend), backend, "vulkan");
g_render.width = width > 0 ? width : 1920;
g_render.height = height > 0 ? height : 1080;
g_render.booted = 1;
g_render.registered_materials = 0;
g_render.gpu_memory_mb = 2048 + (g_render.width * g_render.height) / (1024 * 512);
g_render.last_gpu_ms = 6.0 + ((double)(g_render.width * g_render.height) / (1920.0 * 1080.0)) * 2.0;
""",
    "native_render_shutdown": """
g_render.booted = 0;
g_render.registered_materials = 0;
g_render.last_gpu_ms = 0.0;
""",
    "native_render_query_gpu_memory_mb": """
if (!g_render.booted) return 0;
long long tier_extra = 0;
if (strcmp(g_render.tier, "cinematic") == 0) tier_extra = 1024;
else if (strcmp(g_render.tier, "high") == 0) tier_extra = 512;
else if (strcmp(g_render.tier, "medium") == 0) tier_extra = 256;
else tier_extra = 64;
return g_render.gpu_memory_mb + tier_extra + g_render.registered_materials * 3;
""",
    "native_render_query_gpu_time_ms": """
if (!g_render.booted) return 0.0;
double tier_mul = 1.0;
if (strcmp(g_render.tier, "cinematic") == 0) tier_mul = 1.35;
else if (strcmp(g_render.tier, "high") == 0) tier_mul = 1.10;
else if (strcmp(g_render.tier, "medium") == 0) tier_mul = 0.85;
else tier_mul = 0.65;
g_render.last_gpu_ms = (5.5 + (double)g_render.registered_materials * 0.03) * tier_mul;
return g_render.last_gpu_ms;
""",
    "native_nyrender_apply_tier": """
nyx_copy_str(g_render.tier, sizeof(g_render.tier), tier, "high");
""",
    "native_nyrender_compile_material_graph": """
char tmp[256];
unsigned long long h = (unsigned long long)(node_count * 131 + layer_count * 977 + 17);
(void)snprintf(tmp, sizeof(tmp), "material_graph;nodes=%lld;layers=%lld;hash=%s", node_count, layer_count, nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",
    "native_nyrender_compile_pipeline_graph": """
char tmp[256];
unsigned long long h = (unsigned long long)(pass_count * 313 + edge_count * 733 + 23);
(void)snprintf(tmp, sizeof(tmp), "pipeline_graph;passes=%lld;edges=%lld;hash=%s", pass_count, edge_count, nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",
    "native_nyrender_generate_material_from_prompt": """
unsigned long long h = nyx_hash_cstr(prompt);
char tmp[512];
(void)snprintf(tmp, sizeof(tmp), "prompt_material;prompt=%s;hash=%s;brdf=ggx;layered=1;spectral=1", prompt ? prompt : "", nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",
    "native_nyrender_register_material_blob": """
(unsigned long long)nyx_hash_cstr(material_id);
(unsigned long long)nyx_fnv1a(graph_blob.data, graph_blob.len);
g_render.registered_materials++;
""",

    # Physics
    "native_physics_boot": """
g_physics.booted = 1;
g_physics.step_ms = 2.2;
""",
    "native_physics_shutdown": """
g_physics.booted = 0;
""",
    "native_physics_checksum": """
unsigned long long h = ((unsigned long long)frame * 1315423911ULL) ^ nyx_fnv1a(blob.data, blob.len);
g_physics.last_checksum = h;
return nyx_hex_u64(h);
""",
    "native_physics_query_step_ms": """
return g_physics.booted ? g_physics.step_ms : 0.0;
""",
    "native_physics_set_float_mode": """
nyx_copy_str(g_physics.float_mode, sizeof(g_physics.float_mode), mode, "deterministic_fp32");
""",
    "native_physics_validate_frame": """
unsigned long long h = ((unsigned long long)frame * 2654435761ULL) ^ nyx_fnv1a(state_blob.data, state_blob.len);
if (!g_physics.booted) return 0;
if (strcmp(g_physics.float_mode, "deterministic_fp32") != 0 && strcmp(g_physics.float_mode, "deterministic_fp64") != 0) return 0;
return (h != 0ULL) ? 1 : 0;
""",
    "native_nyphysics_apply_template": """
nyx_copy_str(g_physics.template_id, sizeof(g_physics.template_id), template_id, "realistic");
if (strcmp(g_physics.template_id, "arcade") == 0) g_physics.step_ms = 1.7;
else if (strcmp(g_physics.template_id, "simulation") == 0) g_physics.step_ms = 2.9;
else if (strcmp(g_physics.template_id, "experimental") == 0) g_physics.step_ms = 3.3;
else g_physics.step_ms = 2.2;
""",
    "native_nyphysics_auto_tune": """
double hint = nyx_parse_first_double(telemetry_blob, g_physics.step_ms);
g_physics.step_ms = nyx_clamp((g_physics.step_ms * 0.7) + (hint * 0.3), 0.5, 8.0);
""",
    "native_nyphysics_compile_constraint_graph": """
char tmp[256];
unsigned long long h = (unsigned long long)(node_count * 41 + edge_count * 73 + 11);
(void)snprintf(tmp, sizeof(tmp), "constraint_graph;nodes=%lld;edges=%lld;hash=%s", node_count, edge_count, nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",
    "native_nyphysics_generate_fracture_rules": """
char tmp[256];
unsigned long long h = (unsigned long long)(material_count * 97 + 7);
(void)snprintf(tmp, sizeof(tmp), "fracture_rules;materials=%lld;hash=%s", material_count, nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",
    "native_nyphysics_compile_nocode_bundle": """
unsigned long long h = nyx_fnv1a(graph_blob.data, graph_blob.len) ^ (nyx_fnv1a(fracture_blob.data, fracture_blob.len) << 1) ^ nyx_hash_cstr(template_id);
char tmp[256];
(void)snprintf(tmp, sizeof(tmp), "physics_bundle;template=%s;hash=%s", template_id ? template_id : "", nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",

    # AI
    "native_ai_frame_time_ms": """
return g_ai.frame_ms;
""",
    "native_nyai_build_hybrid_from_intent": """
g_ai.last_intent_hash = nyx_hash_cstr(intent);
char tmp[512];
(void)snprintf(tmp, sizeof(tmp), "hybrid_brain;intent=%s;bt=reactive;goap=enabled;hash=%s", intent ? intent : "", nyx_hex_u64(g_ai.last_intent_hash));
return nyx_blob_from_text(tmp);
""",
    "native_nyai_run_sandbox": """
g_ai.last_sandbox_steps = step_count;
g_ai.frame_ms = nyx_clamp(0.4 + (double)step_count * 0.00003, 0.2, 8.0);
char tmp[256];
(void)snprintf(tmp, sizeof(tmp), "sandbox;steps=%lld;frame_ms=%.3f", step_count, g_ai.frame_ms);
return nyx_blob_from_text(tmp);
""",

    # Net
    "native_nynet_checksum": """
unsigned long long h = ((unsigned long long)frame_id * 11400714819323198485ULL) ^ nyx_fnv1a(world_blob.data, world_blob.len);
g_net.last_world_hash = h;
return nyx_hex_u64(h);
""",
    "native_nynet_tick_ms": """
return g_net.tick_ms;
""",
    "native_nynet_packet_loss_pct": """
return g_net.packet_loss_pct;
""",
    "native_nynet_autodiscover_replication": """
char tmp[256];
(void)snprintf(tmp, sizeof(tmp), "replication_policy;components=%lld;bandwidth_kbps=%lld;mode=auto", component_count, bandwidth_kbps);
return nyx_blob_from_text(tmp);
""",
    "native_nynet_build_interest_zones": """
char tmp[256];
long long zones = entity_count <= 0 ? 0 : (entity_count / 64) + 1;
(void)snprintf(tmp, sizeof(tmp), "interest_zones;entities=%lld;zones=%lld", entity_count, zones);
return nyx_blob_from_text(tmp);
""",
    "native_nynet_validate_desync": """
int ok = 0;
if (local_checksum && remote_checksum && strcmp(local_checksum, remote_checksum) == 0) {
    ok = 1;
    g_net.packet_loss_pct = nyx_clamp(g_net.packet_loss_pct - 0.05, 0.0, 20.0);
    g_net.tick_ms = nyx_clamp(g_net.tick_ms - 0.02, 0.5, 30.0);
} else {
    g_net.desync_count++;
    g_net.packet_loss_pct = nyx_clamp(g_net.packet_loss_pct + 0.12, 0.0, 20.0);
    g_net.tick_ms = nyx_clamp(g_net.tick_ms + 0.04, 0.5, 30.0);
}
(void)frame;
return ok;
""",

    # Audio
    "native_audio_backend_alive": """
if (!backend) return 0;
if (strcmp(backend, "wasapi") == 0) return 1;
if (strcmp(backend, "alsa") == 0) return 1;
if (strcmp(backend, "coreaudio") == 0) return 1;
if (strcmp(backend, g_audio.active_backend) == 0) return 1;
return 0;
""",
    "native_audio_create_context": """
nyx_copy_str(g_audio.active_backend, sizeof(g_audio.active_backend), "wasapi", "wasapi");
g_audio.master_volume = 1.0;
g_audio.active_sources = 0;
g_audio.filters = 0;
g_audio.reverbs = 0;
g_audio.voice_peers = 1;
g_audio.dsp_ms = 1.0;
g_audio.lufs = -16.0;
return &g_audio;
""",
    "native_audio_load_buffer": """
static unsigned long long ids[128];
static int cursor = 0;
int slot = cursor++ % 128;
ids[slot] = nyx_hash_cstr(path);
return &ids[slot];
""",
    "native_audio_play": """
(void)source_id;
g_audio.active_sources++;
g_audio.dsp_ms = nyx_clamp(0.7 + (double)g_audio.active_sources * 0.15 + (double)g_audio.filters * 0.05 + (double)g_audio.reverbs * 0.08, 0.2, 20.0);
g_audio.lufs = -16.0 + (double)g_audio.active_sources * 0.25;
""",
    "native_audio_stop": """
(void)source_id;
if (g_audio.active_sources > 0) g_audio.active_sources--;
g_audio.dsp_ms = nyx_clamp(0.6 + (double)g_audio.active_sources * 0.14, 0.2, 20.0);
""",
    "native_audio_set_master_volume": """
g_audio.master_volume = nyx_clamp(volume, 0.0, 2.0);
""",
    "native_audio_set_listener": """
(void)forward;
(void)up;
if (position) {
    g_audio.listener[0] += 0.01;
    g_audio.listener[1] += 0.01;
    g_audio.listener[2] += 0.01;
}
""",
    "native_audio_add_reverb": """
(void)source_id;
(void)room_size;
(void)damping;
g_audio.reverbs++;
g_audio.dsp_ms = nyx_clamp(g_audio.dsp_ms + 0.09, 0.2, 20.0);
""",
    "native_audio_add_filter": """
(void)source_id;
(void)filter_type;
(void)frequency;
(void)q;
g_audio.filters++;
g_audio.dsp_ms = nyx_clamp(g_audio.dsp_ms + 0.05, 0.2, 20.0);
""",
    "native_audio_trace_occlusion": """
double dist = lx * lx + ly * ly + lz * lz;
double hashed = (double)(nyx_hash_cstr(source_id) % 100) / 100.0;
return nyx_clamp((dist * 0.0002) + hashed * 0.1, 0.0, 1.0);
""",
    "native_audio_voice_peers": """
return g_audio.voice_peers;
""",
    "native_audio_dsp_time_ms": """
return g_audio.dsp_ms;
""",
    "native_audio_integrated_lufs": """
return g_audio.lufs - (1.0 - g_audio.master_volume) * 4.0;
""",
    "native_nyaudio_compile_zone_graph": """
char tmp[256];
(void)snprintf(tmp, sizeof(tmp), "audio_zone_graph;zones=%lld;edges=%lld", zone_count, edge_count);
return nyx_blob_from_text(tmp);
""",
    "native_nyaudio_resolve_music_state": """
if (!state) return nyx_empty_string_list();
if (strcmp(state, "combat") == 0) {
    return nyx_string_list_from4("perc_heavy", "bass_drive", intensity > 0.7 ? "lead_high" : "lead_mid", "drone_tension");
}
if (strcmp(state, "chaos") == 0) {
    return nyx_string_list_from4("perc_break", "noise_swells", "sub_pulse", "alarm_layer");
}
if (strcmp(state, "tension") == 0) {
    return nyx_string_list_from4("pulse_soft", "strings_tense", intensity > 0.6 ? "high_pad" : "", "");
}
return nyx_string_list_from4("pad_calm", "texture_air", "", "");
""",

    # Logic
    "native_nylogic_generate_rule": """
unsigned long long h = nyx_hash_cstr(prompt);
g_logic.last_rule_hash = h;
char tmp[768];
(void)snprintf(tmp, sizeof(tmp), "rule generated_%s when Player enters Bank and Time is Night trigger PoliceResponse(level=3) # prompt=%s", nyx_hex_u64(h), prompt ? prompt : "");
return nyx_blob_from_text(tmp);
""",
    "native_nylogic_decode_rule": """
static char decoded[1024];
long long n = rule_blob.len < 1023 ? rule_blob.len : 1023;
if (!rule_blob.data || n <= 0) {
    decoded[0] = 0;
    return decoded;
}
for (long long i = 0; i < n; i++) decoded[i] = (char)rule_blob.data[i];
decoded[n] = 0;
return decoded;
""",
    "native_nylogic_validate": """
if (!rule_id || rule_id[0] == 0) return 0;
if (condition_count <= 0) return 0;
if (trigger_count <= 0) return 0;
return 1;
""",
    "native_nylogic_compile_graph": """
char tmp[256];
unsigned long long h = (unsigned long long)(node_count * 109 + edge_count * 251 + 29);
(void)snprintf(tmp, sizeof(tmp), "logic_graph;nodes=%lld;edges=%lld;hash=%s", node_count, edge_count, nyx_hex_u64(h));
return nyx_blob_from_text(tmp);
""",
    "native_nylogic_execute": """
g_logic.executed_actions++;
unsigned long long h = nyx_hash_cstr(action) ^ nyx_fnv1a(payload.data, payload.len);
g_logic.last_rule_hash = h;
g_logic.profile_ms = nyx_clamp(g_logic.profile_ms + 0.01, 0.05, 10.0);
""",
    "native_nylogic_mutate": """
if (!rule_id || rule_id[0] == 0) return 0;
if (!patch_blob.data || patch_blob.len <= 0) return 0;
g_logic.mutation_count++;
g_logic.last_rule_hash = nyx_hash_cstr(rule_id) ^ nyx_fnv1a(patch_blob.data, patch_blob.len);
return 1;
""",
    "native_nylogic_optimize": """
if (target_ms <= 0.0) target_ms = 1.0;
if (frame_ms > target_ms) {
    g_logic.profile_ms = nyx_clamp(target_ms + (frame_ms - target_ms) * 0.25, 0.05, 10.0);
} else {
    g_logic.profile_ms = nyx_clamp(frame_ms, 0.05, 10.0);
}
""",
    "native_nylogic_profile_ms": """
return g_logic.profile_ms;
""",

    # Nygame integration helpers
    "native_nygame_mount_engine": """
(void)name;
return enabled ? 1 : 0;
""",
    "native_nygame_bind_engine": """
(void)name;
(void)slot;
""",
    "native_nygame_set_engine_profile": """
(void)name;
(void)profile;
""",
    "native_nygame_enable_telemetry": """
(void)name;
""",
    "native_nygame_tick_engine": """
(void)name;
(void)dt;
""",
    "native_nygame_shutdown_engine": """
(void)name;
""",
    "native_nygame_report_sync": """
g_nygame_last_sync_ok = ok ? 1 : 0;
""",
    "native_nygame_report_capability_validation": """
(void)ok;
""",
    "native_nygame_report_production_validation": """
(void)ok;
""",
    "native_nygame_verify_engine_capability": """
if (!name || !capability) return 0;
return nyx_contract_has_capability(name, capability);
""",
    "native_nygame_verify_engine_profile": """
if (!name || !profile) return 0;
return nyx_contract_has_profile(name, profile);
""",
}


def emit_fn(fn: Fn) -> str:
    params_decl = ", ".join(f"{p.c_type} {p.name}" for p in fn.params) if fn.params else "void"
    out: list[str] = [f"{fn.return_c_type} {fn.function}({params_decl}) {{"]

    body = SPECIAL_IMPLS.get(fn.function)
    if body is not None:
        for line in body.strip("\n").splitlines():
            out.append(f"    {line}")
        if fn.return_c_type != "void":
            # Ensure body has a return statement for non-void paths.
            joined = "\n".join(body.splitlines())
            if "return " not in joined:
                out.append(f"    {default_return(fn.return_c_type)}")
        out.append("}")
        out.append("")
        return "\n".join(out)

    for p in fn.params:
        out.append(f"    (void){p.name};")
    ret = default_return(fn.return_c_type)
    if ret:
        out.append(f"    {ret}")
    out.append("}")
    out.append("")
    return "\n".join(out)


def emit_stub(functions: list[Fn], contract: dict[str, dict[str, list[str]]]) -> str:
    out: list[str] = []
    out.append("/* Auto-generated by scripts/generate_native_backend_stubs.py */")
    out.append("#include <stddef.h>")
    out.append("#include <stdio.h>")
    out.append("#include <stdlib.h>")
    out.append("#include <string.h>")
    out.append("#include <time.h>")
    out.append('#include "nyx_native_hooks.h"')
    out.append("")
    out.append(SPECIAL_PRELUDE.strip("\n"))
    out.append("")
    out.append(emit_capability_contract_prelude(contract).strip("\n"))
    out.append("")

    for fn in functions:
        out.append(emit_fn(fn).rstrip("\n"))
    return "\n".join(out) + "\n"


def emit_md(functions: list[Fn]) -> str:
    out: list[str] = []
    out.append("# Native Hook Inventory")
    out.append("")
    out.append("Generated from NYX engine declarations.")
    out.append("")
    out.append("| Function | Return (NYX) | Return (C) | Params | Source |")
    out.append("|---|---|---|---|---|")
    for fn in functions:
        params = "<br>".join(f"{p.name}: {p.nyx_type} -> {p.c_type}" for p in fn.params) if fn.params else "-"
        out.append(
            f"| `{fn.function}` | `{fn.return_nyx_type}` | `{fn.return_c_type}` | {params} | `{fn.file}:{fn.line}` |"
        )
    out.append("")
    return "\n".join(out)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    capability_contract = load_capability_contract()
    all_decls: list[Fn] = []
    for rel in ENGINE_FILES:
        if (ROOT / rel).exists():
            all_decls.extend(parse_file(rel))

    by_name: dict[str, Fn] = {}
    for d in all_decls:
        if d.function not in by_name:
            by_name[d.function] = d

    functions = sorted(by_name.values(), key=lambda f: f.function)

    OUT_JSON.write_text(json.dumps([f.as_dict() for f in functions], indent=2) + "\n", encoding="utf-8")
    OUT_MD.write_text(emit_md(functions), encoding="utf-8")
    OUT_H.write_text(emit_header(functions), encoding="utf-8")
    OUT_C.write_text(emit_stub(functions, capability_contract), encoding="utf-8")

    print(f"Generated {len(functions)} hooks")
    print(f"- {OUT_JSON.relative_to(ROOT)}")
    print(f"- {OUT_MD.relative_to(ROOT)}")
    print(f"- {OUT_H.relative_to(ROOT)}")
    print(f"- {OUT_C.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
