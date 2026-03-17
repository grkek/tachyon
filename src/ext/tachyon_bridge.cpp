/*
 * tachyon_bridge.cpp
 *
 * C++ bridge between Tachyon engine (Crystal) and QuickJS.
 * Registers the "tachyon" synthetic ES module with native classes.
 *
 * Architecture:
 *   - Crystal owns all engine objects via a HandleRegistry
 *   - JS objects hold an opaque uint32 handle
 *   - Crystal callbacks are stored as CrystalProcedure (same pattern as Medusa)
 *     which preserves closure data across the FFI boundary
 *   - Each callback slot stores {function_pointer, closure_data}
 *
 * Build: compile to .o / .a and link with Crystal via @[Link]
 */

#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cmath>

extern "C"
{
#include "quickjs/quickjs.h"
}

/* =========================================================================
 * CrystalProcedure — matches Medusa's layout exactly
 *
 * Crystal Proc is {pointer, closure_data}. We store this pair and
 * invoke it by calling pointer(closure_data, ...args).
 * ========================================================================= */

struct CrystalProc
{
    void *pointer;
    void *closure_data;

    bool isValid() const { return pointer != nullptr; }
};

/* =========================================================================
 * Callback slots — one per engine operation
 *
 * Crystal registers these at init time. Each carries closure data
 * so Crystal procs that capture registry/scene/etc. work correctly.
 * ========================================================================= */

enum CallbackSlot
{
    CB_CREATE_CUBE = 0,
    CB_CREATE_SPHERE,
    CB_CREATE_PLANE,
    CB_CREATE_CYLINDER,
    CB_SCENE_ADD,
    CB_SCENE_REMOVE,
    CB_SCENE_FIND,
    CB_SCENE_CLEAR,
    CB_NODE_SET_POSITION,
    CB_NODE_GET_POSITION,
    CB_NODE_SET_ROTATION,
    CB_NODE_GET_ROTATION,
    CB_NODE_SET_SCALE,
    CB_NODE_GET_SCALE,
    CB_NODE_SET_NAME,
    CB_NODE_SET_VISIBLE,
    CB_NODE_GET_VISIBLE,
    CB_NODE_ROTATE,
    CB_NODE_TRANSLATE,
    CB_NODE_LOOK_AT,
    CB_NODE_DESTROY,
    CB_NODE_SET_MATERIAL_COLOR,
    CB_NODE_SET_MATERIAL_ROUGHNESS,
    CB_NODE_SET_MATERIAL_METALLIC,
    CB_NODE_SET_MATERIAL_OPACITY,
    CB_INPUT_KEY_DOWN,
    CB_INPUT_KEY_PRESSED,
    CB_INPUT_KEY_RELEASED,
    CB_INPUT_MOUSE_BUTTON_DOWN,
    CB_INPUT_MOUSE_BUTTON_PRESSED,
    CB_INPUT_MOUSE_POSITION,
    CB_INPUT_MOUSE_DELTA,
    CB_CREATE_CONE,
    CB_CREATE_TORUS,
    CB_LOAD_MESH,
    CB_NODE_SET_WIREFRAME,
    CB_GUI_DRAW_RECT,
    CB_GUI_DRAW_TEXT,
    CB_GUI_CLEAR,
    CB_CANVAS_SETUP,
    CB_CANVAS_BACKGROUND,
    CB_CANVAS_TEXT,
    CB_SPRITE_CREATE,
    CB_SPRITE_LOAD,
    CB_SPRITE_SET_POSITION,
    CB_SPRITE_GET_POSITION,
    CB_SPRITE_SET_ROTATION,
    CB_SPRITE_SET_SCALE,
    CB_SPRITE_SET_COLOR,
    CB_SPRITE_SET_VISIBLE,
    CB_SPRITE_DESTROY,
    CB_SPRITE_SET_LAYER,
    CB_CAMERA_SET_POSITION,
    CB_CAMERA_GET_POSITION,
    CB_CAMERA_SET_TARGET,
    CB_CAMERA_GET_TARGET,
    CB_CAMERA_SET_FOV,
    CB_CREATE_POINT_LIGHT,
    CB_LIGHT_SET_POSITION,
    CB_LIGHT_SET_COLOR,
    CB_LIGHT_SET_INTENSITY,
    CB_LIGHT_SET_RANGE,
    CB_AUDIO_PLAY_SOUND,
    CB_AUDIO_LOAD_SOUND,
    CB_AUDIO_STOP_SOUND,
    CB_AUDIO_SET_VOLUME,
    CB_SCENE_PICK,
    CB_MAX
};

static CrystalProc g_callbacks[CB_MAX] = {};

/* =========================================================================
 * Typed callback invocation helpers
 * ========================================================================= */

// void fn(float, float, float, float, float, float, float, float)
static void call_8f_void(CallbackSlot slot, float a, float b, float c, float d, float e, float f, float g, float h)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, float, float, float, float, float, float, float, float);
    ((Fn)cb.pointer)(cb.closure_data, a, b, c, d, e, f, g, h);
}

// void fn(const char*, float, float, float, float, float, float, float)
static void call_s7f_void(CallbackSlot slot, const char *s, float a, float b, float c, float d, float e, float f, float g)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, const char *, float, float, float, float, float, float, float);
    ((Fn)cb.pointer)(cb.closure_data, s, a, b, c, d, e, f, g);
}

// uint32 fn(float, float, float)
static uint32_t call_fff_u32(CallbackSlot slot, float a, float b, float c)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef uint32_t (*Fn)(void *, float, float, float);
    return ((Fn)cb.pointer)(cb.closure_data, a, b, c);
}

// uint32 fn(float, int, int)
static uint32_t call_fii_u32(CallbackSlot slot, float a, int b, int c)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef uint32_t (*Fn)(void *, float, int, int);
    return ((Fn)cb.pointer)(cb.closure_data, a, b, c);
}

// uint32 fn(float, float)
static uint32_t call_ff_u32(CallbackSlot slot, float a, float b)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef uint32_t (*Fn)(void *, float, float);
    return ((Fn)cb.pointer)(cb.closure_data, a, b);
}

// uint32 fn(float, float, int)
static uint32_t call_ffi_u32(CallbackSlot slot, float a, float b, int c)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef uint32_t (*Fn)(void *, float, float, int);
    return ((Fn)cb.pointer)(cb.closure_data, a, b, c);
}

// void fn(uint32)
static void call_u32_void(CallbackSlot slot, uint32_t h)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t);
    ((Fn)cb.pointer)(cb.closure_data, h);
}

// uint32 fn(const char*)
static uint32_t call_s_u32(CallbackSlot slot, const char *s)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef uint32_t (*Fn)(void *, const char *);
    return ((Fn)cb.pointer)(cb.closure_data, s);
}

// void fn()
static void call_void(CallbackSlot slot)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *);
    ((Fn)cb.pointer)(cb.closure_data);
}

// void fn(uint32, float, float, float)
static void call_u32_fff_void(CallbackSlot slot, uint32_t h, float x, float y, float z)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, float, float, float);
    ((Fn)cb.pointer)(cb.closure_data, h, x, y, z);
}

