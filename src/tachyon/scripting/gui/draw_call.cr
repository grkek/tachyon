module Tachyon
  module Scripting
    module GUI
      struct DrawCall
        property command : Command = Command::Rect
        property text : String = ""
        property x : Float32 = 0.0f32
        property y : Float32 = 0.0f32
        property w : Float32 = 0.0f32
        property h : Float32 = 0.0f32
        property r : Float32 = 1.0f32
        property g : Float32 = 1.0f32
        property b : Float32 = 1.0f32
        property a : Float32 = 1.0f32
        property scale : Float32 = 2.0f32
      end
    end
  end
end
