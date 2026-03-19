module Tachyon
  module Renderer
    class IBL
      Log = ::Log.for(self)

      getter irradiance_map : LibGL::GLuint = 0_u32
      getter prefilter_map : LibGL::GLuint = 0_u32
      getter brdf_lut : LibGL::GLuint = 0_u32
      getter environment_map : LibGL::GLuint = 0_u32

      @equirect_shader : Shader
      @irradiance_shader : Shader
      @prefilter_shader : Shader
      @brdf_shader : Shader
      @cube_vao : LibGL::GLuint = 0_u32
      @cube_vbo : LibGL::GLuint = 0_u32
      @capture_frame_buffer : LibGL::GLuint = 0_u32
      @capture_rbo : LibGL::GLuint = 0_u32
      @ready : Bool = false

      CUBE_VERTICES = StaticArray[
        -1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32,
        1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32,
        -1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32,
        1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32,
        -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32,
        -1.0f32, -1.0f32, -1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32,
        1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32,
        1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, 1.0f32, 1.0f32,
        -1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, 1.0f32,
        1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, 1.0f32, -1.0f32, -1.0f32, -1.0f32,
        -1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, 1.0f32,
        1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, 1.0f32, -1.0f32, 1.0f32, -1.0f32,
      ]

      CAPTURE_VIEWS = [
        Math::Matrix4.look_at(Math::Vector3.zero, Math::Vector3.new(1.0f32, 0.0f32, 0.0f32), Math::Vector3.new(0.0f32, -1.0f32, 0.0f32)),
        Math::Matrix4.look_at(Math::Vector3.zero, Math::Vector3.new(-1.0f32, 0.0f32, 0.0f32), Math::Vector3.new(0.0f32, -1.0f32, 0.0f32)),
        Math::Matrix4.look_at(Math::Vector3.zero, Math::Vector3.new(0.0f32, 1.0f32, 0.0f32), Math::Vector3.new(0.0f32, 0.0f32, 1.0f32)),
        Math::Matrix4.look_at(Math::Vector3.zero, Math::Vector3.new(0.0f32, -1.0f32, 0.0f32), Math::Vector3.new(0.0f32, 0.0f32, -1.0f32)),
        Math::Matrix4.look_at(Math::Vector3.zero, Math::Vector3.new(0.0f32, 0.0f32, 1.0f32), Math::Vector3.new(0.0f32, -1.0f32, 0.0f32)),
        Math::Matrix4.look_at(Math::Vector3.zero, Math::Vector3.new(0.0f32, 0.0f32, -1.0f32), Math::Vector3.new(0.0f32, -1.0f32, 0.0f32)),
      ]

      def initialize
        @equirect_shader = Shader.from_file("equirect_to_cube")
        @irradiance_shader = Shader.new(Shader.load_file("equirect_to_cube.vert"), Shader.load_file("irradiance.frag"))
        @prefilter_shader = Shader.new(Shader.load_file("equirect_to_cube.vert"), Shader.load_file("prefilter.frag"))
        @brdf_shader = Shader.new(Shader.load_file("quad.vert"), Shader.load_file("brdf_lut.frag"))
        setup_cube
        setup_capture_frame_buffer
      end

      def ready? : Bool
        @ready
      end

      def load_hdr(path : String)
        Log.info { "Loading HDR environment: #{path}" }

        gtk_frame_buffer = 0_i32
        LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(gtk_frame_buffer))
        Log.debug { "Saved GTK FBO: #{gtk_frame_buffer}" }

        saved_viewport = StaticArray(Int32, 4).new(0)
        LibGL.glGetIntegerv(LibGL::GL_VIEWPORT, saved_viewport.to_unsafe)

        width = 0
        height = 0
        channels = 0
        LibSTBI.stbi_set_flip_vertically_on_load(1)
        data = LibSTBI.stbi_loadf(path, pointerof(width), pointerof(height), pointerof(channels), 3)

        unless data
          Log.error { "Failed to load HDR: #{path}" }
          return
        end

        Log.info { "HDR loaded: #{width}x#{height}, #{channels} channels" }

        hdr_texture = 0_u32
        LibGL.glGenTextures(1, pointerof(hdr_texture))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, hdr_texture)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_RGB16F.to_i32, width, height, 0,
          LibGL::GL_RGB, LibGL::GL_FLOAT, data.as(Pointer(Void)))
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibSTBI.stbi_image_free(data.as(Pointer(Void)))

        capture_projection = Math::Matrix4.perspective(90.0f32 * ::Math::PI.to_f32 / 180.0f32, 1.0f32, 0.1f32, 10.0f32)

        LibGL.glDisable(LibGL::GL_DEPTH_TEST)

        convert_to_cubemap(hdr_texture, capture_projection)
        generate_irradiance(capture_projection)
        generate_prefilter(capture_projection)
        generate_brdf_lut

        LibGL.glEnable(LibGL::GL_DEPTH_TEST)

        LibGL.glDeleteTextures(1, pointerof(hdr_texture))
        LibSTBI.stbi_set_flip_vertically_on_load(0)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, gtk_frame_buffer.to_u32)
        LibGL.glViewport(saved_viewport[0], saved_viewport[1], saved_viewport[2], saved_viewport[3])
        LibGL.glEnable(LibGL::GL_DEPTH_TEST)
        LibGL.glEnable(LibGL::GL_CULL_FACE)
        LibGL.glCullFace(LibGL::GL_BACK)

        @ready = true
        Log.info { "IBL maps generated successfully" }
        Log.info { "  Environment: #{@environment_map}, Irradiance: #{@irradiance_map}, Prefilter: #{@prefilter_map}, BRDF: #{@brdf_lut}" }
      end

      def bind(shader : Shader, irradiance_unit : Int32 = 7, prefilter_unit : Int32 = 8, brdf_unit : Int32 = 9)
        return unless @ready

        LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + irradiance_unit.to_u32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @irradiance_map)
        shader.set_int("uIrradianceMap", irradiance_unit)

        LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + prefilter_unit.to_u32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @prefilter_map)
        shader.set_int("uPrefilterMap", prefilter_unit)

        LibGL.glActiveTexture(LibGL::GL_TEXTURE0 + brdf_unit.to_u32)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @brdf_lut)
        shader.set_int("uBRDFLUT", brdf_unit)

        shader.set_int("uHasIBL", 1)
      end

      def destroy
        @equirect_shader.destroy
        @irradiance_shader.destroy
        @prefilter_shader.destroy
        @brdf_shader.destroy
        LibGL.glDeleteTextures(1, pointerof(@irradiance_map)) if @irradiance_map != 0
        LibGL.glDeleteTextures(1, pointerof(@prefilter_map)) if @prefilter_map != 0
        LibGL.glDeleteTextures(1, pointerof(@brdf_lut)) if @brdf_lut != 0
        LibGL.glDeleteTextures(1, pointerof(@environment_map)) if @environment_map != 0
        LibGL.glDeleteVertexArrays(1, pointerof(@cube_vao))
        LibGL.glDeleteBuffers(1, pointerof(@cube_vbo))
        LibGL.glDeleteFramebuffers(1, pointerof(@capture_frame_buffer))
        LibGL.glDeleteRenderbuffers(1, pointerof(@capture_rbo))
      end

      private def setup_cube
        LibGL.glGenVertexArrays(1, pointerof(@cube_vao))
        LibGL.glGenBuffers(1, pointerof(@cube_vbo))
        LibGL.glBindVertexArray(@cube_vao)
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @cube_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          CUBE_VERTICES.size.to_i64 * sizeof(Float32),
          CUBE_VERTICES.to_unsafe.as(Pointer(Void)),
          LibGL::GL_STATIC_DRAW)
        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 3, LibGL::GL_FLOAT, LibGL::GL_FALSE, 3 * sizeof(Float32), Pointer(Void).null)
        LibGL.glBindVertexArray(0)
      end

      private def setup_capture_frame_buffer
        LibGL.glGenFramebuffers(1, pointerof(@capture_frame_buffer))
        LibGL.glGenRenderbuffers(1, pointerof(@capture_rbo))
      end

      private def render_cube
        LibGL.glBindVertexArray(@cube_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 36)
        LibGL.glBindVertexArray(0)
      end

      private def check_frame_buffer_status(label : String)
        status = LibGL.glCheckFramebufferStatus(LibGL::GL_FRAMEBUFFER)
        if status != LibGL::GL_FRAMEBUFFER_COMPLETE
          Log.error { "#{label}: FBO incomplete, status=#{status}" }
        end
      end

      private def convert_to_cubemap(hdr_texture : LibGL::GLuint, projection : Math::Matrix4)
        env_size = 512

        LibGL.glGenTextures(1, pointerof(@environment_map))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @environment_map)
        6.times do |i|
          LibGL.glTexImage2D(LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, 0, LibGL::GL_RGB16F.to_i32,
            env_size, env_size, 0, LibGL::GL_RGB, LibGL::GL_FLOAT, Pointer(Void).null)
        end
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR_MIPMAP_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_R, LibGL::GL_CLAMP_TO_EDGE.to_i32)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @capture_frame_buffer)
        LibGL.glBindRenderbuffer(LibGL::GL_RENDERBUFFER, @capture_rbo)
        LibGL.glRenderbufferStorage(LibGL::GL_RENDERBUFFER, LibGL::GL_DEPTH_COMPONENT24, env_size, env_size)
        LibGL.glFramebufferRenderbuffer(LibGL::GL_FRAMEBUFFER, LibGL::GL_DEPTH_ATTACHMENT, LibGL::GL_RENDERBUFFER, @capture_rbo)

        @equirect_shader.use
        @equirect_shader.set_int("uEquirectangularMap", 0)
        @equirect_shader.set_matrix4("uProjection", projection)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, hdr_texture)

        LibGL.glViewport(0, 0, env_size, env_size)
        LibGL.glDisable(LibGL::GL_CULL_FACE)
        6.times do |i|
          @equirect_shader.set_matrix4("uView", CAPTURE_VIEWS[i])
          LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0,
            LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, @environment_map, 0)
          check_frame_buffer_status("convert_to_cubemap face #{i}") if i == 0
          LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)
          render_cube
        end
        LibGL.glEnable(LibGL::GL_CULL_FACE)

        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @environment_map)
        LibGL.glGenerateMipmap(LibGL::GL_TEXTURE_CUBE_MAP)

        Log.debug { "Environment cubemap generated: #{@environment_map}" }
      end

      private def generate_irradiance(projection : Math::Matrix4)
        irr_size = 32

        LibGL.glGenTextures(1, pointerof(@irradiance_map))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @irradiance_map)
        6.times do |i|
          LibGL.glTexImage2D(LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, 0, LibGL::GL_RGB16F.to_i32,
            irr_size, irr_size, 0, LibGL::GL_RGB, LibGL::GL_FLOAT, Pointer(Void).null)
        end
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_R, LibGL::GL_CLAMP_TO_EDGE.to_i32)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @capture_frame_buffer)
        LibGL.glBindRenderbuffer(LibGL::GL_RENDERBUFFER, @capture_rbo)
        LibGL.glRenderbufferStorage(LibGL::GL_RENDERBUFFER, LibGL::GL_DEPTH_COMPONENT24, irr_size, irr_size)

        @irradiance_shader.use
        @irradiance_shader.set_int("uEnvironmentMap", 0)
        @irradiance_shader.set_matrix4("uProjection", projection)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @environment_map)

        LibGL.glViewport(0, 0, irr_size, irr_size)
        LibGL.glDisable(LibGL::GL_CULL_FACE)
        6.times do |i|
          @irradiance_shader.set_matrix4("uView", CAPTURE_VIEWS[i])
          LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0,
            LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, @irradiance_map, 0)
          check_frame_buffer_status("irradiance face #{i}") if i == 0
          LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)
          render_cube
        end
        LibGL.glEnable(LibGL::GL_CULL_FACE)

        Log.debug { "Irradiance map generated: #{@irradiance_map}" }
      end

      private def generate_prefilter(projection : Math::Matrix4)
        prefilter_size = 128
        max_mip_levels = 5

        LibGL.glGenTextures(1, pointerof(@prefilter_map))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @prefilter_map)
        6.times do |i|
          LibGL.glTexImage2D(LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, 0, LibGL::GL_RGB16F.to_i32,
            prefilter_size, prefilter_size, 0, LibGL::GL_RGB, LibGL::GL_FLOAT, Pointer(Void).null)
        end
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR_MIPMAP_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_CUBE_MAP, LibGL::GL_TEXTURE_WRAP_R, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glGenerateMipmap(LibGL::GL_TEXTURE_CUBE_MAP)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @capture_frame_buffer)

        @prefilter_shader.use
        @prefilter_shader.set_int("uEnvironmentMap", 0)
        @prefilter_shader.set_matrix4("uProjection", projection)
        LibGL.glActiveTexture(LibGL::GL_TEXTURE0)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_CUBE_MAP, @environment_map)

        LibGL.glDisable(LibGL::GL_CULL_FACE)
        max_mip_levels.times do |mip|
          mip_width = (prefilter_size * (0.5 ** mip)).to_i32
          mip_height = mip_width
          roughness = mip.to_f32 / (max_mip_levels - 1).to_f32

          LibGL.glBindRenderbuffer(LibGL::GL_RENDERBUFFER, @capture_rbo)
          LibGL.glRenderbufferStorage(LibGL::GL_RENDERBUFFER, LibGL::GL_DEPTH_COMPONENT24, mip_width, mip_height)
          LibGL.glViewport(0, 0, mip_width, mip_height)

          @prefilter_shader.set_float("uRoughness", roughness)

          6.times do |i|
            @prefilter_shader.set_matrix4("uView", CAPTURE_VIEWS[i])
            LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0,
              LibGL::GL_TEXTURE_CUBE_MAP_POSITIVE_X + i.to_u32, @prefilter_map, mip)
            LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)
            render_cube
          end
        end
        LibGL.glEnable(LibGL::GL_CULL_FACE)

        Log.debug { "Prefilter map generated: #{@prefilter_map}" }
      end

      private def generate_brdf_lut
        lut_size = 512

        # Temporary quad VAO for the single BRDF integration draw
        quad_vao = 0_u32
        quad_vbo = 0_u32
        LibGL.glGenVertexArrays(1, pointerof(quad_vao))
        LibGL.glBindVertexArray(quad_vao)
        LibGL.glGenBuffers(1, pointerof(quad_vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, quad_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          Constants::QUAD_VERTICES.size.to_i64 * sizeof(Float32),
          Constants::QUAD_VERTICES.to_unsafe.as(Pointer(Void)),
          LibGL::GL_STATIC_DRAW)
        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).null)
        LibGL.glEnableVertexAttribArray(1)
        LibGL.glVertexAttribPointer(1, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).new(2_u64 * sizeof(Float32)))
        LibGL.glBindVertexArray(0)

        LibGL.glGenTextures(1, pointerof(@brdf_lut))
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, @brdf_lut)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_RG16F.to_i32, lut_size, lut_size, 0,
          LibGL::GL_RG, LibGL::GL_FLOAT, Pointer(Void).null)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @capture_frame_buffer)
        LibGL.glBindRenderbuffer(LibGL::GL_RENDERBUFFER, @capture_rbo)
        LibGL.glRenderbufferStorage(LibGL::GL_RENDERBUFFER, LibGL::GL_DEPTH_COMPONENT24, lut_size, lut_size)
        LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0, LibGL::GL_TEXTURE_2D, @brdf_lut, 0)
        check_frame_buffer_status("brdf_lut")

        LibGL.glViewport(0, 0, lut_size, lut_size)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)
        @brdf_shader.use
        LibGL.glBindVertexArray(quad_vao)
        LibGL.glDrawArrays(LibGL::GL_TRIANGLES, 0, 6)
        LibGL.glBindVertexArray(0)

        # Clean up temporary quad
        LibGL.glDeleteVertexArrays(1, pointerof(quad_vao))
        LibGL.glDeleteBuffers(1, pointerof(quad_vbo))

        Log.debug { "BRDF LUT generated: #{@brdf_lut}" }
      end
    end
  end
end