// void fn(uint32, float*, float*, float*)
static void call_u32_ppp_void(CallbackSlot slot, uint32_t h, float *x, float *y, float *z)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, float *, float *, float *);
    ((Fn)cb.pointer)(cb.closure_data, h, x, y, z);
}

// void fn(uint32, const char*)
static void call_u32_s_void(CallbackSlot slot, uint32_t h, const char *s)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, const char *);
    ((Fn)cb.pointer)(cb.closure_data, h, s);
}

// void fn(uint32, int)
static void call_u32_i_void(CallbackSlot slot, uint32_t h, int v)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, int);
    ((Fn)cb.pointer)(cb.closure_data, h, v);
}

// int fn(uint32)
static int call_u32_int(CallbackSlot slot, uint32_t h)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef int (*Fn)(void *, uint32_t);
    return ((Fn)cb.pointer)(cb.closure_data, h);
}

// void fn(uint32, float)
static void call_u32_f_void(CallbackSlot slot, uint32_t h, float v)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, float);
    ((Fn)cb.pointer)(cb.closure_data, h, v);
}

// uint32 fn()
static uint32_t call_u32(CallbackSlot slot)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef uint32_t (*Fn)(void *);
    return ((Fn)cb.pointer)(cb.closure_data);
}

// int fn(const char*)
static int call_s_int(CallbackSlot slot, const char *s)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef int (*Fn)(void *, const char *);
    return ((Fn)cb.pointer)(cb.closure_data, s);
}

// int fn(int)
static int call_i_int(CallbackSlot slot, int v)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return 0;
    typedef int (*Fn)(void *, int);
    return ((Fn)cb.pointer)(cb.closure_data, v);
}

// void fn(float*, float*)
static void call_pp_void(CallbackSlot slot, float *a, float *b)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, float *, float *);
    ((Fn)cb.pointer)(cb.closure_data, a, b);
}

/* =========================================================================
 * Class IDs
 * ========================================================================= */

static JSClassID js_tachyon_node_class_id = 0;
static JSClassID js_vector3_class_id = 0;
static JSClassID js_sprite_class_id = 0;

/* =========================================================================
 * Helper
 * ========================================================================= */

static uint32_t get_handle(JSContext *ctx, JSValueConst this_val, JSClassID class_id)
{
    void *opaque = JS_GetOpaque2(ctx, this_val, class_id);
    if (!opaque)
        return 0;
    return (uint32_t)(uintptr_t)opaque;
}

static void set_handle(JSValue obj, uint32_t handle)
{
    JS_SetOpaque(obj, (void *)(uintptr_t)handle);
}

/* =========================================================================
 * Vector3
 * ========================================================================= */

struct Vec3Data
{
    float x, y, z;
};

static void js_vector3_finalizer(JSRuntime *rt, JSValue val)
{
    Vec3Data *v = (Vec3Data *)JS_GetOpaque(val, js_vector3_class_id);
    if (v)
        js_free_rt(rt, v);
}

static JSClassDef js_vector3_class = {"Vector3", .finalizer = js_vector3_finalizer};

static JSValue js_vector3_new(JSContext *ctx, float x, float y, float z)
{
    JSValue obj = JS_NewObjectClass(ctx, (int)js_vector3_class_id);
    if (JS_IsException(obj))
        return obj;
    Vec3Data *v = (Vec3Data *)js_malloc(ctx, sizeof(Vec3Data));
    v->x = x;
    v->y = y;
    v->z = z;
    JS_SetOpaque(obj, v);
    return obj;
}

static Vec3Data *js_vector3_get(JSContext *ctx, JSValueConst val)
{
    return (Vec3Data *)JS_GetOpaque2(ctx, val, js_vector3_class_id);
}

static JSValue js_vector3_constructor(JSContext *ctx, JSValueConst new_target,
                                      int argc, JSValueConst *argv)
{
    double x = 0, y = 0, z = 0;
    if (argc >= 1)
        JS_ToFloat64(ctx, &x, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &y, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &z, argv[2]);

    JSValue proto = JS_GetPropertyStr(ctx, new_target, "prototype");
    JSValue obj = JS_NewObjectProtoClass(ctx, proto, js_vector3_class_id);
    JS_FreeValue(ctx, proto);
    if (JS_IsException(obj))
        return obj;

    Vec3Data *v = (Vec3Data *)js_malloc(ctx, sizeof(Vec3Data));
    v->x = (float)x;
    v->y = (float)y;
    v->z = (float)z;
    JS_SetOpaque(obj, v);
    return obj;
}

#define V3_GETSET(COMP)                                                                           \
    static JSValue js_vector3_get_##COMP(JSContext *ctx, JSValueConst this_val)                   \
    {                                                                                             \
        Vec3Data *v = js_vector3_get(ctx, this_val);                                              \
        return v ? JS_NewFloat64(ctx, v->COMP) : JS_EXCEPTION;                                    \
    }                                                                                             \
    static JSValue js_vector3_set_##COMP(JSContext *ctx, JSValueConst this_val, JSValueConst val) \
    {                                                                                             \
        Vec3Data *v = js_vector3_get(ctx, this_val);                                              \
        if (!v)                                                                                   \
            return JS_EXCEPTION;                                                                  \
        double d;                                                                                 \
        JS_ToFloat64(ctx, &d, val);                                                               \
        v->COMP = (float)d;                                                                       \
        return JS_UNDEFINED;                                                                      \
    }

V3_GETSET(x)
V3_GETSET(y)
V3_GETSET(z)

static JSValue js_vector3_add(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    Vec3Data *b = (argc >= 1) ? js_vector3_get(ctx, argv[0]) : nullptr;
    if (!a || !b)
        return JS_ThrowTypeError(ctx, "Vector3.add requires a Vector3 argument");
    return js_vector3_new(ctx, a->x + b->x, a->y + b->y, a->z + b->z);
}

static JSValue js_vector3_sub(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    Vec3Data *b = (argc >= 1) ? js_vector3_get(ctx, argv[0]) : nullptr;
    if (!a || !b)
        return JS_ThrowTypeError(ctx, "Vector3.sub requires a Vector3 argument");
    return js_vector3_new(ctx, a->x - b->x, a->y - b->y, a->z - b->z);
}

static JSValue js_vector3_mul(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    if (!a)
        return JS_EXCEPTION;
    double s = 1.0;
    if (argc >= 1)
        JS_ToFloat64(ctx, &s, argv[0]);
    return js_vector3_new(ctx, a->x * (float)s, a->y * (float)s, a->z * (float)s);
}

static JSValue js_vector3_dot(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    Vec3Data *b = (argc >= 1) ? js_vector3_get(ctx, argv[0]) : nullptr;
    if (!a || !b)
        return JS_ThrowTypeError(ctx, "Vector3.dot requires a Vector3 argument");
    return JS_NewFloat64(ctx, a->x * b->x + a->y * b->y + a->z * b->z);
}

