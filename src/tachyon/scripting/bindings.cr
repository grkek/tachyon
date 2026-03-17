module Tachyon
  module Scripting
    alias QuickJS = Medusa::Binding::QuickJS

    enum CallbackSlot
      CreateCube = 0
      CreateSphere
      CreatePlane
      CreateCylinder
      SceneAdd
      SceneRemove
      SceneFind
      SceneClear
      NodeSetPosition
      NodeGetPosition
      NodeSetRotation
      NodeGetRotation
      NodeSetScale
      NodeGetScale
      NodeSetName
      NodeSetVisible
      NodeGetVisible
      NodeRotate
      NodeTranslate
      NodeLookAt
      NodeDestroy
      NodeSetMaterialColor
      NodeSetMaterialRoughness
      NodeSetMaterialMetallic
      NodeSetMaterialOpacity
      InputKeyDown
      InputKeyPressed
      InputKeyReleased
      InputMouseButtonDown
      InputMouseButtonPressed
      InputMousePosition
      InputMouseDelta
      InputLockCursor
      InputUnlockCursor
      CreateCone
      CreateTorus
      LoadMesh
      NodeSetWireframe
      GUIDrawRect
      GUIDrawText
      GUIClear
      CanvasSetup
      CanvasBackground
      CanvasText
      SpriteCreate
      SpriteLoad
      SpriteSetPosition
      SpriteGetPosition
      SpriteSetRotation
      SpriteSetScale
      SpriteSetColor
      SpriteSetVisible
      SpriteDestroy
      SpriteSetLayer
      CameraSetPosition
      CameraGetPosition
      CameraSetTarget
      CameraGetTarget
      CameraSetFOV
      CreatePointLight
      LightSetPosition
      LightSetColor
      LightSetIntensity
      LightSetRange
      AudioPlaySound
      AudioLoadSound
      AudioStopSound
      AudioSetVolume
      ScenePick
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
