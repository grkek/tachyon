module Tachyon
  # Manages a GTK GL area, camera, scene, and the rendering pipeline
  class Viewport
    Log = ::Log.for(self)

    getter id : String
    getter area : Gtk::GLArea
    getter scene : Scene::Graph
    getter camera : Renderer::Camera
    getter light_manager : Renderer::LightManager
    getter pipeline : Rendering::Pipeline
    getter cursor : Scripting::Cursor? = nil
    getter audio_engine : Audio::Engine? = nil

    @last_frame_time : Time = Time.utc
    @realized : Bool = false
    @before_render : Proc(Float64, Nil)? = nil

    def initialize(@id : String, @area : Gtk::GLArea = Gtk::GLArea.new)
      @scene = Scene::Graph.new
      @camera = create_camera
      @light_manager = Renderer::LightManager.new

      context = Rendering::Context.new(@scene, @camera, @light_manager)

      @pipeline = Rendering::Pipeline.new(context)

      add_default_light
      setup_gl_area
    end

    def realized? : Bool
      @realized
    end

    # Typed accessors into pipeline stages for scripting and external use
    def canvas_2d : Renderer::Canvas?
      @pipeline.find_by_type(Rendering::Stages::Canvas).try(&.canvas)
    end

    def gui : Renderer::GraphicalUserInterface?
      @pipeline.find_by_type(Rendering::Stages::Overlay).try(&.gui)
    end

    def particle_system : Renderer::ParticleSystem?
      @pipeline.find_by_type(Rendering::Stages::Particles).try(&.particle_system)
    end

    def post_process : Renderer::PostProcess?
      @pipeline.find_by_type(Rendering::Stages::PostProcess).try(&.post_process)
    end

    # Hook called before each render with delta time
    def on_before_render(&block : Float64 -> Nil)
      @before_render = block
    end

    # Push GUI draw calls into the rendering context
    def submit_commands(commands : Array(Scripting::GUI::DrawCall))
      @pipeline.context.commands = commands
    end

    def destroy
      return unless @realized
      @area.make_current

      @scene.destroy
      @pipeline.teardown
      @audio_engine.try(&.destroy)

      @realized = false
    end

    private def create_camera : Renderer::Camera
      cfg = Configuration.instance.camera
      camera = Renderer::Camera.new(
        field_of_view: cfg.field_of_view,
        near_plane: cfg.near_plane,
        far_plane: cfg.far_plane
      )
      camera.position = cfg.default_camera_position
      camera.target = cfg.default_camera_target
      camera
    end

    private def add_default_light
      cfg = Configuration.instance.light
      directional = Renderer::Light.new(
        type: Renderer::Light::Type::Directional,
        direction: cfg.direction,
        color: cfg.color,
        intensity: cfg.intensity
      )
      @light_manager.add(directional)
    end

    private def setup_gl_area
      @area.set_required_version(3, 3)
      @area.auto_render = false
      @area.has_depth_buffer = true
      @area.focusable = true

      @area.realize_signal.connect { on_realize }
      @area.unrealize_signal.connect { destroy }
      @area.render_signal.connect { |context| on_render }
      @area.add_tick_callback(->tick_callback(Gtk::Widget, Gdk::FrameClock))
    end

    private def on_realize
      return if @realized
      @area.make_current
      return if @area.error

      setup_gl_defaults

      # Audio lives outside the pipeline
      @audio_engine = Audio::Engine.new

      # Build and realize the default pipeline
      build_default_pipeline
      @pipeline.setup

      @cursor = Scripting::Cursor.new(@area)
      @last_frame_time = Time.utc
      @realized = true

      Log.info { "Viewport '#{@id}' realized with #{@pipeline.stages.size} stages" }
    end

    private def setup_gl_defaults
      LibGL.glEnable(LibGL::GL_DEPTH_TEST)
      LibGL.glEnable(LibGL::GL_CULL_FACE)
      LibGL.glCullFace(LibGL::GL_BACK)
      LibGL.glFrontFace(LibGL::GL_CCW)
      LibGL.glClearColor(0.0f32, 0.0f32, 0.0f32, 1.0f32)
    end

    # Assemble the default 3D rendering pipeline with all stages
    private def build_default_pipeline
      @pipeline.add(Rendering::Stages::Canvas.new)
      @pipeline.add(Rendering::Stages::Shadow.new)
      @pipeline.add(Rendering::Stages::SSAO.new)
      @pipeline.add(Rendering::Stages::Geometry.new)
      @pipeline.add(Rendering::Stages::Skybox.new)
      @pipeline.add(Rendering::Stages::Particles.new)
      @pipeline.add(Rendering::Stages::PostProcess.new)
      @pipeline.add(Rendering::Stages::Vignette.new)
      @pipeline.add(Rendering::Stages::ChromaticAberration.new)
      @pipeline.add(Rendering::Stages::ColorGrading.new)
      @pipeline.add(Rendering::Stages::Overlay.new)
    end

    private def on_render : Bool
      return true unless @realized

      now = Time.utc
      dt = (now - @last_frame_time).total_seconds
      @last_frame_time = now

      # Update camera aspect for current viewport size
      scale = @area.scale_factor
      w = @area.width * scale
      h = @area.height * scale
      @camera.scale_factor = scale
      @camera.update_aspect(w, h) if h > 0

      # Update audio listener to match camera
      if ae = @audio_engine
        direction = (@camera.target - @camera.position).normalize
        ae.update_listener(@camera.position, direction)
      end

      @before_render.try(&.call(dt))

      # Capture GTK's framebuffer and run the pipeline
      frame_buffer = 0_u32
      LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(frame_buffer).as(Pointer(Int32)))
      @pipeline.execute(frame_buffer, w, h, dt.to_f32)

      true
    end

    private def tick_callback(_widget : Gtk::Widget, _clock : Gdk::FrameClock) : Bool
      @area.queue_render
      true
    end
  end
end
