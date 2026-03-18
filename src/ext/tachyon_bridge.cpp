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
    CB_SCENE_PICK,
    CB_SCENE_SAVE,
    CB_SCENE_LOAD_FILE,
    CB_SCENE_LOAD_ENVIRONMENT,
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
    CB_INPUT_LOCK_CURSOR,
    CB_INPUT_UNLOCK_CURSOR,
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
    CB_NODE_LOAD_TEXTURE,
    CB_NODE_SET_TEXTURE_SCALE,
    CB_NODE_SET_MATERIAL_EMISSIVE,
    CB_NODE_SET_MATERIAL_EMISSIVE_STRENGTH,
    CB_SPRITE_SET_ATLAS,
    CB_SPRITE_PLAY_ANIMATION,
    CB_SPRITE_STOP_ANIMATION,
    CB_SPRITE_SET_FRAME,
    CB_PARTICLE_CREATE_EMITTER,
    CB_PARTICLE_DESTROY_EMITTER,
    CB_PARTICLE_SET_POSITION,
    CB_PARTICLE_SET_DIRECTION,
    CB_PARTICLE_SET_COLORS,
    CB_PARTICLE_SET_SIZES,
    CB_PARTICLE_SET_SPEED,
    CB_PARTICLE_SET_LIFETIME,
    CB_PARTICLE_SET_GRAVITY,
    CB_PARTICLE_SET_RATE,
    CB_PARTICLE_SET_SPREAD,
    CB_PARTICLE_SET_ACTIVE,
    CB_PARTICLE_EMIT_BURST,
    CB_PARTICLE_LOAD_TEXTURE,
    CB_TOGGLE_FOG,
    CB_SET_FOG_PARAMETERS,
    CB_TOGGLE_BLOOM,
    CB_SET_BLOOM_PARAMETERS,
    CB_TOGGLE_SSAO,
    CB_SET_SSAO_PARAMETERS,
    CB_TOGGLE_SHADOW,
    CB_SET_SHADOW_RESOLUTION,
    CB_TOGGLE_SKYBOX,
    CB_SET_SKYBOX_TOP_COLOR,
    CB_SET_SKYBOX_BOTTOM_COLOR,
    CB_TOGGLE_VIGNETTE,
    CB_SET_VIGNETTE_PARAMETERS,
    CB_TOGGLE_CHROMATIC_ABERRATION,
    CB_SET_CHROMATIC_ABERRATION_STRENGTH,
    CB_TOGGLE_COLOR_GRADING,
    CB_SET_COLOR_GRADING_PARAMETERS,
    CB_TOGGLE_FXAA,
    CB_SET_AMBIENT_COLOR,
    CB_PIPELINE_TOGGLE_STAGE,
    CB_PIPELINE_MOVE_STAGE,
    CB_PIPELINE_REMOVE_STAGE,
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

// void fn(uint32, const char*, int)
static void call_u32_s_i_void(CallbackSlot slot, uint32_t h, const char *s, int i)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, const char *, int);
    ((Fn)cb.pointer)(cb.closure_data, h, s, i);
}

// void fn(int, float, float, float, float, float, int)
static void call_i_5f_i_void(CallbackSlot slot, int enabled, float a, float b, float c, float d, float e, int mode)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, int, float, float, float, float, float, int);
    ((Fn)cb.pointer)(cb.closure_data, enabled, a, b, c, d, e, mode);
}

// void fn(int)
static void call_i_void(CallbackSlot slot, int v)
{
    auto &cb = g_callbacks[slot];
    if (!cb.isValid())
        return;
    typedef void (*Fn)(void *, uint32_t, int);
    ((Fn)cb.pointer)(cb.closure_data, 0, v);
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

// node.loadTexture(path, slot)
// slot: 0 = albedo, 1 = normal, 2 = metallicRoughness, 3 = ao, 4 = emissive
static JSValue js_node_load_texture(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 2)
        return JS_ThrowTypeError(ctx, "loadTexture(path, slot)");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    int slot = 0;
    JS_ToInt32(ctx, &slot, argv[1]);
    call_u32_s_i_void(CB_NODE_LOAD_TEXTURE, h, path, slot);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
}

static JSValue js_node_set_texture_scale(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 2)
        return JS_ThrowTypeError(ctx, "setTextureScale(x, y)");
    double x, y;
    JS_ToFloat64(ctx, &x, argv[0]);
    JS_ToFloat64(ctx, &y, argv[1]);
    call_u32_fff_void(CB_NODE_SET_TEXTURE_SCALE, h, (float)x, (float)y, 0);
    return JS_UNDEFINED;
}