static JSValue js_vector3_cross(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    Vec3Data *b = (argc >= 1) ? js_vector3_get(ctx, argv[0]) : nullptr;
    if (!a || !b)
        return JS_ThrowTypeError(ctx, "Vector3.cross requires a Vector3 argument");
    return js_vector3_new(ctx, a->y * b->z - a->z * b->y, a->z * b->x - a->x * b->z, a->x * b->y - a->y * b->x);
}

static JSValue js_vector3_normalize(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    if (!a)
        return JS_EXCEPTION;
    float mag = sqrtf(a->x * a->x + a->y * a->y + a->z * a->z);
    if (mag == 0.0f)
        return js_vector3_new(ctx, 0, 0, 0);
    return js_vector3_new(ctx, a->x / mag, a->y / mag, a->z / mag);
}

static JSValue js_vector3_magnitude(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    if (!a)
        return JS_EXCEPTION;
    return JS_NewFloat64(ctx, sqrtf(a->x * a->x + a->y * a->y + a->z * a->z));
}

static JSValue js_vector3_distance(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = js_vector3_get(ctx, this_val);
    Vec3Data *b = (argc >= 1) ? js_vector3_get(ctx, argv[0]) : nullptr;
    if (!a || !b)
        return JS_ThrowTypeError(ctx, "Vector3.distance requires a Vector3 argument");
    float dx = a->x - b->x, dy = a->y - b->y, dz = a->z - b->z;
    return JS_NewFloat64(ctx, sqrtf(dx * dx + dy * dy + dz * dz));
}

static JSValue js_vector3_zero(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return js_vector3_new(ctx, 0, 0, 0);
}
static JSValue js_vector3_one(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return js_vector3_new(ctx, 1, 1, 1);
}
static JSValue js_vector3_up(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return js_vector3_new(ctx, 0, 1, 0);
}
static JSValue js_vector3_lerp(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    Vec3Data *a = (argc >= 1) ? js_vector3_get(ctx, argv[0]) : nullptr;
    Vec3Data *b = (argc >= 2) ? js_vector3_get(ctx, argv[1]) : nullptr;
    if (!a || !b)
        return JS_ThrowTypeError(ctx, "Vector3.lerp requires two Vector3 arguments");
    double t = 0;
    if (argc >= 3)
        JS_ToFloat64(ctx, &t, argv[2]);
    float ft = (float)t;
    return js_vector3_new(ctx, a->x + (b->x - a->x) * ft, a->y + (b->y - a->y) * ft, a->z + (b->z - a->z) * ft);
}

static const JSCFunctionListEntry js_vector3_proto_funcs[] = {
    JS_CGETSET_DEF("x", js_vector3_get_x, js_vector3_set_x),
    JS_CGETSET_DEF("y", js_vector3_get_y, js_vector3_set_y),
    JS_CGETSET_DEF("z", js_vector3_get_z, js_vector3_set_z),
    JS_CFUNC_DEF("add", 1, js_vector3_add),
    JS_CFUNC_DEF("sub", 1, js_vector3_sub),
    JS_CFUNC_DEF("mul", 1, js_vector3_mul),
    JS_CFUNC_DEF("dot", 1, js_vector3_dot),
    JS_CFUNC_DEF("cross", 1, js_vector3_cross),
    JS_CFUNC_DEF("normalize", 0, js_vector3_normalize),
    JS_CFUNC_DEF("magnitude", 0, js_vector3_magnitude),
    JS_CFUNC_DEF("distance", 1, js_vector3_distance),
};

/* =========================================================================
 * Scene Node classes
 * ========================================================================= */

static void js_node_finalizer(JSRuntime *rt, JSValue val) {}
static JSClassDef js_node_class = {"TachyonNode", .finalizer = js_node_finalizer};

static float get_opt_float(JSContext *ctx, JSValueConst obj, const char *key, float def)
{
    JSValue val = JS_GetPropertyStr(ctx, obj, key);
    if (JS_IsUndefined(val))
    {
        JS_FreeValue(ctx, val);
        return def;
    }
    double d = def;
    JS_ToFloat64(ctx, &d, val);
    JS_FreeValue(ctx, val);
    return (float)d;
}

static int get_opt_int(JSContext *ctx, JSValueConst obj, const char *key, int def)
{
    JSValue val = JS_GetPropertyStr(ctx, obj, key);
    if (JS_IsUndefined(val))
    {
        JS_FreeValue(ctx, val);
        return def;
    }
    int32_t i = def;
    JS_ToInt32(ctx, &i, val);
    JS_FreeValue(ctx, val);
    return i;
}

static JSValue js_new_node_obj(JSContext *ctx, JSValueConst new_target, uint32_t handle)
{
    JSValue proto = JS_GetPropertyStr(ctx, new_target, "prototype");
    JSValue obj = JS_NewObjectProtoClass(ctx, proto, js_tachyon_node_class_id);
    JS_FreeValue(ctx, proto);
    if (JS_IsException(obj))
        return obj;
    set_handle(obj, handle);
    return obj;
}

static JSValue js_cube_constructor(JSContext *ctx, JSValueConst new_target, int argc, JSValueConst *argv)
{
    float w = 1, h = 1, d = 1;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        w = get_opt_float(ctx, argv[0], "width", 1.0f);
        h = get_opt_float(ctx, argv[0], "height", 1.0f);
        d = get_opt_float(ctx, argv[0], "depth", 1.0f);
    }
    return js_new_node_obj(ctx, new_target, call_fff_u32(CB_CREATE_CUBE, w, h, d));
}

static JSValue js_sphere_constructor(JSContext *ctx, JSValueConst new_target, int argc, JSValueConst *argv)
{
    float r = 1.0f;
    int seg = 32, rings = 16;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        r = get_opt_float(ctx, argv[0], "radius", 1.0f);
        seg = get_opt_int(ctx, argv[0], "segments", 32);
        rings = get_opt_int(ctx, argv[0], "rings", 16);
    }
    return js_new_node_obj(ctx, new_target, call_fii_u32(CB_CREATE_SPHERE, r, seg, rings));
}

static JSValue js_plane_constructor(JSContext *ctx, JSValueConst new_target, int argc, JSValueConst *argv)
{
    float w = 1, h = 1;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        w = get_opt_float(ctx, argv[0], "width", 1.0f);
        h = get_opt_float(ctx, argv[0], "height", 1.0f);
    }
    return js_new_node_obj(ctx, new_target, call_ff_u32(CB_CREATE_PLANE, w, h));
}

static JSValue js_cylinder_constructor(JSContext *ctx, JSValueConst new_target, int argc, JSValueConst *argv)
{
    float r = 1, h = 2;
    int seg = 32;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        r = get_opt_float(ctx, argv[0], "radius", 1.0f);
        h = get_opt_float(ctx, argv[0], "height", 2.0f);
        seg = get_opt_int(ctx, argv[0], "segments", 32);
    }
    return js_new_node_obj(ctx, new_target, call_ffi_u32(CB_CREATE_CYLINDER, r, h, seg));
}

