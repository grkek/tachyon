module Tachyon
  module Scripting
    alias QuickJS = Medusa::Binding::QuickJS

    # Numeric slots for the C callback bridge, one per JS-callable function
    enum CallbackSlot
      CreateCube                      = 0
      CreateSphere
      CreatePlane
      CreateCylinder
      SceneAdd
      SceneRemove
      SceneFind
      SceneClear
      ScenePick
      SceneSave
      SceneLoadFile
      SceneLoadEnvironment
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
      AudioSetLooping
      AudioSetSpatial
      AudioSetSoundPosition
      AudioSetMinDistance
      AudioSetMaxDistance
      AudioSetRolloff
      AudioSetPitch
      AudioStartSound
      NodeLoadTexture
      NodeSetTextureScale
      NodeSetMaterialEmissive
      NodeSetMaterialEmissiveStrength
      SpriteSetAtlas
      SpritePlayAnimation
      SpriteStopAnimation
      SpriteSetFrame
      ParticleCreateEmitter
      ParticleDestroyEmitter
      ParticleSetPosition
      ParticleSetDirection
      ParticleSetColors
      ParticleSetSizes
      ParticleSetSpeed
      ParticleSetLifetime
      ParticleSetGravity
      ParticleSetRate
      ParticleSetSpread
      ParticleSetActive
      ParticleSetBlendAdditive
      ParticleEmitBurst
      ParticleLoadTexture
      ToggleFog
      SetFogParameters
      ToggleBloom
      SetBloomParameters
      ToggleSSAO
      SetSSAOParameters
      ToggleShadow
      SetShadowResolution
      ToggleSkybox
      SetSkyboxTopColor
      SetSkyboxBottomColor
      ToggleVignette
      SetVignetteParameters
      ToggleChromaticAberration
      SetChromaticAberrationStrength
      ToggleColorGrading
      SetColorGradingParameters
      ToggleFXAA
      SetAmbientColor
      PipelineToggleStage
      PipelineMoveStage
      PipelineRemoveStage
    end

    @[Link(ldflags: "#{__DIR__}/../../../bin/tachyon_bridge.a")]
    lib LibTachyonBridge
      fun TachyonBridge_SetCallback(slot : LibC::Int, pointer : Void*, closure_data : Void*) : Void
      fun TachyonBridge_InitClasses(rt : QuickJS::JSRuntime) : Void
      fun TachyonBridge_RegisterModule(ctx : QuickJS::JSContext) : QuickJS::JSModuleDef
      fun TachyonBridge_CallOnStart(ctx : QuickJS::JSContext, module_ns : Pointer(QuickJS::JSValue)) : LibC::Int
      fun TachyonBridge_CallOnUpdate(ctx : QuickJS::JSContext, module_ns : Pointer(QuickJS::JSValue), dt : Float64) : LibC::Int
      fun TachyonBridge_CallOnFixedUpdate(ctx : QuickJS::JSContext, module_ns : Pointer(QuickJS::JSValue), dt : Float64) : LibC::Int
      fun TachyonBridge_GetModuleNamespace(ctx : QuickJS::JSContext, m : QuickJS::JSModuleDef) : QuickJS::JSValue
    end
  end
end