static JSValue js_node_set_material_emissive(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 3)
        return JS_ThrowTypeError(ctx, "setMaterialEmissive(r, g, b)");
    double r, g, b;
    JS_ToFloat64(ctx, &r, argv[0]);
    JS_ToFloat64(ctx, &g, argv[1]);
    JS_ToFloat64(ctx, &b, argv[2]);
    call_u32_fff_void(CB_NODE_SET_MATERIAL_EMISSIVE, h, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

static JSValue js_node_set_material_emissive_strength(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "setMaterialEmissiveStrength(value)");
    double val;
    JS_ToFloat64(ctx, &val, argv[0]);
    call_u32_f_void(CB_NODE_SET_MATERIAL_EMISSIVE_STRENGTH, h, (float)val);
    return JS_UNDEFINED;
}

static JSValue js_node_set_material_roughness(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "setMaterialRoughness(value)");
    double val;
    JS_ToFloat64(ctx, &val, argv[0]);
    call_u32_f_void(CB_NODE_SET_MATERIAL_ROUGHNESS, h, (float)val);
    return JS_UNDEFINED;
}

static JSValue js_node_set_material_metallic(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_tachyon_node_class_id);
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "setMaterialMetallic(value)");
    double val;
    JS_ToFloat64(ctx, &val, argv[0]);
    call_u32_f_void(CB_NODE_SET_MATERIAL_METALLIC, h, (float)val);
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
    JS_CFUNC_DEF("loadTexture", 2, js_node_load_texture),
    JS_CFUNC_DEF("setTextureScale", 2, js_node_set_texture_scale),
    JS_CFUNC_DEF("setMaterialEmissive", 3, js_node_set_material_emissive),
    JS_CFUNC_DEF("setMaterialEmissiveStrength", 1, js_node_set_material_emissive_strength),
    JS_CFUNC_DEF("setMaterialRoughness", 1, js_node_set_material_roughness),
    JS_CFUNC_DEF("setMaterialMetallic", 1, js_node_set_material_metallic),
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

static JSValue js_scene_pick(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double x = 0, y = 0;
    if (argc >= 1)
        JS_ToFloat64(ctx, &x, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &y, argv[1]);
    uint32_t handle = call_ff_u32(CB_SCENE_PICK, (float)x, (float)y);
    if (handle == 0)
        return JS_UNDEFINED;
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, handle);
    return obj;
}

// Scene.setFog({ color: [r,g,b], near, far, density, mode })
// mode: "linear" (default), "exponential", "exponential2"
static JSValue js_scene_set_fog(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "setFog requires an options object");

    JSValueConst opts = argv[0];

    double near_val = 10.0, far_val = 100.0, density = 0.01;
    double fog_r = 0.7, fog_g = 0.7, fog_b = 0.7;
    int mode = 0;

    JSValue color_val = JS_GetPropertyStr(ctx, opts, "color");
    if (JS_IsArray(ctx, color_val))
    {
        JSValue c0 = JS_GetPropertyUint32(ctx, color_val, 0);
        JSValue c1 = JS_GetPropertyUint32(ctx, color_val, 1);
        JSValue c2 = JS_GetPropertyUint32(ctx, color_val, 2);
        JS_ToFloat64(ctx, &fog_r, c0);
        JS_ToFloat64(ctx, &fog_g, c1);
        JS_ToFloat64(ctx, &fog_b, c2);
        JS_FreeValue(ctx, c0);
        JS_FreeValue(ctx, c1);
        JS_FreeValue(ctx, c2);
    }
    JS_FreeValue(ctx, color_val);

    JSValue near_prop = JS_GetPropertyStr(ctx, opts, "near");
    if (!JS_IsUndefined(near_prop))
        JS_ToFloat64(ctx, &near_val, near_prop);
    JS_FreeValue(ctx, near_prop);

    JSValue far_prop = JS_GetPropertyStr(ctx, opts, "far");
    if (!JS_IsUndefined(far_prop))
        JS_ToFloat64(ctx, &far_val, far_prop);
    JS_FreeValue(ctx, far_prop);

    JSValue density_prop = JS_GetPropertyStr(ctx, opts, "density");
    if (!JS_IsUndefined(density_prop))
        JS_ToFloat64(ctx, &density, density_prop);
    JS_FreeValue(ctx, density_prop);

    JSValue mode_prop = JS_GetPropertyStr(ctx, opts, "mode");
    if (JS_IsString(mode_prop))
    {
        const char *mode_str = JS_ToCString(ctx, mode_prop);
        if (mode_str)
        {
            if (strcmp(mode_str, "exponential") == 0)
                mode = 1;
            else if (strcmp(mode_str, "exponential2") == 0)
                mode = 2;
            JS_FreeCString(ctx, mode_str);
        }
    }
    JS_FreeValue(ctx, mode_prop);

    call_i_void(CB_TOGGLE_FOG, 1);
    call_8f_void(CB_SET_FOG_PARAMETERS,
                 (float)fog_r, (float)fog_g, (float)fog_b,
                 (float)near_val, (float)far_val, (float)density, (float)mode, 0.0f);

    return JS_UNDEFINED;
}

