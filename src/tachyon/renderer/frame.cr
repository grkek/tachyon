module Tachyon
  module Rendering
    # Per-frame data token passed through the pipeline stage by stage.
    # Each stage reads what it needs, writes its outputs, and passes it along.
    class Frame
      # Active framebuffer — stages render into this
      property buffer : LibGL::GLuint = 0_u32
      # Color texture attached to the active framebuffer
      property color_texture : LibGL::GLuint = 0_u32

      # Alternate framebuffer — post-process stages swap between buffer and alt
      property alt_buffer : LibGL::GLuint = 0_u32
      # Color texture attached to the alternate framebuffer
      property alt_texture : LibGL::GLuint = 0_u32

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

      # Cascaded shadow maps
      property cascade_count : Int32 = 0
      property cascade_textures : StaticArray(LibGL::GLuint, 4) = StaticArray(LibGL::GLuint, 4).new(0_u32)
      property cascade_matrices : Array(Math::Matrix4) = [] of Math::Matrix4
      property cascade_splits : StaticArray(Float32, 4) = StaticArray(Float32, 4).new(0.0f32)

      # Signal that a stage consumed the frame (e.g. 2D canvas takes over)
      property consumed : Bool = false

      def initialize(@buffer, @width, @height, @delta_time)
      end

      # Swap active and alternate FBOs — call before a post-process pass.
      # After swap: buffer is the write target, alt_texture is the read source.
      def swap!
        @buffer, @alt_buffer = @alt_buffer, @buffer
        @color_texture, @alt_texture = @alt_texture, @color_texture
      end
    end
  end
end
