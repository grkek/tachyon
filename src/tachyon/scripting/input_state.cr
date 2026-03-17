module Tachyon
  module Scripting
    class InputState
      Log = ::Log.for(self)

      @keys_down : Set(String) = Set(String).new
      @keys_pressed : Set(String) = Set(String).new
      @keys_released : Set(String) = Set(String).new
      @mouse_buttons_down : Set(Int32) = Set(Int32).new
      @mouse_buttons_pressed : Set(Int32) = Set(Int32).new
      @mouse_x : Float32 = 0.0f32
      @mouse_y : Float32 = 0.0f32
      @mouse_dx : Float32 = 0.0f32
      @mouse_dy : Float32 = 0.0f32

      def begin_frame
        @keys_pressed.clear
        @keys_released.clear
        @mouse_buttons_pressed.clear
        @mouse_dx = 0.0f32
        @mouse_dy = 0.0f32
      end

      def on_key_press(key : String)
        normalized = normalize_key(key)
        unless @keys_down.includes?(normalized)
          @keys_pressed.add(normalized)
        end
        @keys_down.add(normalized)
      end

      def on_key_release(key : String)
        normalized = normalize_key(key)
        @keys_down.delete(normalized)
        @keys_released.add(normalized)
      end

      def on_mouse_button_press(button : Int32)
        @mouse_buttons_down.add(button)
        @mouse_buttons_pressed.add(button)
      end

      def on_mouse_button_release(button : Int32)
        @mouse_buttons_down.delete(button)
      end

      def on_mouse_move(x : Float32, y : Float32)
        @mouse_dx += x - @mouse_x
        @mouse_dy += y - @mouse_y
        @mouse_x = x
        @mouse_y = y
      end

      def reset_mouse_position(x : Float32, y : Float32)
        @mouse_x = x
        @mouse_y = y
      end

      def key_down?(key : String) : Bool
        @keys_down.includes?(key)
      end

      def key_pressed?(key : String) : Bool
        @keys_pressed.includes?(key)
      end

      def key_released?(key : String) : Bool
        @keys_released.includes?(key)
      end

      def mouse_button_down?(button : Int32) : Bool
        @mouse_buttons_down.includes?(button)
      end

      def mouse_button_pressed?(button : Int32) : Bool
        @mouse_buttons_pressed.includes?(button)
      end

      def mouse_position : {Float32, Float32}
        {@mouse_x, @mouse_y}
      end

      def mouse_delta : {Float32, Float32}
        {@mouse_dx, @mouse_dy}
      end

      private def normalize_key(key : String) : String
        if key.size == 1
          key.upcase
        elsif key.size > 1
          key[0].upcase.to_s + key[1..]
        else
          key
        end
      end
    end
  end
end
