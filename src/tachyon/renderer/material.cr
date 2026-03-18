module Tachyon
  module Renderer
    class Material
      Log = ::Log.for(self)

      # PBR metallic-roughness parameters
      property albedo : Math::Vector3   # Base color
      property metallic : Float32       # 0.0 = dielectric, 1.0 = metal
      property roughness : Float32      # 0.0 = mirror, 1.0 = matte
      property ao : Float32             # Ambient occlusion multiplier
      property emissive : Math::Vector3 # Self-illumination color
      property emissive_strength : Float32
      property opacity : Float32
      property wireframe : Bool = false

      # Texture maps (nil = use uniform value)
      property albedo_map : Texture? = nil
      property normal_map : Texture? = nil
      property metallic_roughness_map : Texture? = nil # R=metallic, G=roughness (glTF convention)
      property ao_map : Texture? = nil
      property emissive_map : Texture? = nil
      property texture_scale_x : Float32 = 1.0f32
      property texture_scale_y : Float32 = 1.0f32

      def initialize(
        @albedo : Math::Vector3 = Math::Vector3.new(0.8f32, 0.8f32, 0.8f32),
        @metallic : Float32 = 0.0f32,
        @roughness : Float32 = 0.5f32,
        @ao : Float32 = 1.0f32,
        @emissive : Math::Vector3 = Math::Vector3.zero,
        @emissive_strength : Float32 = 0.0f32,
        @opacity : Float32 = 1.0f32,
      )
      end

      # Backwards compatibility: color maps to albedo
      def color : Math::Vector3
        @albedo
      end

      def color=(c : Math::Vector3)
        @albedo = c
      end

      def apply(shader : Shader)
        shader.set_vector3("uMaterial.albedo", @albedo)
        shader.set_float("uMaterial.metallic", @metallic)
        shader.set_float("uMaterial.roughness", @roughness)
        shader.set_float("uMaterial.ao", @ao)
        shader.set_vector3("uMaterial.emissive", @emissive)
        shader.set_float("uMaterial.emissiveStrength", @emissive_strength)
        shader.set_float("uMaterial.opacity", @opacity)

        shader.set_vector2("uTextureScale", @texture_scale_x, @texture_scale_y)

        # Bind textures
        has_albedo_map = @albedo_map ? 1 : 0
        has_normal_map = @normal_map ? 1 : 0
        has_mr_map = @metallic_roughness_map ? 1 : 0
        has_ao_map = @ao_map ? 1 : 0
        has_emissive_map = @emissive_map ? 1 : 0

        shader.set_int("uMaterial.hasAlbedoMap", has_albedo_map)
        shader.set_int("uMaterial.hasNormalMap", has_normal_map)
        shader.set_int("uMaterial.hasMetallicRoughnessMap", has_mr_map)
        shader.set_int("uMaterial.hasAoMap", has_ao_map)
        shader.set_int("uMaterial.hasEmissiveMap", has_emissive_map)

        @albedo_map.try(&.bind(0))
        shader.set_int("uAlbedoMap", 0)

        @normal_map.try(&.bind(1))
        shader.set_int("uNormalMap", 1)

        @metallic_roughness_map.try(&.bind(2))
        shader.set_int("uMetallicRoughnessMap", 2)

        @ao_map.try(&.bind(3))
        shader.set_int("uAoMap", 3)

        @emissive_map.try(&.bind(4))
        shader.set_int("uEmissiveMap", 4)
      end
    end
  end
end