static JSValue js_scene_clear_fog(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    call_i_void(CB_TOGGLE_FOG, 0);
    return JS_UNDEFINED;
}

static JSValue js_scene_load_environment(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Scene.loadEnvironment(path)");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    call_s_u32(CB_SCENE_LOAD_ENVIRONMENT, path);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
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

static JSValue js_input_lock_cursor(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    call_void(CB_INPUT_LOCK_CURSOR);
    return JS_UNDEFINED;
}

static JSValue js_input_unlock_cursor(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    call_void(CB_INPUT_UNLOCK_CURSOR);
    return JS_UNDEFINED;
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

static JSValue js_sprite_set_atlas(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    if (argc < 2)
        return JS_ThrowTypeError(ctx, "setAtlas(columns, rows)");
    int columns = 1, rows = 1;
    JS_ToInt32(ctx, &columns, argv[0]);
    JS_ToInt32(ctx, &rows, argv[1]);
    call_u32_fff_void(CB_SPRITE_SET_ATLAS, h, (float)columns, (float)rows, 0);
    return JS_UNDEFINED;
}

static JSValue js_sprite_set_frame(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "setFrame(index)");
    int frame = 0;
    JS_ToInt32(ctx, &frame, argv[0]);
    call_u32_i_void(CB_SPRITE_SET_FRAME, h, frame);
    return JS_UNDEFINED;
}

// sprite.playAnimation({ frames: [0,1,2,3], fps: 12, loop: true })
static JSValue js_sprite_play_animation(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "playAnimation(options)");

    JSValueConst opts = argv[0];
    double fps = 12.0;
    int loop = 1;

    JSValue fps_prop = JS_GetPropertyStr(ctx, opts, "fps");
    if (!JS_IsUndefined(fps_prop))
        JS_ToFloat64(ctx, &fps, fps_prop);
    JS_FreeValue(ctx, fps_prop);

    JSValue loop_prop = JS_GetPropertyStr(ctx, opts, "loop");
    if (!JS_IsUndefined(loop_prop))
        loop = JS_ToBool(ctx, loop_prop);
    JS_FreeValue(ctx, loop_prop);

    // Build frames string: comma-separated frame indices
    JSValue frames_prop = JS_GetPropertyStr(ctx, opts, "frames");
    if (JS_IsArray(ctx, frames_prop))
    {
        JSValue len_val = JS_GetPropertyStr(ctx, frames_prop, "length");
        int32_t len = 0;
        JS_ToInt32(ctx, &len, len_val);
        JS_FreeValue(ctx, len_val);

        char frames_str[2048] = {0};
        int pos = 0;
        for (int32_t i = 0; i < len && pos < 2040; i++)
        {
            JSValue elem = JS_GetPropertyUint32(ctx, frames_prop, i);
            int32_t frame_idx = 0;
            JS_ToInt32(ctx, &frame_idx, elem);
            JS_FreeValue(ctx, elem);
            if (i > 0)
                frames_str[pos++] = ',';
            pos += snprintf(frames_str + pos, 2048 - pos, "%d", frame_idx);
        }

        // Encode: "frames_csv|fps|loop" as a single string, plus handle
        char buf[2200];
        snprintf(buf, sizeof(buf), "%s|%.2f|%d", frames_str, fps, loop);
        call_u32_s_void(CB_SPRITE_PLAY_ANIMATION, h, buf);
    }
    JS_FreeValue(ctx, frames_prop);

    return JS_UNDEFINED;
}

static JSValue js_sprite_stop_animation(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    uint32_t h = get_handle(ctx, this_val, js_sprite_class_id);
    call_u32_void(CB_SPRITE_STOP_ANIMATION, h);
    return JS_UNDEFINED;
}