// new Cone({ radius, height, segments })
static JSValue js_cone_constructor(JSContext *ctx, JSValueConst new_target, int argc, JSValueConst *argv)
{
    float r = 1, h = 2;
    int seg = 32;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        r = get_opt_float(ctx, argv[0], "radius", 1.0f);
        h = get_opt_float(ctx, argv[0], "height", 2.0f);
        seg = get_opt_int(ctx, argv[0], "segments", 32);
    }
    return js_new_node_obj(ctx, new_target, call_ffi_u32(CB_CREATE_CONE, r, h, seg));
}

// new Torus({ majorRadius, minorRadius, majorSegments, minorSegments })
static JSValue js_torus_constructor(JSContext *ctx, JSValueConst new_target, int argc, JSValueConst *argv)
{
    float major = 1.0f, minor = 0.4f;
    int major_seg = 32, minor_seg = 16;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        major = get_opt_float(ctx, argv[0], "majorRadius", 1.0f);
        minor = get_opt_float(ctx, argv[0], "minorRadius", 0.4f);
        major_seg = get_opt_int(ctx, argv[0], "majorSegments", 32);
        minor_seg = get_opt_int(ctx, argv[0], "minorSegments", 16);
    }
    // Pack into two calls: first create with radii, then we need 4 params
    // Use the string-based loader pattern for torus since it has 4 params
    // Actually reuse ffi_u32 for major/minor and fii for segments
    // Simpler: pass all as a string key and let Crystal parse it
    // Actually let's just use two float params and two int params
    // We need a new call helper. For now, encode as: call_ffi_u32 for (major, minor_as_float, major_seg)
    // and pass minor_seg via a separate mechanism. OR just use the generic approach.
    //
    // Simplest: pack minor_radius into the "height" float param
    return js_new_node_obj(ctx, new_target,
                           call_ffi_u32(CB_CREATE_TORUS, major, minor, major_seg));
}

// Mesh.load("path") — static factory
static JSValue js_mesh_load(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Mesh.load requires a path argument");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    uint32_t handle = call_s_u32(CB_LOAD_MESH, path);
    JS_FreeCString(ctx, path);
    if (handle == 0)
        return JS_ThrowReferenceError(ctx, "Failed to load mesh");
    JSValue obj = JS_NewObjectClass(ctx, (int)js_sprite_class_id);
    set_handle(obj, handle);
    return obj;
}

// node.wireframe = true/false
static JSValue js_node_set_wireframe(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    call_u32_i_void(CB_NODE_SET_WIREFRAME, h, JS_ToBool(ctx, val));
    return JS_UNDEFINED;
}

// Node methods
static JSValue js_node_get_position(JSContext *ctx, JSValueConst this_val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    float x, y, z;
    call_u32_ppp_void(CB_NODE_GET_POSITION, h, &x, &y, &z);
    return js_vector3_new(ctx, x, y, z);
}

