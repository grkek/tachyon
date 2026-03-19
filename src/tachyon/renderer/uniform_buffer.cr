module Tachyon
  module Renderer
    # Manages a shared Uniform Buffer Object for per-frame data.
    # Packs camera, lights, fog, and shadow cascade data into a single GPU upload.
    class UniformBuffer
      Log = ::Log.for(self)

      BINDING_POINT = 0_u32
      MAX_LIGHTS    =     8
      MAX_CASCADES  =     4

      # std140 layout sizes (bytes):
      #   float  = 4, aligned to 4
      #   vec3   = 12, aligned to 16
      #   vec4   = 16, aligned to 16
      #   mat4   = 64, aligned to 16
      #   int    = 4, aligned to 4

      # Layout (std140):
      # ── Camera ──
      #   mat4 uView           (64)   offset 0
      #   mat4 uProjection     (64)   offset 64
      #   vec3 uViewPos        (16)   offset 128  (padded to vec4)
      #   vec3 uAmbientColor   (16)   offset 144  (padded to vec4)
      # ── Fog ──
      #   int  uFogEnabled     (4)    offset 160
      #   int  uFogMode        (4)    offset 164
      #   float uFogNear       (4)    offset 168
      #   float uFogFar        (4)    offset 172
      #   vec3 uFogColor       (16)   offset 176  (padded to vec4)
      #   float uFogDensity    (4)    offset 192
      #   pad                  (12)   offset 196
      # ── Shadows ──
      #   int  uHasShadowMap   (4)    offset 208
      #   int  uCascadeCount   (4)    offset 212
      #   pad                  (8)    offset 216
      #   mat4 uCascadeMatrix[4](256) offset 224
      #   vec4 uCascadeSplits  (16)   offset 480
      # ── Lights ──
      #   int  uLightCount     (4)    offset 496
      #   pad                  (12)   offset 500
      #   Light[8]                    offset 512
      #     per light (std140):
      #       int type         (4)    +0
      #       float intensity  (4)    +4
      #       float range      (4)    +8
      #       float innerCutoff(4)    +12
      #       vec4 color       (16)   +16  (vec3 padded)
      #       vec4 position    (16)   +32  (vec3 padded)
      #       vec4 direction   (16)   +48  (vec3 padded)
      #       float outerCutoff(4)    +64
      #       pad              (12)   +68
      #     = 80 bytes per light
      #   Total lights: 80 * 8 = 640
      # Total buffer size: 512 + 640 = 1152

      BUFFER_SIZE = 1152

      # Offsets
      OFF_VIEW           =   0
      OFF_PROJECTION     =  64
      OFF_VIEW_POS       = 128
      OFF_AMBIENT_COLOR  = 144
      OFF_FOG_ENABLED    = 160
      OFF_FOG_MODE       = 164
      OFF_FOG_NEAR       = 168
      OFF_FOG_FAR        = 172
      OFF_FOG_COLOR      = 176
      OFF_FOG_DENSITY    = 192
      OFF_HAS_SHADOW_MAP = 208
      OFF_CASCADE_COUNT  = 212
      OFF_CASCADE_MATRIX = 224
      OFF_CASCADE_SPLITS = 480
      OFF_LIGHT_COUNT    = 496
      OFF_LIGHTS         = 512
      LIGHT_STRIDE       =  80

      @ubo : LibGL::GLuint = 0_u32
      @buffer : Pointer(UInt8)

      def initialize
        @buffer = Pointer(UInt8).malloc(BUFFER_SIZE)
        @buffer.clear(BUFFER_SIZE)

        LibGL.glGenBuffers(1, pointerof(@ubo))
        LibGL.glBindBuffer(LibGL::GL_UNIFORM_BUFFER, @ubo)
        LibGL.glBufferData(LibGL::GL_UNIFORM_BUFFER, BUFFER_SIZE.to_i64, Pointer(Void).null, LibGL::GL_DYNAMIC_DRAW)
        LibGL.glBindBuffer(LibGL::GL_UNIFORM_BUFFER, 0)

        LibGL.glBindBufferBase(LibGL::GL_UNIFORM_BUFFER, BINDING_POINT, @ubo)
      end

      # Bind this UBO's block in a shader program
      def bind_to_shader(shader : Shader)
        index = LibGL.glGetUniformBlockIndex(shader.program, "FrameData")
        if index != 0xFFFFFFFF_u32 # GL_INVALID_INDEX
          LibGL.glUniformBlockBinding(shader.program, index, BINDING_POINT)
        end
      end

      # Pack all per-frame data and upload once
      def update(context : Rendering::Context, frame : Rendering::Frame)
        camera = context.camera
        config = Configuration.instance

        # Camera
        write_mat4(OFF_VIEW, camera.view_matrix)
        write_mat4(OFF_PROJECTION, camera.projection_matrix)
        write_vec3(OFF_VIEW_POS, camera.position)
        write_vec3(OFF_AMBIENT_COLOR, config.ambient.color)

        # Fog
        write_int(OFF_FOG_ENABLED, config.fog.enabled ? 1 : 0)
        write_int(OFF_FOG_MODE, config.fog.mode)
        write_float(OFF_FOG_NEAR, config.fog.near)
        write_float(OFF_FOG_FAR, config.fog.far)
        write_vec3(OFF_FOG_COLOR, config.fog.color)
        write_float(OFF_FOG_DENSITY, config.fog.density)

        # Shadows
        write_int(OFF_HAS_SHADOW_MAP, frame.cascade_count > 0 || frame.shadow_depth_texture != 0 ? 1 : 0)
        write_int(OFF_CASCADE_COUNT, frame.cascade_count)

        frame.cascade_count.times do |i|
          write_mat4(OFF_CASCADE_MATRIX + i * 64, frame.cascade_matrices[i])
        end

        # Pack splits as a vec4
        write_float(OFF_CASCADE_SPLITS, frame.cascade_splits[0])
        write_float(OFF_CASCADE_SPLITS + 4, frame.cascade_splits[1])
        write_float(OFF_CASCADE_SPLITS + 8, frame.cascade_splits[2])
        write_float(OFF_CASCADE_SPLITS + 12, frame.cascade_splits[3])

        # Lights
        lights = context.light_manager
        write_int(OFF_LIGHT_COUNT, lights.size)
        lights.size.times do |i|
          light = lights.get(i)
          next unless light
          base = OFF_LIGHTS + i * LIGHT_STRIDE
          write_int(base, light.type.value)
          write_float(base + 4, light.intensity)
          write_float(base + 8, light.range)
          write_float(base + 12, light.inner_cutoff)
          write_vec3(base + 16, light.color)
          write_vec3(base + 32, light.position)
          write_vec3(base + 48, light.direction)
          write_float(base + 64, light.outer_cutoff)
        end

        # Single upload
        LibGL.glBindBuffer(LibGL::GL_UNIFORM_BUFFER, @ubo)
        LibGL.glBufferSubData(LibGL::GL_UNIFORM_BUFFER, 0_i64, BUFFER_SIZE.to_i64, @buffer.as(Pointer(Void)))
        LibGL.glBindBuffer(LibGL::GL_UNIFORM_BUFFER, 0)
      end

      def destroy
        LibGL.glDeleteBuffers(1, pointerof(@ubo)) if @ubo != 0
        @ubo = 0_u32
      end

      private def write_mat4(offset : Int32, mat : Math::Matrix4)
        ptr = (@buffer + offset).as(Pointer(Float32))
        mat.to_unsafe.copy_to(ptr, 16)
      end

      private def write_vec3(offset : Int32, vec : Math::Vector3)
        ptr = (@buffer + offset).as(Pointer(Float32))
        ptr[0] = vec.x
        ptr[1] = vec.y
        ptr[2] = vec.z
        ptr[3] = 0.0f32 # std140 padding
      end

      private def write_float(offset : Int32, value : Float32)
        (@buffer + offset).as(Pointer(Float32)).value = value
      end

      private def write_int(offset : Int32, value : Int32)
        (@buffer + offset).as(Pointer(Int32)).value = value
      end
    end
  end
end