static const JSCFunctionListEntry js_sprite_proto_funcs[] = {
    JS_CGETSET_DEF("x", js_sprite_get_x, js_sprite_set_x),
    JS_CGETSET_DEF("y", js_sprite_get_y, js_sprite_set_y),
    JS_CGETSET_DEF("visible", NULL, js_sprite_set_visible_prop),
    JS_CGETSET_DEF("layer", NULL, js_sprite_set_layer),
    JS_CFUNC_DEF("setColor", 4, js_sprite_set_color),
    JS_CFUNC_DEF("destroy", 0, js_sprite_destroy_fn),
    JS_CFUNC_DEF("setAtlas", 2, js_sprite_set_atlas),
    JS_CFUNC_DEF("setFrame", 1, js_sprite_set_frame),
    JS_CFUNC_DEF("playAnimation", 1, js_sprite_play_animation),
    JS_CFUNC_DEF("stopAnimation", 0, js_sprite_stop_animation),
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
static JSValue js_pointlight_constructor(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    float x = 0, y = 2, z = 0, r = 1, g = 1, b = 1, intensity = 1, range = 10;
    if (argc >= 1 && !JS_IsUndefined(argv[0]))
    {
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
    if (handle != 0)
    {
        call_u32_fff_void(CB_LIGHT_SET_COLOR, handle, r, g, b);
        call_u32_f_void(CB_LIGHT_SET_RANGE, handle, range);
    }
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, handle);
    return obj;
}

// Audio.play("path") — fire and forget
static JSValue js_audio_play(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Audio.play requires a path");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    call_s_u32(CB_AUDIO_PLAY_SOUND, path);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
}

// Audio.load("path") — returns handle for control
static JSValue js_audio_load(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Audio.load requires a path");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    uint32_t handle = call_s_u32(CB_AUDIO_LOAD_SOUND, path);
    JS_FreeCString(ctx, path);
    if (handle == 0)
        return JS_UNDEFINED;
    JSValue obj = JS_NewObjectClass(ctx, (int)js_tachyon_node_class_id);
    set_handle(obj, handle);
    return obj;
}

// Audio.stop(handle)
static JSValue js_audio_stop(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_UNDEFINED;
    uint32_t h = get_handle(ctx, argv[0], js_tachyon_node_class_id);
    if (h)
        call_u32_void(CB_AUDIO_STOP_SOUND, h);
    return JS_UNDEFINED;
}

// Audio.setVolume(handle, volume)
static JSValue js_audio_set_volume(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h = get_handle(ctx, argv[0], js_tachyon_node_class_id);
    double vol = 1.0;
    JS_ToFloat64(ctx, &vol, argv[1]);
    if (h)
        call_u32_f_void(CB_AUDIO_SET_VOLUME, h, (float)vol);
    return JS_UNDEFINED;
}

// Particles.createEmitter({ maxParticles })
static JSValue js_particle_create_emitter(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    int max_particles = 256;
    if (argc >= 1 && JS_IsObject(argv[0]))
    {
        JSValue mp = JS_GetPropertyStr(ctx, argv[0], "maxParticles");
        if (!JS_IsUndefined(mp))
            JS_ToInt32(ctx, &max_particles, mp);
        JS_FreeValue(ctx, mp);
    }
    uint32_t handle = call_fii_u32(CB_PARTICLE_CREATE_EMITTER, 0, max_particles, 0);
    return JS_NewUint32(ctx, handle);
}

static JSValue js_particle_destroy_emitter(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    call_u32_void(CB_PARTICLE_DESTROY_EMITTER, h);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_position(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    Vec3Data *v = js_vector3_get(ctx, argv[1]);
    if (v)
        call_u32_fff_void(CB_PARTICLE_SET_POSITION, h, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_direction(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    Vec3Data *v = js_vector3_get(ctx, argv[1]);
    if (v)
        call_u32_fff_void(CB_PARTICLE_SET_DIRECTION, h, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

// Particles.setColors(handle, startR, startG, startB, endR, endG, endB)
static JSValue js_particle_set_colors(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 3)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    Vec3Data *start = js_vector3_get(ctx, argv[1]);
    Vec3Data *end = js_vector3_get(ctx, argv[2]);
    if (start && end)
    {
        // Pack 6 floats + 2 padding into call_8f_void via the handle embedded in first float
        call_8f_void(CB_PARTICLE_SET_COLORS,
                     *(float *)&h, start->x, start->y, start->z,
                     end->x, end->y, end->z, 0);
    }
    return JS_UNDEFINED;
}

static JSValue js_particle_set_sizes(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 3)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    double start_size, end_size;
    JS_ToFloat64(ctx, &start_size, argv[1]);
    JS_ToFloat64(ctx, &end_size, argv[2]);
    call_u32_fff_void(CB_PARTICLE_SET_SIZES, h, (float)start_size, (float)end_size, 0);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_speed(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 3)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    double min_speed, max_speed;
    JS_ToFloat64(ctx, &min_speed, argv[1]);
    JS_ToFloat64(ctx, &max_speed, argv[2]);
    call_u32_fff_void(CB_PARTICLE_SET_SPEED, h, (float)min_speed, (float)max_speed, 0);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_lifetime(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 3)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    double min_life, max_life;
    JS_ToFloat64(ctx, &min_life, argv[1]);
    JS_ToFloat64(ctx, &max_life, argv[2]);
    call_u32_fff_void(CB_PARTICLE_SET_LIFETIME, h, (float)min_life, (float)max_life, 0);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_gravity(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    Vec3Data *v = js_vector3_get(ctx, argv[1]);
    if (v)
        call_u32_fff_void(CB_PARTICLE_SET_GRAVITY, h, v->x, v->y, v->z);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_rate(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    double rate;
    JS_ToFloat64(ctx, &rate, argv[1]);
    call_u32_f_void(CB_PARTICLE_SET_RATE, h, (float)rate);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_spread(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    double spread;
    JS_ToFloat64(ctx, &spread, argv[1]);
    call_u32_f_void(CB_PARTICLE_SET_SPREAD, h, (float)spread);
    return JS_UNDEFINED;
}

static JSValue js_particle_set_active(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    call_u32_i_void(CB_PARTICLE_SET_ACTIVE, h, JS_ToBool(ctx, argv[1]));
    return JS_UNDEFINED;
}

static JSValue js_particle_emit_burst(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    int count = 10;
    JS_ToInt32(ctx, &count, argv[1]);
    call_u32_i_void(CB_PARTICLE_EMIT_BURST, h, count);
    return JS_UNDEFINED;
}

static JSValue js_particle_load_texture(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_UNDEFINED;
    uint32_t h;
    JS_ToUint32(ctx, &h, argv[0]);
    const char *path = JS_ToCString(ctx, argv[1]);
    if (!path)
        return JS_EXCEPTION;
    call_u32_s_void(CB_PARTICLE_LOAD_TEXTURE, h, path);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
}

// Scene.save(path) / Scene.load(path)
static JSValue js_scene_save(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Scene.save(path)");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    call_s_u32(CB_SCENE_SAVE, path);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
}

static JSValue js_scene_load_file(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Scene.load(path)");
    const char *path = JS_ToCString(ctx, argv[0]);
    if (!path)
        return JS_EXCEPTION;
    call_s_u32(CB_SCENE_LOAD_FILE, path);
    JS_FreeCString(ctx, path);
    return JS_UNDEFINED;
}

// Debug
static JSValue js_debug_log(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    fprintf(stderr, "[Log] ");
    for (int i = 0; i < argc; i++)
    {
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str)
        {
            fprintf(stderr, "%s", str);
            JS_FreeCString(ctx, str);
        }
        if (i < argc - 1)
            fprintf(stderr, " ");
    }
    fprintf(stderr, "\n");
    return JS_UNDEFINED;
}

static JSValue js_debug_warning(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    fprintf(stderr, "\033[33m[Warning] ");
    for (int i = 0; i < argc; i++)
    {
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str)
        {
            fprintf(stderr, "%s", str);
            JS_FreeCString(ctx, str);
        }
        if (i < argc - 1)
            fprintf(stderr, " ");
    }
    fprintf(stderr, "\033[0m\n");
    return JS_UNDEFINED;
}

static JSValue js_debug_error(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    fprintf(stderr, "\033[31m[Error] ");
    for (int i = 0; i < argc; i++)
    {
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str)
        {
            fprintf(stderr, "%s", str);
            JS_FreeCString(ctx, str);
        }
        if (i < argc - 1)
            fprintf(stderr, " ");
    }
    fprintf(stderr, "\033[0m\n");
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleBloom()
static JSValue js_config_toggle_bloom(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_BLOOM));
}

// Configuration.setBloomParameters(threshold, intensity)
static JSValue js_config_set_bloom_params(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double threshold = 0.6, intensity = 0.4;
    if (argc >= 1)
        JS_ToFloat64(ctx, &threshold, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &intensity, argv[1]);
    call_ff_u32(CB_SET_BLOOM_PARAMETERS, (float)threshold, (float)intensity);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleSSAO()
static JSValue js_config_toggle_ssao(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_SSAO));
}

// Configuration.setSSAOParameters(radius, bias)
static JSValue js_config_set_ssao_params(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double radius = 0.5, bias = 0.025;
    if (argc >= 1)
        JS_ToFloat64(ctx, &radius, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &bias, argv[1]);
    call_ff_u32(CB_SET_SSAO_PARAMETERS, (float)radius, (float)bias);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleShadow()
static JSValue js_config_toggle_shadow(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_SHADOW));
}

// Configuration.setShadowResolution(resolution)
static JSValue js_config_set_shadow_resolution(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "setShadowResolution(resolution)");
    int32_t res = 4096;
    JS_ToInt32(ctx, &res, argv[0]);
    call_u32_i_void(CB_SET_SHADOW_RESOLUTION, 0, res);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleSkybox()
static JSValue js_config_toggle_skybox(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_SKYBOX));
}

