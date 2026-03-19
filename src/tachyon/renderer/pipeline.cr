module Tachyon
  module Rendering
    # Executes an ordered list of stages, passing a Frame through each one.
    # Provides a full API for runtime insertion, removal, reordering, and toggling.
    class Pipeline
      Log = ::Log.for(self)

      getter stages : Array(Stages::Base)
      getter context : Context

      @realized : Bool = false

      # Ping-pong framebuffers for blit-free post-processing
      @post_process_fbo_a : LibGL::GLuint = 0_u32
      @post_process_tex_a : LibGL::GLuint = 0_u32
      @post_process_depth_a : LibGL::GLuint = 0_u32
      @post_process_fbo_b : LibGL::GLuint = 0_u32
      @post_process_tex_b : LibGL::GLuint = 0_u32
      @post_process_depth_b : LibGL::GLuint = 0_u32
      @post_process_width : Int32 = 0
      @post_process_height : Int32 = 0

      def initialize(@context : Context)
        @stages = [] of Stages::Base
      end

      # Append a stage to the end of the pipeline
      def add(stage : Stages::Base)
        @stages << stage
        stage.setup(@context) if @realized
        Log.info { "Added stage: #{stage.name}" }
      end

      # Insert a stage at a specific index
      def insert(index : Int32, stage : Stages::Base)
        clamped = index.clamp(0, @stages.size)
        @stages.insert(clamped, stage)
        stage.setup(@context) if @realized
        Log.info { "Inserted stage '#{stage.name}' at index #{clamped}" }
      end

      # Insert a stage immediately before another (looked up by name)
      def insert_before(target : String, stage : Stages::Base)
        idx = index_of(target)
        idx ? insert(idx, stage) : add(stage)
      end

      # Insert a stage immediately after another (looked up by name)
      def insert_after(target : String, stage : Stages::Base)
        idx = index_of(target)
        idx ? insert(idx + 1, stage) : add(stage)
      end

      # Remove a stage by name, tearing it down and returning it
      def remove(name : String) : Stages::Base?
        idx = index_of(name)
        return nil unless idx
        stage = @stages.delete_at(idx)
        stage.teardown
        Log.info { "Removed stage: #{name}" }
        stage
      end

      # Replace a stage by name, tearing down the old and setting up the new
      def replace(name : String, new_stage : Stages::Base) : Stages::Base?
        idx = index_of(name)
        return nil unless idx
        old = @stages[idx]
        old.teardown
        @stages[idx] = new_stage
        new_stage.setup(@context) if @realized
        Log.info { "Replaced stage '#{name}' with '#{new_stage.name}'" }
        old
      end

      # Move a stage to a new index
      def move(name : String, new_index : Int32) : Bool
        idx = index_of(name)
        return false unless idx
        stage = @stages.delete_at(idx)
        clamped = new_index.clamp(0, @stages.size)
        @stages.insert(clamped, stage)
        Log.info { "Moved stage '#{name}' from #{idx} to #{clamped}" }
        true
      end

      # Swap two stages by name
      def swap(name_a : String, name_b : String) : Bool
        idx_a = index_of(name_a)
        idx_b = index_of(name_b)
        return false unless idx_a && idx_b
        @stages[idx_a], @stages[idx_b] = @stages[idx_b], @stages[idx_a]
        Log.info { "Swapped stages '#{name_a}' and '#{name_b}'" }
        true
      end

      # Find a stage by name
      def find(name : String) : Stages::Base?
        @stages.find { |s| s.name == name }
      end

      # Find a stage by its concrete type
      def find_by_type(type : T.class) : T? forall T
        @stages.each do |stage|
          return stage.as(T) if stage.is_a?(T)
        end
        nil
      end

      # Enable or disable a stage by name
      def toggle(name : String, enabled : Bool)
        stage = find(name)
        if stage
          stage.enabled = enabled
          Log.info { "Stages::Base '#{name}' #{enabled ? "enabled" : "disabled"}" }
        end
      end

      # Return the index of a stage by name, or nil
      def index_of(name : String) : Int32?
        @stages.index { |s| s.name == name }
      end

      # Check whether a named stage exists
      def has_stage?(name : String) : Bool
        @stages.any? { |s| s.name == name }
      end

      # Return the number of stages
      def size : Int32
        @stages.size
      end

      # Initialize all stages (call once when GL context is ready)
      def setup
        @stages.each { |s| s.setup(@context) }
        @realized = true
        Log.info { "Pipeline realized with #{@stages.size} stages" }
      end

      # Run all enabled stages, passing the Frame through each one.
      # Renders into ping-pong FBOs, then blits the final result to the GTK framebuffer.
      def execute(frame_buffer : LibGL::GLuint, width : Int32, height : Int32, delta_time : Float32) : Frame
        ensure_ping_pong(width, height)

        frame = Frame.new(@post_process_fbo_a, width, height, delta_time)
        frame.color_texture = @post_process_tex_a
        frame.alt_buffer = @post_process_fbo_b
        frame.alt_texture = @post_process_tex_b

        # Reset cascade data for this frame
        frame.cascade_count = 0
        frame.cascade_matrices.clear

        # Clear the initial render target
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, @post_process_fbo_a)
        LibGL.glViewport(0, 0, width, height)
        LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)

        @stages.each do |stage|
          next unless stage.enabled

          frame = stage.call(@context, frame)

          break if frame.consumed
        end

        # Final blit from active ping-pong FBO to GTK's framebuffer
        LibGL.glBindFramebuffer(LibGL::GL_READ_FRAMEBUFFER, frame.buffer)
        LibGL.glBindFramebuffer(LibGL::GL_DRAW_FRAMEBUFFER, frame_buffer)
        LibGL.glBlitFramebuffer(0, 0, width, height, 0, 0, width, height,
          LibGL::GL_COLOR_BUFFER_BIT, LibGL::GL_LINEAR)

        frame
      end

      # Tear down all stages and clear the pipeline
      def teardown
        @stages.each(&.teardown)
        @stages.clear
        cleanup_ping_pong
        @realized = false
      end

      # Debug helper: list stage names and their enabled state
      def describe : Array({String, Bool})
        @stages.map { |s| {s.name, s.enabled} }
      end

      # Debug helper: list stage names in order
      def stage_names : Array(String)
        @stages.map(&.name)
      end

      private def ensure_ping_pong(width : Int32, height : Int32)
        return if width == @post_process_width && height == @post_process_height && @post_process_fbo_a != 0
        cleanup_ping_pong if @post_process_fbo_a != 0
        @post_process_width = width
        @post_process_height = height
        create_ping_pong_fbo(pointerof(@post_process_fbo_a), pointerof(@post_process_tex_a), pointerof(@post_process_depth_a), width, height)
        create_ping_pong_fbo(pointerof(@post_process_fbo_b), pointerof(@post_process_tex_b), pointerof(@post_process_depth_b), width, height)
      end

      private def create_ping_pong_fbo(fbo : LibGL::GLuint*, texture : LibGL::GLuint*, depth : LibGL::GLuint*, w : Int32, h : Int32)
        LibGL.glGenFramebuffers(1, fbo)
        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, fbo.value)

        # Color attachment
        LibGL.glGenTextures(1, texture)
        LibGL.glBindTexture(LibGL::GL_TEXTURE_2D, texture.value)
        LibGL.glTexImage2D(LibGL::GL_TEXTURE_2D, 0, LibGL::GL_RGBA16F.to_i32, w, h, 0,
          LibGL::GL_RGBA, LibGL::GL_FLOAT, Pointer(Void).null)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MIN_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_MAG_FILTER, LibGL::GL_LINEAR.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_S, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glTexParameteri(LibGL::GL_TEXTURE_2D, LibGL::GL_TEXTURE_WRAP_T, LibGL::GL_CLAMP_TO_EDGE.to_i32)
        LibGL.glFramebufferTexture2D(LibGL::GL_FRAMEBUFFER, LibGL::GL_COLOR_ATTACHMENT0, LibGL::GL_TEXTURE_2D, texture.value, 0)

        # Depth attachment (renderbuffer — needed for geometry, particles, skybox)
        LibGL.glGenRenderbuffers(1, depth)
        LibGL.glBindRenderbuffer(LibGL::GL_RENDERBUFFER, depth.value)
        LibGL.glRenderbufferStorage(LibGL::GL_RENDERBUFFER, LibGL::GL_DEPTH_COMPONENT24, w, h)
        LibGL.glFramebufferRenderbuffer(LibGL::GL_FRAMEBUFFER, LibGL::GL_DEPTH_ATTACHMENT, LibGL::GL_RENDERBUFFER, depth.value)

        LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, 0)
      end

      private def cleanup_ping_pong
        LibGL.glDeleteFramebuffers(1, pointerof(@post_process_fbo_a)) if @post_process_fbo_a != 0
        LibGL.glDeleteFramebuffers(1, pointerof(@post_process_fbo_b)) if @post_process_fbo_b != 0
        LibGL.glDeleteTextures(1, pointerof(@post_process_tex_a)) if @post_process_tex_a != 0
        LibGL.glDeleteTextures(1, pointerof(@post_process_tex_b)) if @post_process_tex_b != 0
        LibGL.glDeleteRenderbuffers(1, pointerof(@post_process_depth_a)) if @post_process_depth_a != 0
        LibGL.glDeleteRenderbuffers(1, pointerof(@post_process_depth_b)) if @post_process_depth_b != 0
        @post_process_fbo_a = 0_u32
        @post_process_fbo_b = 0_u32
        @post_process_tex_a = 0_u32
        @post_process_tex_b = 0_u32
        @post_process_depth_a = 0_u32
        @post_process_depth_b = 0_u32
        @post_process_width = 0
        @post_process_height = 0
      end
    end
  end
end
