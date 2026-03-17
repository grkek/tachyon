module Tachyon
  module Renderer
    class Sprite
      Log = ::Log.for(self)

      property x : Float32 = 0.0f32
      property y : Float32 = 0.0f32
      property width : Float32 = 32.0f32
      property height : Float32 = 32.0f32
      property rotation : Float32 = 0.0f32
      property scale_x : Float32 = 1.0f32
      property scale_y : Float32 = 1.0f32
      property r : Float32 = 1.0f32
      property g : Float32 = 1.0f32
      property b : Float32 = 1.0f32
      property a : Float32 = 1.0f32
      property visible : Bool = true
      property layer : Int32 = 0
      property texture : Texture? = nil

      def initialize(@width : Float32 = 32.0f32, @height : Float32 = 32.0f32)
      end

      def self.from_texture(path : String) : Sprite
        tex = Texture.load(path, srgb: true)
        sprite = Sprite.new(tex.width.to_f32, tex.height.to_f32)
        sprite.texture = tex
        sprite
      end
    end
  end
end
