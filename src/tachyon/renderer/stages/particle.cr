module Tachyon
  module Rendering
    module Stages
      # Updates and renders all active particle emitters
      class Particles < Base
        Log = ::Log.for(self)

        @particle_system : Renderer::ParticleSystem? = nil

        def initialize
          super("particles")
        end

        def setup(context : Context)
          ps = Renderer::ParticleSystem.new
          ps.setup
          @particle_system = ps
          Log.info { "Particle pass initialized" }
        end

        def call(context : Context, frame : Frame) : Frame
          return frame unless Configuration.instance.particle.enabled

          if ps = @particle_system
            ps.update(frame.delta_time)
            LibGL.glBindFramebuffer(LibGL::GL_FRAMEBUFFER, frame.buffer)
            ps.render(context.camera.view_matrix, context.camera.projection_matrix, context.camera.position)
          end

          frame
        end

        # Expose particle system for scripting
        def particle_system : Renderer::ParticleSystem?
          @particle_system
        end

        def teardown
          @particle_system.try(&.destroy)
          @particle_system = nil
        end
      end
    end
  end
end
