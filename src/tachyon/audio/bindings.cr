@[Link(ldflags: "#{__DIR__}/../../../bin/miniaudio_impl.o")]
lib LibMiniaudio
  type MaEngine = Void
  type MaSound = Void

  fun ma_engine_init(config : Void*, engine : MaEngine*) : Int32
  fun ma_engine_uninit(engine : MaEngine*) : Void
  fun ma_engine_play_sound(engine : MaEngine*, path : LibC::Char*, group : Void*) : Int32

  # Listener (tied to camera)
  fun ma_engine_listener_set_position(engine : MaEngine*, listenerIndex : UInt32, x : Float32, y : Float32, z : Float32) : Void
  fun ma_engine_listener_set_direction(engine : MaEngine*, listenerIndex : UInt32, x : Float32, y : Float32, z : Float32) : Void
  fun ma_engine_listener_set_world_up(engine : MaEngine*, listenerIndex : UInt32, x : Float32, y : Float32, z : Float32) : Void

  # Sound
  fun ma_sound_init_from_file(engine : MaEngine*, path : LibC::Char*, flags : UInt32, group : Void*, fence : Void*, sound : MaSound*) : Int32
  fun ma_sound_start(sound : MaSound*) : Int32
  fun ma_sound_stop(sound : MaSound*) : Int32
  fun ma_sound_set_volume(sound : MaSound*, volume : Float32) : Void
  fun ma_sound_set_looping(sound : MaSound*, looping : Int32) : Void
  fun ma_sound_set_position(sound : MaSound*, x : Float32, y : Float32, z : Float32) : Void
  fun ma_sound_set_spatialization_enabled(sound : MaSound*, enabled : UInt32) : Void
  fun ma_sound_set_min_distance(sound : MaSound*, distance : Float32) : Void
  fun ma_sound_set_max_distance(sound : MaSound*, distance : Float32) : Void
  fun ma_sound_set_rolloff(sound : MaSound*, rolloff : Float32) : Void
  fun ma_sound_set_pitch(sound : MaSound*, pitch : Float32) : Void
  fun ma_sound_uninit(sound : MaSound*) : Void
  fun ma_sound_is_playing(sound : MaSound*) : Int32
end