// Configuration.setSkyboxTopColor(r, g, b)
static JSValue js_config_set_skybox_top_color(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double r = 0.4, g = 0.6, b = 0.9;
    if (argc >= 1)
        JS_ToFloat64(ctx, &r, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &g, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &b, argv[2]);
    call_u32_fff_void(CB_SET_SKYBOX_TOP_COLOR, 0, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

// Configuration.setSkyboxBottomColor(r, g, b)
static JSValue js_config_set_skybox_bottom_color(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double r = 0.9, g = 0.85, b = 0.7;
    if (argc >= 1)
        JS_ToFloat64(ctx, &r, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &g, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &b, argv[2]);
    call_u32_fff_void(CB_SET_SKYBOX_BOTTOM_COLOR, 1, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleVignette()
static JSValue js_config_toggle_vignette(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_VIGNETTE));
}

// Configuration.setVignetteParameters(intensity, smoothness)
static JSValue js_config_set_vignette_params(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double intensity = 0.4, smoothness = 0.5;
    if (argc >= 1)
        JS_ToFloat64(ctx, &intensity, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &smoothness, argv[1]);
    call_ff_u32(CB_SET_VIGNETTE_PARAMETERS, (float)intensity, (float)smoothness);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleChromaticAberration()
static JSValue js_config_toggle_chromatic_aberration(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_CHROMATIC_ABERRATION));
}

// Configuration.setChromaticAberrationStrength(strength)
static JSValue js_config_set_chromatic_strength(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double strength = 0.003;
    if (argc >= 1)
        JS_ToFloat64(ctx, &strength, argv[0]);
    call_u32_f_void(CB_SET_CHROMATIC_ABERRATION_STRENGTH, 0, (float)strength);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleColorGrading()
static JSValue js_config_toggle_color_grading(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_COLOR_GRADING));
}

