@[Link(ldflags: "#{__DIR__}/../../../bin/miniaudio_impl.o")]
lib LibMiniaudio
  type MaEngine = Void
  type MaSound = Void

  fun ma_engine_init(config : Void*, engine : MaEngine*) : Int32
  fun ma_engine_uninit(engine : MaEngine*) : Void
  fun ma_engine_play_sound(engine : MaEngine*, path : LibC::Char*, group : Void*) : Int32
  fun ma_sound_init_from_file(engine : MaEngine*, path : LibC::Char*, flags : UInt32, group : Void*, fence : Void*, sound : MaSound*) : Int32
  fun ma_sound_start(sound : MaSound*) : Int32
  fun ma_sound_stop(sound : MaSound*) : Int32
  fun ma_sound_set_volume(sound : MaSound*, volume : Float32) : Void
  fun ma_sound_set_looping(sound : MaSound*, looping : Int32) : Void
  fun ma_sound_set_position(sound : MaSound*, x : Float32, y : Float32, z : Float32) : Void
  fun ma_sound_uninit(sound : MaSound*) : Void
  fun ma_sound_is_playing(sound : MaSound*) : Int32
end