static JSValue js_node_set_position(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    Vec3Data *v = js_vector3_get(ctx, val);
    if (!v)
        return JS_ThrowTypeError(ctx, "position must be a Vector3");
    call_u32_fff_void(CB_NODE_SET_POSITION, h, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_node_get_scale(JSContext *ctx, JSValueConst this_val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    float x, y, z;
    call_u32_ppp_void(CB_NODE_GET_SCALE, h, &x, &y, &z);
    return js_vector3_new(ctx, x, y, z);
}

static JSValue js_node_set_scale(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    Vec3Data *v = js_vector3_get(ctx, val);
    if (!v)
        return JS_ThrowTypeError(ctx, "scale must be a Vector3");
    call_u32_fff_void(CB_NODE_SET_SCALE, h, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_node_set_visible_prop(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    call_u32_i_void(CB_NODE_SET_VISIBLE, h, JS_ToBool(ctx, val));
    return JS_UNDEFINED;
}

static JSValue js_node_get_visible_prop(JSContext *ctx, JSValueConst this_val)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    return JS_NewBool(ctx, call_u32_int(CB_NODE_GET_VISIBLE, h));
}

static JSValue js_node_rotate(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    double x = 0, y = 0, z = 0;
    if (argc >= 1)
        JS_ToFloat64(ctx, &x, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &y, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &z, argv[2]);
    call_u32_fff_void(CB_NODE_ROTATE, h, (float)x, (float)y, (float)z);
    return JS_UNDEFINED;
}

static JSValue js_node_translate(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    double x = 0, y = 0, z = 0;
    if (argc >= 1)
        JS_ToFloat64(ctx, &x, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &y, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &z, argv[2]);
    call_u32_fff_void(CB_NODE_TRANSLATE, h, (float)x, (float)y, (float)z);
    return JS_UNDEFINED;
}

static JSValue js_node_look_at(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "lookAt requires a Vector3 argument");
    Vec3Data *v = js_vector3_get(ctx, argv[0]);
    if (!v)
        return JS_ThrowTypeError(ctx, "lookAt requires a Vector3 argument");
    call_u32_fff_void(CB_NODE_LOOK_AT, h, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_node_destroy(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    call_u32_void(CB_NODE_DESTROY, h);
    return JS_UNDEFINED;
}

static JSValue js_node_set_material_color(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 3)
        return JS_ThrowTypeError(ctx, "setMaterialColor(r, g, b)");
    double r, g, b;
    JS_ToFloat64(ctx, &r, argv[0]);
    JS_ToFloat64(ctx, &g, argv[1]);
    JS_ToFloat64(ctx, &b, argv[2]);
    call_u32_fff_void(CB_NODE_SET_MATERIAL_COLOR, h, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

static const JSCFunctionListEntry js_node_proto_funcs[] = {
    JS_CGETSET_DEF("position", js_node_get_position, js_node_set_position),
    JS_CGETSET_DEF("scale", js_node_get_scale, js_node_set_scale),
    JS_CGETSET_DEF("visible", js_node_get_visible_prop, js_node_set_visible_prop),
    JS_CFUNC_DEF("rotate", 3, js_node_rotate),
    JS_CFUNC_DEF("translate", 3, js_node_translate),
    JS_CFUNC_DEF("lookAt", 1, js_node_look_at),
    JS_CFUNC_DEF("destroy", 0, js_node_destroy),
    JS_CFUNC_DEF("setMaterialColor", 3, js_node_set_material_color),
    JS_CGETSET_DEF("wireframe", NULL, js_node_set_wireframe),
};

/* =========================================================================
 * Scene (static)
 * ========================================================================= */

static JSValue js_scene_add(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    for (int i = 0; i < argc; i++)
    {
        uint32_t h = get_handle(ctx, argv[i], js_tachyon_node_class_id);
        if (h)
            call_u32_void(CB_SCENE_ADD, h);
    }
    return JS_UNDEFINED;
}

static JSValue js_scene_remove(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    for (int i = 0; i < argc; i++)
    {
        uint32_t h = get_handle(ctx, argv[i], js_tachyon_node_class_id);
        if (h)
            call_u32_void(CB_SCENE_REMOVE, h);
    }
    return JS_UNDEFINED;
}

static JSValue js_scene_find(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_UNDEFINED;
    const char *name = JS_ToCString(ctx, argv[0]);
    if (!name)
        return JS_EXCEPTION;
    uint32_t h = call_s_u32(CB_SCENE_FIND, name);
    JS_FreeCString(ctx, name);
    if (h == 0)
        return JS_UNDEFINED;
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, h);
    return obj;
}

static JSValue js_scene_clear(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    call_void(CB_SCENE_CLEAR);
    return JS_UNDEFINED;
}

static JSValue js_scene_pick(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    double x = 0, y = 0;
    if (argc >= 1) JS_ToFloat64(ctx, &x, argv[0]);
    if (argc >= 2) JS_ToFloat64(ctx, &y, argv[1]);
    uint32_t handle = call_ff_u32(CB_SCENE_PICK, (float)x, (float)y);
    if (handle == 0) return JS_UNDEFINED;
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, handle);
    return obj;
}

/* =========================================================================
 * Input (static)
 * ========================================================================= */

static JSValue js_input_key_down(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_FALSE;
    const char *key = JS_ToCString(ctx, argv[0]);
    if (!key)
        return JS_EXCEPTION;
    int r = call_s_int(CB_INPUT_KEY_DOWN, key);
    JS_FreeCString(ctx, key);
    return JS_NewBool(ctx, r);
}

static JSValue js_input_key_pressed(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_FALSE;
    const char *key = JS_ToCString(ctx, argv[0]);
    if (!key)
        return JS_EXCEPTION;
    int r = call_s_int(CB_INPUT_KEY_PRESSED, key);
    JS_FreeCString(ctx, key);
    return JS_NewBool(ctx, r);
}

static JSValue js_input_key_released(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_FALSE;
    const char *key = JS_ToCString(ctx, argv[0]);
    if (!key)
        return JS_EXCEPTION;
    int r = call_s_int(CB_INPUT_KEY_RELEASED, key);
    JS_FreeCString(ctx, key);
    return JS_NewBool(ctx, r);
}

static JSValue js_input_mouse_button_down(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    int32_t btn = 0;
    if (argc >= 1)
        JS_ToInt32(ctx, &btn, argv[0]);
    return JS_NewBool(ctx, call_i_int(CB_INPUT_MOUSE_BUTTON_DOWN, btn));
}

static JSValue js_input_mouse_button_pressed(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    int32_t btn = 0;
    if (argc >= 1)
        JS_ToInt32(ctx, &btn, argv[0]);
    return JS_NewBool(ctx, call_i_int(CB_INPUT_MOUSE_BUTTON_PRESSED, btn));
}

static JSValue js_input_mouse_position(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    float x, y;
    call_pp_void(CB_INPUT_MOUSE_POSITION, &x, &y);
    return js_vector3_new(ctx, x, y, 0);
}

static JSValue js_input_mouse_delta(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    float dx, dy;
    call_pp_void(CB_INPUT_MOUSE_DELTA, &dx, &dy);
    return js_vector3_new(ctx, dx, dy, 0);
}

// GUI.rect(x, y, w, h, r, g, b, a)
static JSValue js_gui_draw_rect(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double x = 0, y = 0, w = 100, h = 100, r = 1, g = 1, b = 1, a = 1;
    if (argc >= 1)
        JS_ToFloat64(ctx, &x, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &y, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &w, argv[2]);
    if (argc >= 4)
        JS_ToFloat64(ctx, &h, argv[3]);
    if (argc >= 5)
        JS_ToFloat64(ctx, &r, argv[4]);
    if (argc >= 6)
        JS_ToFloat64(ctx, &g, argv[5]);
    if (argc >= 7)
        JS_ToFloat64(ctx, &b, argv[6]);
    if (argc >= 8)
        JS_ToFloat64(ctx, &a, argv[7]);
    call_8f_void(CB_GUI_DRAW_RECT, (float)x, (float)y, (float)w, (float)h, (float)r, (float)g, (float)b, (float)a);
    return JS_UNDEFINED;
}

// GUI.text(str, x, y, scale, r, g, b, a)
static JSValue js_gui_draw_text(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "GUI.text requires a string");
    const char *text = JS_ToCString(ctx, argv[0]);
    if (!text)
        return JS_EXCEPTION;
    double x = 0, y = 0, scale = 2, r = 1, g = 1, b = 1, a = 1;
    if (argc >= 2)
        JS_ToFloat64(ctx, &x, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &y, argv[2]);
    if (argc >= 4)
        JS_ToFloat64(ctx, &scale, argv[3]);
    if (argc >= 5)
        JS_ToFloat64(ctx, &r, argv[4]);
    if (argc >= 6)
        JS_ToFloat64(ctx, &g, argv[5]);
    if (argc >= 7)
        JS_ToFloat64(ctx, &b, argv[6]);
    if (argc >= 8)
        JS_ToFloat64(ctx, &a, argv[7]);
    call_s7f_void(CB_GUI_DRAW_TEXT, text, (float)x, (float)y, (float)scale, (float)r, (float)g, (float)b, (float)a);
    JS_FreeCString(ctx, text);
    return JS_UNDEFINED;
}

// GUI.clear()
static JSValue js_gui_clear(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    call_void(CB_GUI_CLEAR);
    return JS_UNDEFINED;
}

static JSValue js_new_sprite_obj(JSContext *ctx, uint32_t handle)
{
    JSValue obj = JS_NewObjectClass(ctx, (int)js_sprite_class_id);
    set_handle(obj, handle);
    return obj;
}

// Sprite.create({ width, height })
static JSValue js_sprite_create(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    float w = 32, h = 32;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
        w = get_opt_float(ctx, argv[0], "width", 32.0f);
        h = get_opt_float(ctx, argv[0], "height", 32.0f);
    }
    uint32_t handle = call_ff_u32(CB_SPRITE_CREATE, w, h);
    if (handle == 0)
        return JS_UNDEFINED;
    return js_new_sprite_obj(ctx, handle);
}

static JSValue js_sprite_load(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Sprite.load requires a path");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    uint32_t handle = call_s_u32(CB_SPRITE_LOAD, path);
    JS_FreeCString(ctx, path);
    if (handle == 0)
        return JS_ThrowReferenceError(ctx, "Failed to load sprite");
    return js_new_sprite_obj(ctx, handle);
}

// Canvas.setup(width, height)
static JSValue js_canvas_setup(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double w = 1280, h = 720;
    if (argc >= 1)
        JS_ToFloat64(ctx, &w, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &h, argv[1]);
    call_ff_u32(CB_CANVAS_SETUP, (float)w, (float)h);
    return JS_UNDEFINED;
}

// Canvas.background(r, g, b, a)
static JSValue js_canvas_background(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double r = 0, g = 0, b = 0, a = 1;
    if (argc >= 1)
        JS_ToFloat64(ctx, &r, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &g, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &b, argv[2]);
    if (argc >= 4)
        JS_ToFloat64(ctx, &a, argv[3]);
    call_u32_fff_void(CB_CANVAS_BACKGROUND, 0, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

// Canvas.text(str, x, y, scale, r, g, b, a)
static JSValue js_canvas_text(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Canvas.text requires a string");
    const char *text = JS_ToCString(ctx, argv[0]);
    if (!text)
        return JS_EXCEPTION;
    double x = 0, y = 0, scale = 2, r = 1, g = 1, b = 1, a = 1;
    if (argc >= 2)
        JS_ToFloat64(ctx, &x, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &y, argv[2]);
    if (argc >= 4)
        JS_ToFloat64(ctx, &scale, argv[3]);
    if (argc >= 5)
        JS_ToFloat64(ctx, &r, argv[4]);
    if (argc >= 6)
        JS_ToFloat64(ctx, &g, argv[5]);
    if (argc >= 7)
        JS_ToFloat64(ctx, &b, argv[6]);
    if (argc >= 8)
        JS_ToFloat64(ctx, &a, argv[7]);
    call_s7f_void(CB_CANVAS_TEXT, text, (float)x, (float)y, (float)scale, (float)r, (float)g, (float)b, (float)a);
    JS_FreeCString(ctx, text);
    return JS_UNDEFINED;
}

static void js_sprite_finalizer(JSRuntime *rt, JSValue val) {}
static JSClassDef js_sprite_class = {"TachyonSprite", .finalizer = js_sprite_finalizer};

// Sprite property getters/setters
static JSValue js_sprite_get_x(JSContext *ctx, JSValueConst this_val)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    float x, y;
    call_u32_ppp_void(CB_SPRITE_GET_POSITION, h, &x, &y, nullptr);
    return JS_NewFloat64(ctx, x);
}

static JSValue js_sprite_set_x(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    double x;
    JS_ToFloat64(ctx, &x, val);
    float ox, oy;
    call_u32_ppp_void(CB_SPRITE_GET_POSITION, h, &ox, &oy, nullptr);
    call_u32_fff_void(CB_SPRITE_SET_POSITION, h, (float)x, oy, 0);
    return JS_UNDEFINED;
}

static JSValue js_sprite_get_y(JSContext *ctx, JSValueConst this_val)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    float x, y;
    call_u32_ppp_void(CB_SPRITE_GET_POSITION, h, &x, &y, nullptr);
    return JS_NewFloat64(ctx, y);
}

static JSValue js_sprite_set_y(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    double y;
    JS_ToFloat64(ctx, &y, val);
    float ox, oy;
    call_u32_ppp_void(CB_SPRITE_GET_POSITION, h, &ox, &oy, nullptr);
    call_u32_fff_void(CB_SPRITE_SET_POSITION, h, ox, (float)y, 0);
    return JS_UNDEFINED;
}

static JSValue js_sprite_set_color(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    double r = 1, g = 1, b = 1, a = 1;
    if (argc >= 1)
        JS_ToFloat64(ctx, &r, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &g, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &b, argv[2]);
    if (argc >= 4)
        JS_ToFloat64(ctx, &a, argv[3]);
    call_u32_fff_void(CB_SPRITE_SET_COLOR, h, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

static JSValue js_sprite_set_layer(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    int32_t layer = 0;
    JS_ToInt32(ctx, &layer, val);
    call_u32_i_void(CB_SPRITE_SET_LAYER, h, layer);
    return JS_UNDEFINED;
}

static JSValue js_sprite_set_visible_prop(JSContext *ctx, JSValueConst this_val, JSValueConst val)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    call_u32_i_void(CB_SPRITE_SET_VISIBLE, h, JS_ToBool(ctx, val));
    return JS_UNDEFINED;
}

static JSValue js_sprite_destroy_fn(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    call_u32_void(CB_SPRITE_DESTROY, h);
    return JS_UNDEFINED;
}

static const JSCFunctionListEntry js_sprite_proto_funcs[] = {
    JS_CGETSET_DEF("x", js_sprite_get_x, js_sprite_set_x),
    JS_CGETSET_DEF("y", js_sprite_get_y, js_sprite_set_y),
    JS_CGETSET_DEF("visible", NULL, js_sprite_set_visible_prop),
    JS_CGETSET_DEF("layer", NULL, js_sprite_set_layer),
    JS_CFUNC_DEF("setColor", 4, js_sprite_set_color),
    JS_CFUNC_DEF("destroy", 0, js_sprite_destroy_fn),
};

// Camera
static JSValue js_camera_set_position(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Camera.setPosition requires a Vector3");
    Vec3Data *v = js_vector3_get(ctx, argv[0]);
    if (!v)
        return JS_ThrowTypeError(ctx, "Camera.setPosition requires a Vector3");
    call_u32_fff_void(CB_CAMERA_SET_POSITION, 0, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_camera_get_position(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    float x, y, z;
    call_u32_ppp_void(CB_CAMERA_GET_POSITION, 0, &x, &y, &z);
    return js_vector3_new(ctx, x, y, z);
}

static JSValue js_camera_set_target(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Camera.setTarget requires a Vector3");
    Vec3Data *v = js_vector3_get(ctx, argv[0]);
    if (!v)
        return JS_ThrowTypeError(ctx, "Camera.setTarget requires a Vector3");
    call_u32_fff_void(CB_CAMERA_SET_TARGET, 0, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_camera_get_target(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    float x, y, z;
    call_u32_ppp_void(CB_CAMERA_GET_TARGET, 0, &x, &y, &z);
    return js_vector3_new(ctx, x, y, z);
}

static JSValue js_camera_set_fov(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double fov = 60;
    if (argc >= 1)
        JS_ToFloat64(ctx, &fov, argv[0]);
    call_u32_f_void(CB_CAMERA_SET_FOV, 0, (float)fov);
    return JS_UNDEFINED;
}

// Lighting
static JSValue js_pointlight_constructor(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    float x = 0, y = 2, z = 0, r = 1, g = 1, b = 1, intensity = 1, range = 10;
    if (argc >= 1 && !JS_IsUndefined(argv[0])) {
        x = get_opt_float(ctx, argv[0], "x", 0);
        y = get_opt_float(ctx, argv[0], "y", 2);
        z = get_opt_float(ctx, argv[0], "z", 0);
        r = get_opt_float(ctx, argv[0], "r", 1);
        g = get_opt_float(ctx, argv[0], "g", 1);
        b = get_opt_float(ctx, argv[0], "b", 1);
        intensity = get_opt_float(ctx, argv[0], "intensity", 1);
        range = get_opt_float(ctx, argv[0], "range", 10);
    }
    // Pass position as fff, color+intensity+range via separate calls
    uint32_t handle = call_fff_u32(CB_CREATE_POINT_LIGHT, x, y, z);
    if (handle != 0) {
        call_u32_fff_void(CB_LIGHT_SET_COLOR, handle, r, g, b);
        call_u32_f_void(CB_LIGHT_SET_RANGE, handle, range);
    }
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, handle);
    return obj;
}

// Audio.play("path") — fire and forget
static JSValue js_audio_play(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_ThrowTypeError(ctx, "Audio.play requires a path");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path) return JS_EXCEPTION;
    call_s_u32(CB_AUDIO_PLAY_SOUND, path);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
}

// Audio.load("path") — returns handle for control
static JSValue js_audio_load(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_ThrowTypeError(ctx, "Audio.load requires a path");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path) return JS_EXCEPTION;
    uint32_t handle = call_s_u32(CB_AUDIO_LOAD_SOUND, path);
    JS_FreeCString(ctx, path);
    if (handle == 0) return JS_UNDEFINED;
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, handle);
    return obj;
}

// Audio.stop(handle)
static JSValue js_audio_stop(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    uint32_t h = get_handle(ctx, argv[0], js_tachyon_node_class_id);
    if (h) call_u32_void(CB_AUDIO_STOP_SOUND, h);
    return JS_UNDEFINED;
}

// Audio.setVolume(handle, volume)
static JSValue js_audio_set_volume(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_UNDEFINED;
    uint32_t h = get_handle(ctx, argv[0], js_tachyon_node_class_id);
    double vol = 1.0;
    JS_ToFloat64(ctx, &vol, argv[1]);
    if (h) call_u32_f_void(CB_AUDIO_SET_VOLUME, h, (float)vol);
    return JS_UNDEFINED;
}



/* =========================================================================
 * Module init
 * ========================================================================= */

static int js_tachyon_module_init(JSContext *ctx, JSModuleDef *m)
{
    // Vector3
    JSValue vector3_proto = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, vector3_proto, js_vector3_proto_funcs,
                               sizeof(js_vector3_proto_funcs) / sizeof(js_vector3_proto_funcs[0]));
    JSValue vector3_ctor = JS_NewCFunction2(ctx, js_vector3_constructor, "Vector3", 3, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, vector3_ctor, vector3_proto);
    JS_SetClassProto(ctx, js_vector3_class_id, vector3_proto);
    JS_SetPropertyStr(ctx, vector3_ctor, "zero", JS_NewCFunction(ctx, js_vector3_zero, "zero", 0));
    JS_SetPropertyStr(ctx, vector3_ctor, "one", JS_NewCFunction(ctx, js_vector3_one, "one", 0));
    JS_SetPropertyStr(ctx, vector3_ctor, "up", JS_NewCFunction(ctx, js_vector3_up, "up", 0));
    JS_SetPropertyStr(ctx, vector3_ctor, "lerp", JS_NewCFunction(ctx, js_vector3_lerp, "lerp", 3));
    JS_SetModuleExport(ctx, m, "Vector3", vector3_ctor);

    // Node prototype
    JSValue node_proto = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, node_proto, js_node_proto_funcs,
                               sizeof(js_node_proto_funcs) / sizeof(js_node_proto_funcs[0]));
    JS_SetClassProto(ctx, js_tachyon_node_class_id, node_proto);

    JSValue cube_ctor = JS_NewCFunction2(ctx, js_cube_constructor, "Cube", 1, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, cube_ctor, JS_DupValue(ctx, node_proto));
    JS_SetModuleExport(ctx, m, "Cube", cube_ctor);

    JSValue sphere_ctor = JS_NewCFunction2(ctx, js_sphere_constructor, "Sphere", 1, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, sphere_ctor, JS_DupValue(ctx, node_proto));
    JS_SetModuleExport(ctx, m, "Sphere", sphere_ctor);

    JSValue plane_ctor = JS_NewCFunction2(ctx, js_plane_constructor, "Plane", 1, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, plane_ctor, JS_DupValue(ctx, node_proto));
    JS_SetModuleExport(ctx, m, "Plane", plane_ctor);

    JSValue cylinder_ctor = JS_NewCFunction2(ctx, js_cylinder_constructor, "Cylinder", 1, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, cylinder_ctor, JS_DupValue(ctx, node_proto));
    JS_SetModuleExport(ctx, m, "Cylinder", cylinder_ctor);

    JSValue cone_ctor = JS_NewCFunction2(ctx, js_cone_constructor, "Cone", 1, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, cone_ctor, JS_DupValue(ctx, node_proto));
    JS_SetModuleExport(ctx, m, "Cone", cone_ctor);

    JSValue torus_ctor = JS_NewCFunction2(ctx, js_torus_constructor, "Torus", 1, JS_CFUNC_constructor, 0);
    JS_SetConstructor(ctx, torus_ctor, JS_DupValue(ctx, node_proto));
    JS_SetModuleExport(ctx, m, "Torus", torus_ctor);

    JSValue mesh_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, mesh_obj, "load", JS_NewCFunction(ctx, js_mesh_load, "load", 1));
    JS_SetModuleExport(ctx, m, "Mesh", mesh_obj);

    // Scene
    JSValue scene_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, scene_obj, "add", JS_NewCFunction(ctx, js_scene_add, "add", 1));
    JS_SetPropertyStr(ctx, scene_obj, "remove", JS_NewCFunction(ctx, js_scene_remove, "remove", 1));
    JS_SetPropertyStr(ctx, scene_obj, "find", JS_NewCFunction(ctx, js_scene_find, "find", 1));
    JS_SetPropertyStr(ctx, scene_obj, "clear", JS_NewCFunction(ctx, js_scene_clear, "clear", 0));
    JS_SetPropertyStr(ctx, scene_obj, "pick", JS_NewCFunction(ctx, js_scene_pick, "pick", 2));
    JS_SetModuleExport(ctx, m, "Scene", scene_obj);

    // Input
    JSValue input_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, input_obj, "keyDown", JS_NewCFunction(ctx, js_input_key_down, "keyDown", 1));
    JS_SetPropertyStr(ctx, input_obj, "keyPressed", JS_NewCFunction(ctx, js_input_key_pressed, "keyPressed", 1));
    JS_SetPropertyStr(ctx, input_obj, "keyReleased", JS_NewCFunction(ctx, js_input_key_released, "keyReleased", 1));
    JS_SetPropertyStr(ctx, input_obj, "mouseButtonDown", JS_NewCFunction(ctx, js_input_mouse_button_down, "mouseButtonDown", 1));
    JS_SetPropertyStr(ctx, input_obj, "mouseButtonPressed", JS_NewCFunction(ctx, js_input_mouse_button_pressed, "mouseButtonPressed", 1));
    JS_SetPropertyStr(ctx, input_obj, "mousePosition", JS_NewCFunction(ctx, js_input_mouse_position, "mousePosition", 0));
    JS_SetPropertyStr(ctx, input_obj, "mouseDelta", JS_NewCFunction(ctx, js_input_mouse_delta, "mouseDelta", 0));
    JS_SetModuleExport(ctx, m, "Input", input_obj);

    // GUI
    JSValue gui_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, gui_obj, "rect", JS_NewCFunction(ctx, js_gui_draw_rect, "rect", 8));
    JS_SetPropertyStr(ctx, gui_obj, "text", JS_NewCFunction(ctx, js_gui_draw_text, "text", 8));
    JS_SetPropertyStr(ctx, gui_obj, "clear", JS_NewCFunction(ctx, js_gui_clear, "clear", 0));
    JS_SetModuleExport(ctx, m, "GUI", gui_obj);

    // Sprite prototype
    JSValue sprite_proto = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, sprite_proto, js_sprite_proto_funcs,
                               sizeof(js_sprite_proto_funcs) / sizeof(js_sprite_proto_funcs[0]));
    JS_SetClassProto(ctx, js_sprite_class_id, sprite_proto);

    // Sprite (static factory)
    JSValue sprite_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, sprite_obj, "create", JS_NewCFunction(ctx, js_sprite_create, "create", 1));
    JS_SetPropertyStr(ctx, sprite_obj, "load", JS_NewCFunction(ctx, js_sprite_load, "load", 1));
    JS_SetModuleExport(ctx, m, "Sprite", sprite_obj);

    // Canvas (static object)
    JSValue canvas_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, canvas_obj, "setup", JS_NewCFunction(ctx, js_canvas_setup, "setup", 2));
    JS_SetPropertyStr(ctx, canvas_obj, "background", JS_NewCFunction(ctx, js_canvas_background, "background", 4));
    JS_SetPropertyStr(ctx, canvas_obj, "text", JS_NewCFunction(ctx, js_canvas_text, "text", 8));
    JS_SetModuleExport(ctx, m, "Canvas", canvas_obj);

    // Camera
    JSValue camera_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, camera_obj, "setPosition", JS_NewCFunction(ctx, js_camera_set_position, "setPosition", 1));
    JS_SetPropertyStr(ctx, camera_obj, "getPosition", JS_NewCFunction(ctx, js_camera_get_position, "getPosition", 0));
    JS_SetPropertyStr(ctx, camera_obj, "setTarget", JS_NewCFunction(ctx, js_camera_set_target, "setTarget", 1));
    JS_SetPropertyStr(ctx, camera_obj, "getTarget", JS_NewCFunction(ctx, js_camera_get_target, "getTarget", 0));
    JS_SetPropertyStr(ctx, camera_obj, "setFOV", JS_NewCFunction(ctx, js_camera_set_fov, "setFOV", 1));
    JS_SetModuleExport(ctx, m, "Camera", camera_obj);

    // Lighting
    JSValue pointlight_ctor = JS_NewCFunction2(ctx, js_pointlight_constructor, "PointLight", 1, JS_CFUNC_constructor, 0);
    JS_SetModuleExport(ctx, m, "PointLight", pointlight_ctor);

    // Audio
    JSValue audio_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, audio_obj, "play", JS_NewCFunction(ctx, js_audio_play, "play", 1));
    JS_SetPropertyStr(ctx, audio_obj, "load", JS_NewCFunction(ctx, js_audio_load, "load", 1));
    JS_SetPropertyStr(ctx, audio_obj, "stop", JS_NewCFunction(ctx, js_audio_stop, "stop", 1));
    JS_SetPropertyStr(ctx, audio_obj, "setVolume", JS_NewCFunction(ctx, js_audio_set_volume, "setVolume", 2));
    JS_SetModuleExport(ctx, m, "Audio", audio_obj);

    return 0;
}

