module Tachyon
  module Scripting
    module GraphicalUserInterface
      class DrawCall
        property command : Command = Command::Rect

        # Geometry
        property x : Float32 = 0.0f32
        property y : Float32 = 0.0f32
        property w : Float32 = 0.0f32
        property h : Float32 = 0.0f32

        # Primary color
        property r : Float32 = 1.0f32
        property g : Float32 = 1.0f32
        property b : Float32 = 1.0f32
        property a : Float32 = 1.0f32

        # Secondary color (bevel light edge, header fill, progress fill)
        property r2 : Float32 = 0.0f32
        property g2 : Float32 = 0.0f32
        property b2 : Float32 = 0.0f32
        property a2 : Float32 = 1.0f32

        # Tertiary color (bevel dark edge, label color)
        property r3 : Float32 = 0.0f32
        property g3 : Float32 = 0.0f32
        property b3 : Float32 = 0.0f32
        property a3 : Float32 = 1.0f32

        # Text content
        property text : String = ""
        property scale : Float32 = 1.0f32
        property font_id : Int32 = 0

        # State flags (bitfield)
        # Bit 0: active/pressed
        # Bit 1: hovered
        # Bit 2: disabled
        # Bit 3: checked
        # Bit 4: vertical orientation
        # Bit 5: has header
        property state : Int32 = 0

        # Normalized value (slider position, progress, scroll offset)
        property value : Float32 = 0.0f32

        def active? : Bool
          (state & 0x01) != 0
        end

        def hovered? : Bool
          (state & 0x02) != 0
        end

        def disabled? : Bool
          (state & 0x04) != 0
        end

        def checked? : Bool
          (state & 0x08) != 0
        end

        def vertical? : Bool
          (state & 0x10) != 0
        end

        def has_header? : Bool
          (state & 0x20) != 0
        end
      end
    end
  end
end
