module Tachyon
  module Audio
    class Engine
      Log = ::Log.for(self)

      MA_ENGINE_SIZE = 4096 # Generous allocation for ma_engine struct

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
