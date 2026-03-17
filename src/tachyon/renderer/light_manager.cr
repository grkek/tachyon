module Tachyon
  module Renderer
    class LightManager
      Log = ::Log.for(self)

      MAX_LIGHTS = 8

      @lights : Array(Light) = [] of Light

      def add(light : Light) : Int32
        return -1 if @lights.size >= MAX_LIGHTS
        @lights << light
        @lights.size - 1
      end

      def remove(index : Int32)
        @lights.delete_at(index) if index >= 0 && index < @lights.size
      end

      def get(index : Int32) : Light?
        @lights[index]? if index >= 0
      end

      def apply(shader : Shader)
        shader.set_int("uLightCount", @lights.size)
        @lights.each_with_index do |light, i|
          light.apply(shader, i)
        end
      end

      def directional : Light?
        @lights.find { |l| l.type == Light::Type::Directional }
      end

      def size : Int32
        @lights.size
      end

      def clear
        @lights.clear
      end
    end
  end
end
