module Tachyon
  module Renderer
    module Stages
      class Shadow < Base
        Log = ::Log.for(self)

        CASCADE_COUNT  = 4
        SPLIT_LAMBDA   = 0.65f32

        @frame_buffers  : StaticArray(LibGL::GLuint, 4) = StaticArray(LibGL::GLuint, 4).new(0_u32)
        @depth_textures : StaticArray(LibGL::GLuint, 4) = StaticArray(LibGL::GLuint, 4).new(0_u32)
        @shader : Shader? = nil
        @resolution : Int32 = 2048

        def initialize
          super("shadow")
        end

        def setup(context : Context)
          @resolution = Configuration.instance.shadow.resolution
          CASCADE_COUNT.times { |i| create_cascade_fbo(i) }
          @shader = Shader.from_file("shadow_depth")
          Log.info { "Shadow stage: #{CASCADE_COUNT} cascades @ #{@resolution}x#{@resolution}" }
        end

        def call(context : Context, frame : Frame) : Frame
          shader = @shader
          return frame unless shader
          return frame unless Configuration.instance.shadow.enabled

          dir_light = context.light_manager.directional
          return frame unless dir_light

          camera = context.camera
          near = camera.near_plane
          far = camera.far_plane
          light_dir = dir_light.direction.normalize

          splits = compute_splits(near, far)

          # CRITICAL: clear from previous frame
          frame.cascade_count = CASCADE_COUNT
          frame.cascade_matrices.clear

          # Shadow GL state — set once for all cascades
          LibGL.glEnable(LibGL::GL_DEPTH_TEST)
          LibGL.glDepthFunc(LibGL::GL_LESS)
          LibGL.glDepthMask(1_u8)
          LibGL.glDisable(LibGL::GL_CULL_FACE)
          LibGL.glEnable(LibGL::GL_POLYGON_OFFSET_FILL)
          LibGL.glPolygonOffset(1.1f32, 4.0f32)

          shader.use

          CASCADE_COUNT.times do |i|
            cascade_near = i == 0 ? near : splits[i - 1]
            cascade_far = splits[i]

            frame.cascade_splits[i] = cascade_far

            light_matrix = build_cascade_matrix(camera, light_dir, cascade_near, cascade_far)
            frame.cascade_matrices << light_matrix

            LibGL.glViewport(0, 0, @resolution, @resolution)
            LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @frame_buffers[i])
            LibGL.glClear(LibGL::GL_DEPTH_BUFFER_BIT)

            shader.set_matrix4("uLightSpaceMatrix", light_matrix)

            cull_frustum = build_open_near_frustum(light_matrix)

            context.scene.each_renderable(cull_frustum) do |node|
              shader.set_matrix4("uModel", node.world_matrix)
              node.mesh.try(&.draw)
            end

            frame.cascade_textures[i] = @depth_textures[i]
          end

          # Restore state
          LibGL.glDisable(LibGL::GL_POLYGON_OFFSET_FILL)
          LibGL.glEnable(LibGL::GL_CULL_FACE)
          LibGL.glCullFace(LibGL::GL_BACK)
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)

          frame.light_space_matrix = frame.cascade_matrices[0]
          frame.shadow_depth_texture = @depth_textures[0]

          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil
          CASCADE_COUNT.times do |i|
            if @frame_buffers[i] != 0
              fbo = @frame_buffers[i]
              LibGL.glDeleteFramebuffers(1, pointerof(fbo))
              @frame_buffers[i] = 0_u32
            end
            if @depth_textures[i] != 0
              tex = @depth_textures[i]
              LibGL.glDeleteTextures(1, pointerof(tex))
              @depth_textures[i] = 0_u32
            end
          end
        end

        private def compute_splits(near : Float32, far : Float32) : StaticArray(Float32, 4)
          splits = StaticArray(Float32, 4).new(0.0f32)
          CASCADE_COUNT.times do |i|
            p = (i + 1).to_f32 / CASCADE_COUNT.to_f32
            log_split = near * (far / near) ** p
            uni_split = near + (far - near) * p
            splits[i] = SPLIT_LAMBDA * log_split + (1.0f32 - SPLIT_LAMBDA) * uni_split
          end
          splits
        end

        private def build_cascade_matrix(
          camera : Camera,
          light_dir : Math::Vector3,
          cascade_near : Float32,
          cascade_far : Float32
        ) : Math::Matrix4
          aspect = camera.viewport_width.to_f32 / camera.viewport_height.to_f32
          fov_rad = camera.field_of_view * ::Math::PI.to_f32 / 180.0f32
          slice_proj = Math::Matrix4.perspective(fov_rad, aspect, cascade_near, cascade_far)
          inv_vp = (slice_proj * camera.view_matrix).inverse
          corners = frustum_corners(inv_vp)

          center = Math::Vector3.zero
          corners.each { |c| center = center + c }
          center = center * (1.0f32 / 8.0f32)

          radius = 0.0f32
          corners.each do |c|
            d = (c - center).magnitude
            radius = d if d > radius
          end

          # Quantize to texel grid for stable edges
          texel_size = (radius * 2.0f32) / @resolution.to_f32
          radius = (radius / texel_size).ceil * texel_size

          # Up vector handling for straight-down lights
          up = if light_dir.y.abs > 0.99f32
                 Math::Vector3.new(0.0f32, 0.0f32, 1.0f32)
               else
                 Math::Vector3.new(0.0f32, 1.0f32, 0.0f32)
               end

          # Push light camera far back to capture all shadow casters
          back_dist = radius * 10.0f32
          light_pos = center - light_dir * back_dist

          light_view = Math::Matrix4.look_at(light_pos, center, up)
          light_proj = Math::Matrix4.orthographic(
            -radius, radius, -radius, radius,
            0.0f32, back_dist * 2.0f32
          )

          # Texel snapping to prevent shimmer
          shadow_matrix = light_proj * light_view
          origin = shadow_matrix * Math::Vector4.new(0.0f32, 0.0f32, 0.0f32, 1.0f32)
          snap_x = (origin.x / texel_size).round * texel_size - origin.x
          snap_y = (origin.y / texel_size).round * texel_size - origin.y

          light_proj = Math::Matrix4.orthographic(
            -radius + snap_x, radius + snap_x,
            -radius + snap_y, radius + snap_y,
            0.0f32, back_dist * 2.0f32
          )

          light_proj * light_view
        end

        private def frustum_corners(inv_vp : Math::Matrix4) : Array(Math::Vector3)
          corners = [] of Math::Vector3
          [-1.0f32, 1.0f32].each do |x|
            [-1.0f32, 1.0f32].each do |y|
              [-1.0f32, 1.0f32].each do |z|
                pt = inv_vp * Math::Vector4.new(x, y, z, 1.0f32)
                corners << Math::Vector3.new(pt.x / pt.w, pt.y / pt.w, pt.z / pt.w)
              end
            end
          end
          corners
        end

        private def build_open_near_frustum(light_matrix : Math::Matrix4) : Math::Frustum
          frustum = Math::Frustum.new(light_matrix)
          planes = frustum.planes
          planes[4] = Math::Vector4.new(0.0f32, 0.0f32, 0.0f32, 1.0f32)
          Math::Frustum.new(planes)
        end

        private def create_cascade_fbo(index : Int32)
          tex = 0_u32
          LibGL.glGenTextures(1, pointerof(tex))
          @depth_textures[index] = tex

          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, tex)
          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_2D, 0, LibGL::GL_DEPTH_COMPONENT24.to_i32,
            @resolution, @resolution, 0,
            LibGL::GL_DEPTH_COMPONENT, LibGL::GL_FLOAT, Pointer(Void).null
          )

          # NEAREST — we read raw depth and do manual PCF
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_NEAREST.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_NEAREST.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_BORDER.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_BORDER.to_i32)
          border = StaticArray[1.0f32, 1.0f32, 1.0f32, 1.0f32]
          LibGL.glTexParameterfv(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_BORDER_COLOR, border.to_unsafe)

          # NO compare mode — fragment shader does its own comparison
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)

          fbo = 0_u32
          LibGL.glGenFramebuffers(1, pointerof(fbo))
          @frame_buffers[index] = fbo

          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, fbo)
          LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_DEPTH_ATTACHMENT, LibGL::GL_TEXTURE_2D, tex, 0)
          LibGL.glDrawBuffer(LibGL::GL_NONE)
          LibGL.glReadBuffer(LibGL::GL_NONE)
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, 0)
        end
      end
    end
  end
end
