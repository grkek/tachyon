module Tachyon
  module Math
    DEG2RAD = ::Math::PI.to_f32 / 180.0f32
    RAD2DEG = 180.0f32 / ::Math::PI.to_f32

    def self.to_radians(degrees : Float32) : Float32
      degrees * DEG2RAD
    end

    def self.to_degrees(radians : Float32) : Float32
      radians * RAD2DEG
    end

    def self.to_radians(degrees : Float64) : Float32
      (degrees * DEG2RAD).to_f32
    end
  end
end
