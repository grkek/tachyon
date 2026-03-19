module Tachyon
  module Audio
    class Sound
      Log = ::Log.for(self)

      MA_SOUND_SIZE = 4096

      @sound_data : Bytes
      @engine : Engine
      @initialized : Bool = false

      def initialize(@engine : Engine, path : String, looping : Bool = false)
        @sound_data = Bytes.new(MA_SOUND_SIZE, 0_u8)
        result = LibMiniaudio.ma_sound_init_from_file(
          @engine.to_unsafe, path.to_unsafe, 0_u32,
          Pointer(Void).null, Pointer(Void).null, sound_ptr
        )
        if result == 0
          @initialized = true
          LibMiniaudio.ma_sound_set_looping(sound_ptr, looping ? 1 : 0)
        end
      end

      def play
        return unless @initialized
        LibMiniaudio.ma_sound_start(sound_ptr)
      end

      def stop
        return unless @initialized
        LibMiniaudio.ma_sound_stop(sound_ptr)
      end

      def volume=(v : Float32)
        return unless @initialized
        LibMiniaudio.ma_sound_set_volume(sound_ptr, v)
      end

      def playing? : Bool
        return false unless @initialized
        LibMiniaudio.ma_sound_is_playing(sound_ptr) != 0
      end

      def position=(pos : Math::Vector3)
        return unless @initialized
        LibMiniaudio.ma_sound_set_position(sound_ptr, pos.x, pos.y, pos.z)
      end

      def looping=(value : Bool)
        return unless @initialized
        LibMiniaudio.ma_sound_set_looping(sound_ptr, value ? 1 : 0)
      end

      def spatial=(enabled : Bool)
        return unless @initialized
        LibMiniaudio.ma_sound_set_spatialization_enabled(sound_ptr, enabled ? 1_u32 : 0_u32)
      end

      def min_distance=(distance : Float32)
        return unless @initialized
        LibMiniaudio.ma_sound_set_min_distance(sound_ptr, distance)
      end

      def max_distance=(distance : Float32)
        return unless @initialized
        LibMiniaudio.ma_sound_set_max_distance(sound_ptr, distance)
      end

      def rolloff=(value : Float32)
        return unless @initialized
        LibMiniaudio.ma_sound_set_rolloff(sound_ptr, value)
      end

      def pitch=(value : Float32)
        return unless @initialized
        LibMiniaudio.ma_sound_set_pitch(sound_ptr, value)
      end

      def destroy
        return unless @initialized
        LibMiniaudio.ma_sound_uninit(sound_ptr)
        @initialized = false
      end

      private def sound_ptr : LibMiniaudio::MaSound*
        @sound_data.to_unsafe.as(LibMiniaudio::MaSound*)
      end
    end
  end
end