// Configuration.setColorGradingParameters(exposure, contrast, saturation, tintR, tintG, tintB)
static JSValue js_config_set_color_grading_params(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double exposure = 1, contrast = 1, saturation = 1, tr = 1, tg = 1, tb = 1;
    if (argc >= 1)
        JS_ToFloat64(ctx, &exposure, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &contrast, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &saturation, argv[2]);
    if (argc >= 4)
        JS_ToFloat64(ctx, &tr, argv[3]);
    if (argc >= 5)
        JS_ToFloat64(ctx, &tg, argv[4]);
    if (argc >= 6)
        JS_ToFloat64(ctx, &tb, argv[5]);
    call_8f_void(CB_SET_COLOR_GRADING_PARAMETERS,
                 (float)exposure, (float)contrast, (float)saturation,
                 (float)tr, (float)tg, (float)tb, 0, 0);
    return JS_UNDEFINED;
}

// const isEnabled = Configuration.toggleFXAA()
static JSValue js_config_toggle_fxaa(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBool(ctx, call_u32(CB_TOGGLE_FXAA));
}

// Configuration.setAmbientColor(r, g, b)
static JSValue js_config_set_ambient_color(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    double r = 0.2, g = 0.2, b = 0.22;
    if (argc >= 1)
        JS_ToFloat64(ctx, &r, argv[0]);
    if (argc >= 2)
        JS_ToFloat64(ctx, &g, argv[1]);
    if (argc >= 3)
        JS_ToFloat64(ctx, &b, argv[2]);
    call_fff_u32(CB_SET_AMBIENT_COLOR, (float)r, (float)g, (float)b);
    return JS_UNDEFINED;
}

/* =========================================================================
 * Pipeline — lets JS toggle, reorder, and remove pipeline stages
 * ========================================================================= */

// Pipeline.toggleStage(name, enabled)
static JSValue js_pipeline_toggle_stage(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_ThrowTypeError(ctx, "Pipeline.toggleStage(name, enabled)");
    const char *name = JS_ToCString(ctx, argv[0]);
    if (!name)
        return JS_EXCEPTION;
    int enabled = JS_ToBool(ctx, argv[1]);
    // Use call_u32_s_void pattern: reuse slot with (name, enabled)
    auto &cb = g_callbacks[CB_PIPELINE_TOGGLE_STAGE];
    if (cb.isValid())
    {
        typedef void (*Fn)(void *, const char *, int);
        ((Fn)cb.pointer)(cb.closure_data, name, enabled);
    }
    JS_FreeCString(ctx, name);
    return JS_UNDEFINED;
}

// Pipeline.moveStage(name, newIndex)
static JSValue js_pipeline_move_stage(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 2)
        return JS_ThrowTypeError(ctx, "Pipeline.moveStage(name, index)");
    const char *name = JS_ToCString(ctx, argv[0]);
    if (!name)
        return JS_EXCEPTION;
    int32_t idx = 0;
    JS_ToInt32(ctx, &idx, argv[1]);
    auto &cb = g_callbacks[CB_PIPELINE_MOVE_STAGE];
    if (cb.isValid())
    {
        typedef uint32_t (*Fn)(void *, const char *, int);
        ((Fn)cb.pointer)(cb.closure_data, name, idx);
    }
    JS_FreeCString(ctx, name);
    return JS_UNDEFINED;
}

