module Tachyon
  module Rendering
    # Per-frame data token passed through the pipeline stage by stage.
    # Each stage reads what it needs, writes its outputs, and passes it along.
    class Frame
      # Active framebuffer - stages bind or replace this
      property buffer : LibGL::GLuint = 0_u32

      # Viewport dimensions for this frame
      property width : Int32 = 800
      property height : Int32 = 600
      property delta_time : Float32 = 0.0f32

      # Texture outputs written by upstream stages, consumed downstream
      property shadow_depth_texture : LibGL::GLuint = 0_u32
      property ssao_texture : LibGL::GLuint = 0_u32
      property scene_color_texture : LibGL::GLuint = 0_u32
      property depth_texture : LibGL::GLuint = 0_u32

      # Shadow pass writes this, geometry pass reads it
      property light_space_matrix : Math::Matrix4 = Math::Matrix4.identity

      # Signal that a stage consumed the frame (e.g. 2D canvas takes over)
      property consumed : Bool = false

      def initialize(@buffer, @width, @height, @delta_time)
      end
    end
  end
end
