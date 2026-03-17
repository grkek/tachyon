module Tachyon
  module Renderer
    class Light
      Log = ::Log.for(self)

      enum Type
        Directional
        Point
        Spot
      end

      property type : Type
      property position : Math::Vector3
      property direction : Math::Vector3
      property color : Math::Vector3
      property intensity : Float32
      property range : Float32        # For point/spot
      property inner_cutoff : Float32 # For spot (cosine)
      property outer_cutoff : Float32 # For spot (cosine)

      def initialize(@type : Type = Type::Directional,
                     @position : Math::Vector3 = Math::Vector3.zero,
                     @direction : Math::Vector3 = Math::Vector3.new(0.0f32, -1.0f32, 0.0f32),
                     @color : Math::Vector3 = Math::Vector3.new(1.0f32, 1.0f32, 1.0f32),
                     @intensity : Float32 = 1.0f32,
                     @range : Float32 = 10.0f32,
                     @inner_cutoff : Float32 = 0.9763f32, # cos(12.5 degrees)
                     @outer_cutoff : Float32 = 0.9659f32) # cos(15 degrees)
      end

      def apply(shader : Shader, index : Int32)
        prefix = "uLights[#{index}]"
        shader.set_int("#{prefix}.type", @type.value)
        shader.set_vector3("#{prefix}.color", @color)
        shader.set_float("#{prefix}.intensity", @intensity)
        shader.set_vector3("#{prefix}.position", @position)
        shader.set_vector3("#{prefix}.direction", @direction)
        shader.set_float("#{prefix}.range", @range)
        shader.set_float("#{prefix}.innerCutoff", @inner_cutoff)
        shader.set_float("#{prefix}.outerCutoff", @outer_cutoff)
      end

      def shadow_view_projection(focus : Math::Vector3 = Math::Vector3.zero, radius : Float32 = 50.0f32) : Math::Matrix4
        light_proj = Math::Matrix4.orthographic(-radius, radius, -radius, radius, 0.1f32, radius * 4.0f32)
        light_pos = focus + (@direction * -radius * 2.0f32)
        light_view = Math::Matrix4.look_at(light_pos, focus, Math::Vector3.new(0.0f32, 1.0f32, 0.0f32))
        light_proj * light_view
      end
    end
  end
end
