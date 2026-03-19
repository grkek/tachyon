module Tachyon
  module Rendering
    module Stages
      class Shadow < Base
        Log = ::Log.for(self)

        CASCADE_AMOUNT = 4

        @frame_buffers : StaticArray(LibGL::GLuint, 4) = StaticArray(LibGL::GLuint, 4).new(0_u32)
        @depth_textures : StaticArray(LibGL::GLuint, 4) = StaticArray(LibGL::GLuint, 4).new(0_u32)
        @shader : Renderer::Shader? = nil
        @resolution : Int32 = 0

        # Cascade split distances (fraction of far plane)
        CASCADE_SPLITS = StaticArray[0.05f32, 0.15f32, 0.4f32, 1.0f32]

        def initialize
          super("shadow")
        end

        def setup(context : Context)
          @resolution = Configuration.instance.shadow.resolution
          CASCADE_AMOUNT.times do |i|
            create_cascade(i)
          end
          @shader = Renderer::Shader.from_file("shadow_depth")
          Log.info { "Shadow pass initialized (#{CASCADE_AMOUNT} cascades @ #{@resolution}x#{@resolution})" }
        end

        def call(context : Context, frame : Frame) : Frame
          shader = @shader
          return frame unless shader
          return frame unless Configuration.instance.shadow.enabled

          dir = context.light_manager.directional
          return frame unless dir

          camera = context.camera
          near = camera.near_plane
          far = camera.far_plane

          frame.cascade_count = CASCADE_AMOUNT

          CASCADE_AMOUNT.times do |i|
            # Compute cascade near/far in view space
            cascade_near = i == 0 ? near : near + (far - near) * CASCADE_SPLITS[i - 1]
            cascade_far = near + (far - near) * CASCADE_SPLITS[i]

            # Store the split distance in clip space for the fragment shader
            frame.cascade_splits[i] = cascade_far

            # Compute tight light-space matrix for this cascade
            light_matrix = compute_cascade_matrix(camera, dir, cascade_near, cascade_far)
            frame.cascade_matrices << light_matrix

            # Render into this cascade's shadow map
            LibGL.glViewport(0, 0, @resolution, @resolution)
            LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @frame_buffers[i])
            LibGL.glClear(LibGL::GL_DEPTH_BUFFER_BIT)

            LibGL.glEnable(LibGL::GL_POLYGON_OFFSET_FILL)
            LibGL.glPolygonOffset(1.5f32, 3.0f32)

            shader.use
            shader.set_matrix4("uLightSpaceMatrix", light_matrix)

            context.scene.each_renderable do |node|
              shader.set_matrix4("uModel", node.world_matrix)
              node.mesh.try(&.draw)
            end

            LibGL.glDisable(LibGL::GL_POLYGON_OFFSET_FILL)

            frame.cascade_textures[i] = @depth_textures[i]
          end

          # Restore the incoming framebuffer
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)

          # Keep backward compatibility — first cascade as the primary shadow map
          frame.light_space_matrix = frame.cascade_matrices[0]
          frame.shadow_depth_texture = @depth_textures[0]

          frame
        end

        def teardown
          @shader.try(&.destroy)
          @shader = nil

          CASCADE_AMOUNT.times do |i|
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

        private def compute_cascade_matrix(camera : Renderer::Camera, light : Renderer::Light, cascade_near : Float32, cascade_far : Float32) : Math::Matrix4
          # Build a projection matrix for just this cascade's slice
          aspect = camera.viewport_width.to_f32 / camera.viewport_height.to_f32
          fov_rad = camera.field_of_view * ::Math::PI.to_f32 / 180.0f32
          slice_proj = Math::Matrix4.perspective(fov_rad, aspect, cascade_near, cascade_far)

          # Get the 8 corners of this frustum slice in world space
          inv_vp = (slice_proj * camera.view_matrix).inverse
          corners = frustum_corners(inv_vp)

          # Find the center of the frustum slice
          center = Math::Vector3.zero
          corners.each { |c| center = center + c }
          center = center * (1.0f32 / 8.0f32)

          # Compute the radius (bounding sphere) for stable shadow edges
          radius = 0.0f32
          corners.each do |c|
            dist = (c - center).magnitude
            radius = dist if dist > radius
          end
          # Round up to avoid sub-pixel jitter
          radius = (radius * 16.0f32).ceil / 16.0f32

          # Build light view/projection
          light_dir = light.direction.normalize
          light_pos = center - light_dir * radius
          light_view = Math::Matrix4.look_at(light_pos, center, Math::Vector3.new(0.0f32, 1.0f32, 0.0f32))
          light_proj = Math::Matrix4.orthographic(-radius, radius, -radius, radius, 0.01f32, radius * 2.0f32)

          # Snap to texel grid to prevent shadow shimmer when camera moves
          shadow_matrix = light_proj * light_view
          origin = shadow_matrix * Math::Vector4.new(0.0f32, 0.0f32, 0.0f32, 1.0f32)
          texel_size = (radius * 2.0f32) / @resolution.to_f32
          origin_x = origin.x / texel_size
          origin_y = origin.y / texel_size
          round_x = origin_x.round - origin_x
          round_y = origin_y.round - origin_y
          round_x *= texel_size
          round_y *= texel_size

          light_proj = Math::Matrix4.orthographic(
            -radius + round_x, radius + round_x,
            -radius + round_y, radius + round_y,
            0.01f32, radius * 2.0f32
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

        private def create_cascade(index : Int32)
          # Depth texture
          tex = 0_u32
          LibGL.glGenTextures(1, pointerof(tex))
          @depth_textures[index] = tex

          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, tex)
          LibGL.glTexImage2D(
            LibGL::GL_TEXTURE_2D, 0, LibGL::GL_DEPTH_COMPONENT24.to_i32,
            @resolution, @resolution, 0,
            LibGL::GL_DEPTH_COMPONENT, LibGL::GL_FLOAT, Pointer(Void).null
          )
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_BORDER.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_BORDER.to_i32)
          border_color = StaticArray[1.0f32, 1.0f32, 1.0f32, 1.0f32]
          LibGL.glTexParameterfv(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_BORDER_COLOR, border_color.to_unsafe)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_COMPARE_MODE, LibGL::GL_COMPARE_REF_TO_TEXTURE.to_i32)
          LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_COMPARE_FUNC, LibGL::GL_LEQUAL.to_i32)
          LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, 0)

          # Framebuffer
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