// Pipeline.removeStage(name)
static JSValue js_pipeline_remove_stage(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    if (argc < 1)
        return JS_ThrowTypeError(ctx, "Pipeline.removeStage(name)");
    const char *name = JS_ToCString(ctx, argv[0]);
    if (!name)
        return JS_EXCEPTION;
    call_s_u32(CB_PIPELINE_REMOVE_STAGE, name);
    JS_FreeCString(ctx, name);
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
    JS_SetPropertyStr(ctx, scene_obj, "setFog", JS_NewCFunction(ctx, js_scene_set_fog, "setFog", 1));
    JS_SetPropertyStr(ctx, scene_obj, "clearFog", JS_NewCFunction(ctx, js_scene_clear_fog, "clearFog", 0));
    JS_SetPropertyStr(ctx, scene_obj, "save", JS_NewCFunction(ctx, js_scene_save, "save", 1));
    JS_SetPropertyStr(ctx, scene_obj, "load", JS_NewCFunction(ctx, js_scene_load_file, "load", 1));
    JS_SetPropertyStr(ctx, scene_obj, "loadEnvironment", JS_NewCFunction(ctx, js_scene_load_environment, "loadEnvironment", 1));
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
    JS_SetPropertyStr(ctx, input_obj, "lockCursor", JS_NewCFunction(ctx, js_input_lock_cursor, "lockCursor", 0));
    JS_SetPropertyStr(ctx, input_obj, "unlockCursor", JS_NewCFunction(ctx, js_input_unlock_cursor, "unlockCursor", 0));
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

    // Particles
    JSValue particles_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, particles_obj, "createEmitter", JS_NewCFunction(ctx, js_particle_create_emitter, "createEmitter", 1));
    JS_SetPropertyStr(ctx, particles_obj, "destroyEmitter", JS_NewCFunction(ctx, js_particle_destroy_emitter, "destroyEmitter", 1));
    JS_SetPropertyStr(ctx, particles_obj, "setPosition", JS_NewCFunction(ctx, js_particle_set_position, "setPosition", 2));
    JS_SetPropertyStr(ctx, particles_obj, "setDirection", JS_NewCFunction(ctx, js_particle_set_direction, "setDirection", 2));
    JS_SetPropertyStr(ctx, particles_obj, "setColors", JS_NewCFunction(ctx, js_particle_set_colors, "setColors", 3));
    JS_SetPropertyStr(ctx, particles_obj, "setSizes", JS_NewCFunction(ctx, js_particle_set_sizes, "setSizes", 3));
    JS_SetPropertyStr(ctx, particles_obj, "setSpeed", JS_NewCFunction(ctx, js_particle_set_speed, "setSpeed", 3));
    JS_SetPropertyStr(ctx, particles_obj, "setLifetime", JS_NewCFunction(ctx, js_particle_set_lifetime, "setLifetime", 3));
    JS_SetPropertyStr(ctx, particles_obj, "setGravity", JS_NewCFunction(ctx, js_particle_set_gravity, "setGravity", 2));
    JS_SetPropertyStr(ctx, particles_obj, "setRate", JS_NewCFunction(ctx, js_particle_set_rate, "setRate", 2));
    JS_SetPropertyStr(ctx, particles_obj, "setSpread", JS_NewCFunction(ctx, js_particle_set_spread, "setSpread", 2));
    JS_SetPropertyStr(ctx, particles_obj, "setActive", JS_NewCFunction(ctx, js_particle_set_active, "setActive", 2));
    JS_SetPropertyStr(ctx, particles_obj, "emitBurst", JS_NewCFunction(ctx, js_particle_emit_burst, "emitBurst", 2));
    JS_SetPropertyStr(ctx, particles_obj, "loadTexture", JS_NewCFunction(ctx, js_particle_load_texture, "loadTexture", 2));
    JS_SetModuleExport(ctx, m, "Particles", particles_obj);

    // Debug
    JSValue debug_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, debug_obj, "log", JS_NewCFunction(ctx, js_debug_log, "log", 1));
    JS_SetPropertyStr(ctx, debug_obj, "warning", JS_NewCFunction(ctx, js_debug_warning, "warning", 1));
    JS_SetPropertyStr(ctx, debug_obj, "error", JS_NewCFunction(ctx, js_debug_error, "error", 1));
    JS_SetModuleExport(ctx, m, "Debug", debug_obj);

    // Configuration
    JSValue config_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, config_obj, "toggleBloom", JS_NewCFunction(ctx, js_config_toggle_bloom, "toggleBloom", 0));
    JS_SetPropertyStr(ctx, config_obj, "setBloomParameters", JS_NewCFunction(ctx, js_config_set_bloom_params, "setBloomParameters", 2));
    JS_SetPropertyStr(ctx, config_obj, "toggleSSAO", JS_NewCFunction(ctx, js_config_toggle_ssao, "toggleSSAO", 0));
    JS_SetPropertyStr(ctx, config_obj, "setSSAOParameters", JS_NewCFunction(ctx, js_config_set_ssao_params, "setSSAOParameters", 2));
    JS_SetPropertyStr(ctx, config_obj, "toggleShadow", JS_NewCFunction(ctx, js_config_toggle_shadow, "toggleShadow", 0));
    JS_SetPropertyStr(ctx, config_obj, "setShadowResolution", JS_NewCFunction(ctx, js_config_set_shadow_resolution, "setShadowResolution", 1));
    JS_SetPropertyStr(ctx, config_obj, "toggleSkybox", JS_NewCFunction(ctx, js_config_toggle_skybox, "toggleSkybox", 0));
    JS_SetPropertyStr(ctx, config_obj, "setSkyboxTopColor", JS_NewCFunction(ctx, js_config_set_skybox_top_color, "setSkyboxTopColor", 3));
    JS_SetPropertyStr(ctx, config_obj, "setSkyboxBottomColor", JS_NewCFunction(ctx, js_config_set_skybox_bottom_color, "setSkyboxBottomColor", 3));
    JS_SetPropertyStr(ctx, config_obj, "toggleVignette", JS_NewCFunction(ctx, js_config_toggle_vignette, "toggleVignette", 0));
    JS_SetPropertyStr(ctx, config_obj, "setVignetteParameters", JS_NewCFunction(ctx, js_config_set_vignette_params, "setVignetteParameters", 2));
    JS_SetPropertyStr(ctx, config_obj, "toggleChromaticAberration", JS_NewCFunction(ctx, js_config_toggle_chromatic_aberration, "toggleChromaticAberration", 0));
    JS_SetPropertyStr(ctx, config_obj, "setChromaticAberrationStrength", JS_NewCFunction(ctx, js_config_set_chromatic_strength, "setChromaticAberrationStrength", 1));
    JS_SetPropertyStr(ctx, config_obj, "toggleColorGrading", JS_NewCFunction(ctx, js_config_toggle_color_grading, "toggleColorGrading", 0));
    JS_SetPropertyStr(ctx, config_obj, "setColorGradingParameters", JS_NewCFunction(ctx, js_config_set_color_grading_params, "setColorGradingParameters", 6));
    JS_SetPropertyStr(ctx, config_obj, "toggleFXAA", JS_NewCFunction(ctx, js_config_toggle_fxaa, "toggleFXAA", 0));
    JS_SetPropertyStr(ctx, config_obj, "setAmbientColor", JS_NewCFunction(ctx, js_config_set_ambient_color, "setAmbientColor", 3));
    JS_SetModuleExport(ctx, m, "Configuration", config_obj);

    // Pipeline
    JSValue pipeline_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, pipeline_obj, "toggleStage", JS_NewCFunction(ctx, js_pipeline_toggle_stage, "toggleStage", 2));
    JS_SetPropertyStr(ctx, pipeline_obj, "moveStage", JS_NewCFunction(ctx, js_pipeline_move_stage, "moveStage", 2));
    JS_SetPropertyStr(ctx, pipeline_obj, "removeStage", JS_NewCFunction(ctx, js_pipeline_remove_stage, "removeStage", 1));
    JS_SetModuleExport(ctx, m, "Pipeline", pipeline_obj);

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
        JS_AddModuleExport(ctx, m, "Particles");
        JS_AddModuleExport(ctx, m, "Debug");
        JS_AddModuleExport(ctx, m, "Configuration");
        JS_AddModuleExport(ctx, m, "Pipeline");

        return m;
    }

    int TachyonBridge_CallOnStart(JSContext *ctx, JSValue *module_ns)
    {
        JSValue fn = JS_GetPropertyStr(ctx, *module_ns, "onStart");
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

    int TachyonBridge_CallOnUpdate(JSContext *ctx, JSValue *module_ns, double dt)
    {
        JSValue fn = JS_GetPropertyStr(ctx, *module_ns, "onUpdate");
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

    int TachyonBridge_CallOnFixedUpdate(JSContext *ctx, JSValue *module_ns, double dt)
    {
        JSValue fn = JS_GetPropertyStr(ctx, *module_ns, "onFixedUpdate");
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