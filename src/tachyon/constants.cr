module Tachyon
  module Constants
    # Full-screen quad vertices: position (xy) + texcoord (uv)
    QUAD_VERTICES = StaticArray[
      -1.0f32, -1.0f32, 0.0f32, 0.0f32,
      1.0f32, -1.0f32, 1.0f32, 0.0f32,
      1.0f32, 1.0f32, 1.0f32, 1.0f32,
      -1.0f32, -1.0f32, 0.0f32, 0.0f32,
      1.0f32, 1.0f32, 1.0f32, 1.0f32,
      -1.0f32, 1.0f32, 0.0f32, 1.0f32,
    ]
  end
end
