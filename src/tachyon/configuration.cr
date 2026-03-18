module Tachyon
  # Global engine configuration singleton, readable/writable from Crystal and JS
  class Configuration
    INSTANCE = new

    def self.instance
      INSTANCE
    end

    # Distance fog settings
    class Fog
      property enabled : Bool = false
      property color : Math::Vector3 = Math::Vector3.new(0.7f32, 0.7f32, 0.7f32)
      property near : Float32 = 10.0f32
      property far : Float32 = 100.0f32
      property density : Float32 = 0.01f32
      property mode : Int32 = 0
    end

    # HDR bloom / glow settings
    class Bloom
      property enabled : Bool = true
      property threshold : Float32 = 0.6f32
      property intensity : Float32 = 0.4f32
    end

    # Screen-space ambient occlusion settings
    class SSAO
      property enabled : Bool = true
      property radius : Float32 = 0.5f32
      property bias : Float32 = 0.025f32
    end

    # Shadow map settings
    class Shadow
      property enabled : Bool = true
      property resolution : Int32 = 4096
    end

    # Procedural skybox settings
    class Skybox
      property enabled : Bool = true
      property top_color : Math::Vector3 = Math::Vector3.new(0.18f32, 0.28f32, 0.58f32)
      property bottom_color : Math::Vector3 = Math::Vector3.new(0.82f32, 0.45f32, 0.22f32)
    end

    # Default camera parameters
    class Camera
      property field_of_view : Float32 = 60.0f32
      property near_plane : Float32 = 0.1f32
      property far_plane : Float32 = 100.0f32
      property default_camera_position : Math::Vector3 = Math::Vector3.new(0.0f32, 3.0f32, 6.0f32)
      property default_camera_target : Math::Vector3 = Math::Vector3.new(0.0f32, 0.5f32, 0.0f32)
    end

    # Ambient light color
    class Ambient
      property color : Math::Vector3 = Math::Vector3.new(0.2f32, 0.2f32, 0.22f32)
    end

    # Default directional light
    class Light
      property direction : Math::Vector3 = Math::Vector3.new(0.5f32, -1.0f32, -0.5f32)
      property color : Math::Vector3 = Math::Vector3.new(1.0f32, 0.95f32, 0.9f32)
      property intensity : Float32 = 2.0f32
    end

    # Particle system toggle
    class Particle
      property enabled : Bool = true
    end

    # Fixed timestep for physics
    class Timing
      property fixed : Float64 = 1.0 / 60.0
    end

    # Vignette post-process effect
    class Vignette
      property enabled : Bool = false
      property intensity : Float32 = 0.4f32
      property smoothness : Float32 = 0.5f32
    end

    # Chromatic aberration post-process effect
    class ChromaticAberration
      property enabled : Bool = false
      property strength : Float32 = 0.003f32
    end

    # Color grading / tone adjustment
    class ColorGrading
      property enabled : Bool = false
      property exposure : Float32 = 1.0f32
      property contrast : Float32 = 1.0f32
      property saturation : Float32 = 1.0f32
      property tint : Math::Vector3 = Math::Vector3.new(1.0f32, 1.0f32, 1.0f32)
    end

    # FXAA toggle
    class FXAA
      property enabled : Bool = true
    end

    property fog : Fog = Fog.new
    property bloom : Bloom = Bloom.new
    property ssao : SSAO = SSAO.new
    property shadow : Shadow = Shadow.new
    property skybox : Skybox = Skybox.new
    property camera : Camera = Camera.new
    property ambient : Ambient = Ambient.new
    property light : Light = Light.new
    property particle : Particle = Particle.new
    property timing : Timing = Timing.new
    property vignette : Vignette = Vignette.new
    property chromatic_aberration : ChromaticAberration = ChromaticAberration.new
    property color_grading : ColorGrading = ColorGrading.new
    property fxaa : FXAA = FXAA.new
  end
end
