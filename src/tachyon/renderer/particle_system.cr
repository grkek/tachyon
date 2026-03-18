module Tachyon
  module Renderer
    class ParticleSystem
      Log = ::Log.for(self)

      class Particle
        property position : Math::Vector3 = Math::Vector3.zero
        property velocity : Math::Vector3 = Math::Vector3.zero
        property color : Math::Vector3 = Math::Vector3.new(1.0f32, 1.0f32, 1.0f32)
        property alpha : Float32 = 1.0f32
        property size : Float32 = 0.1f32
        property lifetime : Float32 = 0.0f32
        property max_lifetime : Float32 = 1.0f32
        property alive : Bool = false

        def initialize
        end
      end

      class Emitter
        Log = ::Log.for(self)

        property position : Math::Vector3 = Math::Vector3.zero
        property direction : Math::Vector3 = Math::Vector3.up
        property spread : Float32 = 0.5f32
        property speed_min : Float32 = 1.0f32
        property speed_max : Float32 = 3.0f32
        property lifetime_min : Float32 = 0.5f32
        property lifetime_max : Float32 = 2.0f32
        property size_start : Float32 = 0.1f32
        property size_end : Float32 = 0.02f32
        property color_start : Math::Vector3 = Math::Vector3.new(1.0f32, 0.8f32, 0.2f32)
        property color_end : Math::Vector3 = Math::Vector3.new(1.0f32, 0.2f32, 0.0f32)
        property alpha_start : Float32 = 1.0f32
        property alpha_end : Float32 = 0.0f32
        property gravity : Math::Vector3 = Math::Vector3.new(0.0f32, -9.8f32, 0.0f32)
        property emit_rate : Float32 = 20.0f32
        property max_particles : Int32 = 256
        property active : Bool = true
        property one_shot : Bool = false
        property texture : Texture? = nil

        @particles : Array(Particle)
        @emit_accumulator : Float32 = 0.0f32
        @one_shot_emitted : Bool = false

        def initialize(@max_particles : Int32 = 256)
          @particles = Array(Particle).new(@max_particles) { Particle.new }
        end

        def update(delta_time : Float32)
          update_living_particles(delta_time)
          emit_new_particles(delta_time) if @active
        end

        def emit(count : Int32)
          count.times { spawn_particle }
        end

        def reset
          @particles.each { |particle| particle.alive = false }
          @emit_accumulator = 0.0f32
          @one_shot_emitted = false
        end

        def alive_count : Int32
          @particles.count(&.alive)
        end

        def each_alive(&block : Particle ->)
          @particles.each do |particle|
            block.call(particle) if particle.alive
          end
        end

        private def update_living_particles(delta_time : Float32)
          @particles.each do |particle|
            next unless particle.alive

            particle.lifetime += delta_time

            if particle.lifetime >= particle.max_lifetime
              particle.alive = false
              next
            end

            progress = particle.lifetime / particle.max_lifetime

            particle.velocity = particle.velocity + @gravity * delta_time
            particle.position = particle.position + particle.velocity * delta_time

            particle.color = lerp_vector3(@color_start, @color_end, progress)
            particle.alpha = @alpha_start + (@alpha_end - @alpha_start) * progress
            particle.size = @size_start + (@size_end - @size_start) * progress
          end
        end

        private def emit_new_particles(delta_time : Float32)
          if @one_shot
            return if @one_shot_emitted
            @max_particles.times { spawn_particle }
            @one_shot_emitted = true
            return
          end

          @emit_accumulator += @emit_rate * delta_time

          while @emit_accumulator >= 1.0f32
            spawn_particle
            @emit_accumulator -= 1.0f32
          end
        end

        private def spawn_particle
          particle = find_dead_particle
          return unless particle

          particle.alive = true
          particle.lifetime = 0.0f32
          particle.position = @position
          particle.max_lifetime = random_range(@lifetime_min, @lifetime_max)

          speed = random_range(@speed_min, @speed_max)
          offset = random_cone_direction(@direction, @spread)
          particle.velocity = offset * speed

          particle.color = @color_start
          particle.alpha = @alpha_start
          particle.size = @size_start
        end

        private def find_dead_particle : Particle?
          @particles.each do |particle|
            return particle unless particle.alive
          end
          nil
        end

        private def random_range(min_value : Float32, max_value : Float32) : Float32
          min_value + rand.to_f32 * (max_value - min_value)
        end

        private def random_cone_direction(base_direction : Math::Vector3, half_angle : Float32) : Math::Vector3
          return base_direction.normalize if half_angle < 0.001f32

          theta = rand.to_f32 * 2.0f32 * ::Math::PI.to_f32
          cos_phi = ::Math.cos(half_angle).to_f32 + rand.to_f32 * (1.0f32 - ::Math.cos(half_angle).to_f32)
          sin_phi = ::Math.sqrt(1.0f32 - cos_phi * cos_phi).to_f32

          local_x = sin_phi * ::Math.cos(theta).to_f32
          local_y = sin_phi * ::Math.sin(theta).to_f32
          local_z = cos_phi

          dir = base_direction.normalize
          up = if dir.dot(Math::Vector3.up).abs > 0.99f32
                 Math::Vector3.right
               else
                 Math::Vector3.up
               end

          right = dir.cross(up).normalize
          actual_up = right.cross(dir).normalize

          result = right * local_x + actual_up * local_y + dir * local_z
          result.normalize
        end

        private def lerp_vector3(from : Math::Vector3, to : Math::Vector3, t : Float32) : Math::Vector3
          Math::Vector3.new(
            from.x + (to.x - from.x) * t,
            from.y + (to.y - from.y) * t,
            from.z + (to.z - from.z) * t,
          )
        end
      end

      getter emitters : Array(Emitter) = [] of Emitter

      @billboard_shader : Shader? = nil
      @quad_vao : LibGL::GLuint = 0_u32
      @quad_vbo : LibGL::GLuint = 0_u32
      @instance_vbo : LibGL::GLuint = 0_u32
      @max_instances : Int32 = 4096
      @default_texture : Texture? = nil
      @initialized : Bool = false

      def initialize
      end

      def setup
        @billboard_shader = Shader.from_file("particle")

        @default_texture = Texture.solid_color(255_u8, 255_u8, 255_u8, 255_u8)

        setup_quad_buffer
        setup_instance_buffer
        @initialized = true
      end

      def add_emitter(emitter : Emitter) : Emitter
        @emitters << emitter
        emitter
      end

      def remove_emitter(emitter : Emitter)
        @emitters.delete(emitter)
      end

      def update(delta_time : Float32)
        @emitters.each do |emitter|
          emitter.update(delta_time)
        end
      end

      # TODO: Group emitters for a better performance
      def render(view_matrix : Math::Matrix4, projection_matrix : Math::Matrix4, camera_position : Math::Vector3)
        return unless @initialized
        shader = @billboard_shader
        return unless shader

        LibGL.glEnable(LibGL::GL_BLEND)
        LibGL.glBlendFunc(LibGL::GL_SRC_ALPHA, LibGL::GL_ONE_MINUS_SRC_ALPHA)
        LibGL.glDepthMask(LibGL::GL_FALSE)
        LibGL.glDisable(LibGL::GL_CULL_FACE)

        shader.use
        shader.set_matrix4("uView", view_matrix)
        shader.set_matrix4("uProjection", projection_matrix)
        shader.set_vector3("uCameraRight", camera_right(view_matrix))
        shader.set_vector3("uCameraUp", camera_up(view_matrix))
        shader.set_int("uTexture", 0)

        instance_data = [] of Float32

        @emitters.each do |emitter|
          instance_data.clear

          emitter.each_alive do |particle|
            instance_data << particle.position.x
            instance_data << particle.position.y
            instance_data << particle.position.z
            instance_data << particle.size
            instance_data << particle.color.x
            instance_data << particle.color.y
            instance_data << particle.color.z
            instance_data << particle.alpha
          end

          next if instance_data.empty?
          instance_count = instance_data.size // 8

          if texture = emitter.texture
            texture.bind(0)
          elsif default_texture = @default_texture
            default_texture.bind(0)
          end

          LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @instance_vbo)
          upload_size = instance_data.size.to_i64 * sizeof(Float32)
          LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER, upload_size,
            instance_data.to_unsafe.as(Pointer(Void)),
            LibGL::GL_STREAM_DRAW)

          LibGL.glBindVertexArray(@quad_vao)
          LibGL.glDrawArraysInstanced(LibGL::GL_TRIANGLES, 0, 6, instance_count)
        end

        LibGL.glBindVertexArray(0)
        LibGL.glDepthMask(LibGL::GL_TRUE)
        LibGL.glDisable(LibGL::GL_BLEND)
        LibGL.glEnable(LibGL::GL_CULL_FACE)
      end

      def destroy
        return unless @initialized
        @billboard_shader.try(&.destroy)
        @default_texture.try(&.destroy)
        LibGL.glDeleteVertexArrays(1, pointerof(@quad_vao))
        LibGL.glDeleteBuffers(1, pointerof(@quad_vbo))
        LibGL.glDeleteBuffers(1, pointerof(@instance_vbo))
        @initialized = false
      end

      private def camera_right(view_matrix : Math::Matrix4) : Math::Vector3
        Math::Vector3.new(view_matrix[0, 0], view_matrix[1, 0], view_matrix[2, 0])
      end

      private def camera_up(view_matrix : Math::Matrix4) : Math::Vector3
        Math::Vector3.new(view_matrix[0, 1], view_matrix[1, 1], view_matrix[2, 1])
      end

      private def setup_quad_buffer
        quad_vertices = StaticArray[
          -0.5f32, -0.5f32, 0.0f32, 0.0f32,
          0.5f32, -0.5f32, 1.0f32, 0.0f32,
          0.5f32, 0.5f32, 1.0f32, 1.0f32,
          -0.5f32, -0.5f32, 0.0f32, 0.0f32,
          0.5f32, 0.5f32, 1.0f32, 1.0f32,
          -0.5f32, 0.5f32, 0.0f32, 1.0f32,
        ]

        LibGL.glGenVertexArrays(1, pointerof(@quad_vao))
        LibGL.glBindVertexArray(@quad_vao)

        LibGL.glGenBuffers(1, pointerof(@quad_vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @quad_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          quad_vertices.size.to_i64 * sizeof(Float32),
          quad_vertices.to_unsafe.as(Pointer(Void)),
          LibGL::GL_STATIC_DRAW)

        # location 0: quad vertex position (vec2)
        LibGL.glEnableVertexAttribArray(0)
        LibGL.glVertexAttribPointer(0, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).null)

        # location 1: quad UV (vec2)
        LibGL.glEnableVertexAttribArray(1)
        LibGL.glVertexAttribPointer(1, 2, LibGL::GL_FLOAT, LibGL::GL_FALSE, 4 * sizeof(Float32), Pointer(Void).new(2_u64 * sizeof(Float32)))

        LibGL.glBindVertexArray(0)
      end

      private def setup_instance_buffer
        LibGL.glBindVertexArray(@quad_vao)

        LibGL.glGenBuffers(1, pointerof(@instance_vbo))
        LibGL.glBindBuffer(LibGL::GL_ARRAY_BUFFER, @instance_vbo)
        LibGL.glBufferData(LibGL::GL_ARRAY_BUFFER,
          @max_instances.to_i64 * 8 * sizeof(Float32),
          Pointer(Void).null,
          LibGL::GL_STREAM_DRAW)

        stride = 8 * sizeof(Float32)

        # location 2: instance position (vec3)
        LibGL.glEnableVertexAttribArray(2)
        LibGL.glVertexAttribPointer(2, 3, LibGL::GL_FLOAT, LibGL::GL_FALSE, stride, Pointer(Void).null)
        LibGL.glVertexAttribDivisor(2, 1)

        # location 3: instance size (float)
        LibGL.glEnableVertexAttribArray(3)
        LibGL.glVertexAttribPointer(3, 1, LibGL::GL_FLOAT, LibGL::GL_FALSE, stride, Pointer(Void).new(3_u64 * sizeof(Float32)))
        LibGL.glVertexAttribDivisor(3, 1)

        # location 4: instance color + alpha (vec4)
        LibGL.glEnableVertexAttribArray(4)
        LibGL.glVertexAttribPointer(4, 4, LibGL::GL_FLOAT, LibGL::GL_FALSE, stride, Pointer(Void).new(4_u64 * sizeof(Float32)))
        LibGL.glVertexAttribDivisor(4, 1)

        LibGL.glBindVertexArray(0)
      end
    end
  end
end
