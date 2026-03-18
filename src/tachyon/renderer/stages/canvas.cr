module Tachyon
  module Rendering
    module Stages
      # Renders the 2D canvas when active, short-circuiting the 3D pipeline
      class Canvas < Base
        Log = ::Log.for(self)

        @canvas : Renderer::Canvas? = nil

        def initialize
          super("canvas")
        end

        def setup(context : Context)
          @canvas = Renderer::Canvas.new
          Log.info { "Canvas 2D pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          canvas = @canvas
          return frame unless canvas

          # Tick sprite animations every frame
          canvas.tick_sprites(frame.delta_time)

          # If canvas is not in active mode, pass through
          return frame unless canvas.active

          # Full 2D mode: render canvas scene and overlay text
          LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
          canvas.render(frame.width, frame.height)
          render_overlay(canvas, context)

          # Short-circuit — no 3D rendering needed
          frame.consumed = true
          frame
        end

        # Expose canvas for scripting
        def canvas : Renderer::Canvas?
          @canvas
        end

        def teardown
          @canvas.try(&.destroy)
          @canvas = nil
        end

        private def render_overlay(canvas : Renderer::Canvas, context : Context)
          commands = context.commands
          return if commands.empty?

          LibGL.glDisable(LibGL::GL_DEPTH_TEST)
          LibGL.glDisable(LibGL::GL_CULL_FACE)
          LibGL.glEnable(LibGL::GL_BLEND)
          LibGL.glBlendFunc(LibGL::GL_SRC_ALPHA, LibGL::GL_ONE_MINUS_SRC_ALPHA)

          commands.each do |cmd|
            case cmd.command
            when Scripting::GUI::Command::Text
              canvas.draw_text(cmd.text, cmd.x, cmd.y, cmd.scale, cmd.r, cmd.g, cmd.b, cmd.a)
            end
          end

          LibGL.glDisable(LibGL::GL_BLEND)
          LibGL.glEnable(LibGL::GL_DEPTH_TEST)
          LibGL.glEnable(LibGL::GL_CULL_FACE)
        end
      end
    end
  end
end