/* =========================================================================
 * Public C API
 * ========================================================================= */

extern "C"
{

    void TachyonBridge_SetCallback(int slot, void *pointer, void *closure_data)
    {
        if (slot >= 0 && slot < CB_MAX)
        {
            g_callbacks[slot].pointer = pointer;
            g_callbacks[slot].closure_data = closure_data;
        }
    }

    void TachyonBridge_InitClasses(JSRuntime *rt)
    {
        JS_NewClassID(&js_tachyon_node_class_id);
        JS_NewClassID(&js_vector3_class_id);
        JS_NewClass(rt, js_tachyon_node_class_id, &js_node_class);
        JS_NewClass(rt, js_vector3_class_id, &js_vector3_class);
        JS_NewClassID(&js_sprite_class_id);
        JS_NewClass(rt, js_sprite_class_id, &js_sprite_class);
    }

    JSModuleDef *TachyonBridge_RegisterModule(JSContext *ctx)
    {
        JSModuleDef *m = JS_NewCModule(ctx, "tachyon", js_tachyon_module_init);
        if (!m)
            return nullptr;
        JS_AddModuleExport(ctx, m, "Vector3");
        JS_AddModuleExport(ctx, m, "Cube");
        JS_AddModuleExport(ctx, m, "Sphere");
        JS_AddModuleExport(ctx, m, "Plane");
        JS_AddModuleExport(ctx, m, "Cylinder");
        JS_AddModuleExport(ctx, m, "Cone");
        JS_AddModuleExport(ctx, m, "Torus");
        JS_AddModuleExport(ctx, m, "Mesh");
        JS_AddModuleExport(ctx, m, "Scene");
        JS_AddModuleExport(ctx, m, "Input");
        JS_AddModuleExport(ctx, m, "GUI");
        JS_AddModuleExport(ctx, m, "Sprite");
        JS_AddModuleExport(ctx, m, "Canvas");
        JS_AddModuleExport(ctx, m, "Camera");
        JS_AddModuleExport(ctx, m, "PointLight");
        JS_AddModuleExport(ctx, m, "Audio");

        return m;
    }

    int TachyonBridge_CallOnStart(JSContext *ctx, JSValue module_ns)
    {
        JSValue fn = JS_GetPropertyStr(ctx, module_ns, "onStart");
        if (JS_IsFunction(ctx, fn))
        {
            JSValue ret = JS_Call(ctx, fn, JS_UNDEFINED, 0, nullptr);
            int err = JS_IsException(ret);
            JS_FreeValue(ctx, ret);
            JS_FreeValue(ctx, fn);
            return err ? -1 : 0;
        }
        JS_FreeValue(ctx, fn);
        return 0;
    }

    int TachyonBridge_CallOnUpdate(JSContext *ctx, JSValue module_ns, double dt)
    {
        JSValue fn = JS_GetPropertyStr(ctx, module_ns, "onUpdate");
        if (JS_IsFunction(ctx, fn))
        {
            JSValue arg = JS_NewFloat64(ctx, dt);
            JSValue ret = JS_Call(ctx, fn, JS_UNDEFINED, 1, &arg);
            int err = JS_IsException(ret);
            JS_FreeValue(ctx, ret);
            JS_FreeValue(ctx, arg);
            JS_FreeValue(ctx, fn);
            return err ? -1 : 0;
        }
        JS_FreeValue(ctx, fn);
        return 0;
    }

    int TachyonBridge_CallOnFixedUpdate(JSContext *ctx, JSValue module_ns, double dt)
    {
        JSValue fn = JS_GetPropertyStr(ctx, module_ns, "onFixedUpdate");
        if (JS_IsFunction(ctx, fn))
        {
            JSValue arg = JS_NewFloat64(ctx, dt);
            JSValue ret = JS_Call(ctx, fn, JS_UNDEFINED, 1, &arg);
            int err = JS_IsException(ret);
            JS_FreeValue(ctx, ret);
            JS_FreeValue(ctx, arg);
            JS_FreeValue(ctx, fn);
            return err ? -1 : 0;
        }
        JS_FreeValue(ctx, fn);
        return 0;
    }

    JSValue TachyonBridge_GetModuleNamespace(JSContext *ctx, JSModuleDef *m)
    {
        return JS_GetModuleNamespace(ctx, m);
    }

} // extern "C"
