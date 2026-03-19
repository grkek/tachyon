module Tachyon
  module Audio
    class Engine
      Log = ::Log.for(self)

      MA_ENGINE_SIZE = 4096

      @engine_data : Bytes
      @initialized : Bool = false

      def initialize
        @engine_data = Bytes.new(MA_ENGINE_SIZE, 0_u8)
        result = LibMiniaudio.ma_engine_init(Pointer(Void).null, to_unsafe)
        if result == 0
          @initialized = true
          Log.debug { "Audio engine initialized" }
        else
          Log.debug { "Audio engine failed to initialize: #{result}" }
        end
      end

      def play(path : String)
        return unless @initialized
        LibMiniaudio.ma_engine_play_sound(to_unsafe, path.to_unsafe, Pointer(Void).null)
      end

      # Update listener position and orientation from camera
      def update_listener(position : Math::Vector3, direction : Math::Vector3, up : Math::Vector3 = Math::Vector3.up)
        return unless @initialized
        LibMiniaudio.ma_engine_listener_set_position(to_unsafe, 0_u32, position.x, position.y, position.z)
        LibMiniaudio.ma_engine_listener_set_direction(to_unsafe, 0_u32, direction.x, direction.y, direction.z)
        LibMiniaudio.ma_engine_listener_set_world_up(to_unsafe, 0_u32, up.x, up.y, up.z)
      end

      def destroy
        return unless @initialized
        LibMiniaudio.ma_engine_uninit(to_unsafe)
        @initialized = false
      end

      def to_unsafe : LibMiniaudio::MaEngine*
        @engine_data.to_unsafe.as(LibMiniaudio::MaEngine*)
      end
    end
  end
end
