module Tachyon
  module Scripting
    alias QuickJS = Medusa::Binding::QuickJS

    enum CallbackSlot
      CreateCube               =  0
      CreateSphere             =  1
      CreatePlane              =  2
      CreateCylinder           =  3
      SceneAdd                 =  4
      SceneRemove              =  5
      SceneFind                =  6
      SceneClear               =  7
      NodeSetPosition          =  8
      NodeGetPosition          =  9
      NodeSetRotation          = 10
      NodeGetRotation          = 11
      NodeSetScale             = 12
      NodeGetScale             = 13
      NodeSetName              = 14
      NodeSetVisible           = 15
      NodeGetVisible           = 16
      NodeRotate               = 17
      NodeTranslate            = 18
      NodeLookAt               = 19
      NodeDestroy              = 20
      NodeSetMaterialColor     = 21
      NodeSetMaterialRoughness = 22
      NodeSetMaterialMetallic  = 23
      NodeSetMaterialOpacity   = 24
      InputKeyDown             = 25
      InputKeyPressed          = 26
      InputKeyReleased         = 27
      InputMouseButtonDown     = 28
      InputMouseButtonPressed  = 29
      InputMousePosition       = 30
      InputMouseDelta          = 31
      CreateCone               = 32
      CreateTorus              = 33
      LoadMesh                 = 34
      NodeSetWireframe         = 35
      GUIDrawRect              = 36
      GUIDrawText              = 37
      GUIClear                 = 38
      CanvasSetup              = 39
      CanvasBackground         = 40
      CanvasText               = 41
      SpriteCreate             = 42
      SpriteLoad               = 43
      SpriteSetPosition        = 44
      SpriteGetPosition        = 45
      SpriteSetRotation        = 46
      SpriteSetScale           = 47
      SpriteSetColor           = 48
      SpriteSetVisible         = 49
      SpriteDestroy            = 50
      SpriteSetLayer           = 51
      CameraSetPosition        = 52
      CameraGetPosition        = 53
      CameraSetTarget          = 54
      CameraGetTarget          = 55
      CameraSetFOV             = 56
      CreatePointLight         = 57
      LightSetPosition         = 58
      LightSetColor            = 59
      LightSetIntensity        = 60
      LightSetRange            = 61
      AudioPlaySound           = 62
      AudioLoadSound           = 63
      AudioStopSound           = 64
      AudioSetVolume           = 65
      ScenePick                = 66
    end

    @[Link(ldflags: "#{__DIR__}/../../../bin/tachyon_bridge.a")]
    lib LibTachyonBridge
      fun TachyonBridge_SetCallback(slot : LibC::Int, pointer : Void*, closure_data : Void*) : Void
      fun TachyonBridge_InitClasses(rt : QuickJS::JSRuntime) : Void
      fun TachyonBridge_RegisterModule(ctx : QuickJS::JSContext) : QuickJS::JSModuleDef
      fun TachyonBridge_CallOnStart(ctx : QuickJS::JSContext, module_ns : QuickJS::JSValue) : LibC::Int
      fun TachyonBridge_CallOnUpdate(ctx : QuickJS::JSContext, module_ns : QuickJS::JSValue, dt : Float64) : LibC::Int
      fun TachyonBridge_CallOnFixedUpdate(ctx : QuickJS::JSContext, module_ns : QuickJS::JSValue, dt : Float64) : LibC::Int
      fun TachyonBridge_GetModuleNamespace(ctx : QuickJS::JSContext, m : QuickJS::JSModuleDef) : QuickJS::JSValue
    end
  end
end
