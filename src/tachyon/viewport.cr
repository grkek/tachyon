module Tachyon
  class Viewport
    Log = ::Log.for(self)

    getter id : String
    getter area : Gtk::GLArea
    getter scene : Scene::Graph
    getter camera : Renderer::Camera
    getter light_manager : Renderer::LightManager

    @shader : Renderer::Shader? = nil
    @default_texture : Renderer::Texture? = nil
    @shadow_map : Renderer::ShadowMap? = nil
    @post_process : Renderer::PostProcess? = nil
    @skybox : Renderer::Skybox? = nil
    @canvas_2d : Renderer::Canvas? = nil
    @gui : Renderer::GraphicalUserInterface? = nil
    @audio : Audio::Engine? = nil
    @commands : Array(Scripting::GUI::DrawCall)? = nil
    @viewport_width : Int32 = 800
    @viewport_height : Int32 = 600
    @last_frame_time : Time = Time.utc
    @realized : Bool = false
    @before_render : Proc(Float64, Nil)? = nil

    def initialize(@id : String, @area : Gtk::GLArea)
      @scene = Scene::Graph.new
      @camera = Renderer::Camera.new(field_of_view: 60.0f32, near_plane: 0.1f32, far_plane: 100.0f32)
      @camera.position = Math::Vector3.new(0.0f32, 3.0f32, 6.0f32)
      @camera.target = Math::Vector3.new(0.0f32, 0.5f32, 0.0f32)
      @light_manager = Renderer::LightManager.new
      add_default_light
      setup_gl_area
    end

    def initialize(@id : String)
      @area = Gtk::GLArea.new
      @scene = Scene::Graph.new
      @camera = Renderer::Camera.new(field_of_view: 60.0f32, near_plane: 0.1f32, far_plane: 100.0f32)
      @camera.position = Math::Vector3.new(0.0f32, 3.0f32, 6.0f32)
      @camera.target = Math::Vector3.new(0.0f32, 0.5f32, 0.0f32)
      @light_manager = Renderer::LightManager.new
      add_default_light
      setup_gl_area
    end

    def realized? : Bool
      @realized
    end

    def canvas_2d : Renderer::Canvas?
      @canvas_2d
    end

    def gui : Renderer::GraphicalUserInterface?
      @gui
    end

    def audio : Audio::Engine?
      @audio
    end

    def on_before_render(&block : Float64 -> Nil)
      @before_render = block
    end

    def submit_commands(commands : Array(Scripting::GUI::DrawCall))
      @commands = commands
    end

    def destroy
      return unless @realized
      @area.make_current

      @scene.destroy
      @shader.try(&.destroy)
      @shadow_map.try(&.destroy)
      @skybox.try(&.destroy)
      @post_process.try(&.destroy)
      @gui.try(&.destroy)
      @canvas_2d.try(&.destroy)
      @default_texture.try(&.destroy)
      @audio.try(&.destroy)

      @shader = nil
      @shadow_map = nil
      @skybox = nil
      @post_process = nil
      @gui = nil
      @canvas_2d = nil
      @default_texture = nil
      @audio = nil
      @realized = false
    end

    private def add_default_light
      dir_light = Renderer::Light.new(
        type: Renderer::Light::Type::Directional,
        direction: Math::Vector3.new(0.5f32, -1.0f32, -0.5f32),
        color: Math::Vector3.new(1.0f32, 0.95f32, 0.9f32),
        intensity: 2.0f32
      )
      @light_manager.add(dir_light)
    end

    private def setup_gl_area
      @area.set_required_version(3, 3)
      @area.auto_render = false
      @area.has_depth_buffer = true
      @area.focusable = true

      @area.realize_signal.connect { on_realize }
      @area.unrealize_signal.connect { destroy }
      @area.render_signal.connect { |ctx| on_render }
      @area.add_tick_callback(->tick_callback(Gtk::Widget, Gdk::FrameClock))
    end

    private def on_realize
      return if @realized
      @area.make_current
      return if @area.error

      LibGL.glEnable(LibGL::GL_DEPTH_TEST)
      LibGL.glEnable(LibGL::GL_CULL_FACE)
      LibGL.glCullFace(LibGL::GL_BACK)
      LibGL.glFrontFace(LibGL::GL_CCW)
      LibGL.glClearColor(0.0f32, 0.0f32, 0.0f32, 1.0f32)

      @shader = Renderer::Shader.new(
        Constants::VERTEX_SHADER_SOURCE,
        Constants::FRAGMENT_SHADER_SOURCE
      )

      @default_texture = Renderer::Texture.solid_color(255_u8, 255_u8, 255_u8, 255_u8)
      @shadow_map = Renderer::ShadowMap.new(width: 4096, height: 4096)
      @post_process = Renderer::PostProcess.new
      @canvas_2d = Renderer::Canvas.new
      @gui = Renderer::GraphicalUserInterface.new
      @audio = Audio::Engine.new

      skybox = Renderer::Skybox.new
      skybox.generate_gradient(
        Math::Vector3.new(0.4f32, 0.6f32, 0.9f32),
        Math::Vector3.new(0.9f32, 0.85f32, 0.7f32)
      )
      @skybox = skybox

      @last_frame_time = Time.utc
      @realized = true
    end

    private def on_render : Bool
      return true unless @realized

      shader = @shader
      return true unless shader

      now = Time.utc
      dt = (now - @last_frame_time).total_seconds
      @last_frame_time = now

      update_viewport

      if callback = @before_render
        callback.call(dt)
      end

      if canvas = @canvas_2d
        if canvas.active
          render_2d_scene(canvas)
          render_2d_overlay(canvas)
          return true
        end
      end

      gtk_fbo = save_gtk_fbo
      light_space_matrix = render_shadow_pass
      render_main_pass(shader, light_space_matrix)
      render_skybox

      if post = @post_process
        post.apply(gtk_fbo, @viewport_width, @viewport_height)
      end

      render_3d_overlay

      true
    end

    private def update_viewport
      @viewport_width = @area.width
      @viewport_height = @area.height
      scale = @area.scale_factor
      @viewport_width *= scale
      @viewport_height *= scale
      @camera.scale_factor = scale
      @camera.update_aspect(@viewport_width, @viewport_height) if @viewport_height > 0
    end

    private def save_gtk_fbo : Int32
      gtk_fbo = 0_i32
      LibGL.glGetIntegerv(LibGL::GL_FRAMEBUFFER_BINDING, pointerof(gtk_fbo))
      gtk_fbo
    end

    private def render_2d_scene(canvas : Renderer::Canvas)
      canvas.render(@viewport_width, @viewport_height)
    end

    private def render_2d_overlay(canvas : Renderer::Canvas)
      commands = @commands
      return unless commands
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

    private def render_3d_overlay
      gui = @gui
      commands = @commands
      return unless gui
      return unless commands
      return if commands.empty?

      gui.begin_frame(@viewport_width, @viewport_height)

      commands.each do |cmd|
        case cmd.command
        when Scripting::GUI::Command::Rect
          gui.draw_rect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.r, cmd.g, cmd.b, cmd.a)
        when Scripting::GUI::Command::Text
          gui.draw_text(cmd.text, cmd.x, cmd.y, cmd.scale, cmd.r, cmd.g, cmd.b, cmd.a)
        end
      end

      gui.end_frame
    end

    private def render_shadow_pass : Math::Matrix4
      light_space_matrix = Math::Matrix4.identity

      if shadow_map = @shadow_map
        if dir = @light_manager.directional
          focus = @camera.target
          distance = (@camera.position - @camera.target).magnitude
          radius = ::Math.max(distance * 2.0f32, 50.0f32)
          light_space_matrix = dir.shadow_view_projection(focus, radius)
          shadow_map.begin_pass(light_space_matrix)

          @scene.each_renderable do |node|
            shadow_map.render_node(node)
          end

          shadow_map.end_pass
        end
      end

      light_space_matrix
    end

    private def render_main_pass(shader : Renderer::Shader, light_space_matrix : Math::Matrix4)
      LibGL.glViewport(0, 0, @viewport_width, @viewport_height)
      LibGL.glClear(LibGL::GL_COLOR_BUFFER_BIT | LibGL::GL_DEPTH_BUFFER_BIT)

      shader.use
      shader.set_matrix4("uView", @camera.view_matrix)
      shader.set_matrix4("uProjection", @camera.projection_matrix)
      shader.set_vector3("uViewPos", @camera.position)
      shader.set_vector3("uAmbientColor", Math::Vector3.new(0.15f32, 0.15f32, 0.18f32))
      shader.set_matrix4("uLightSpaceMatrix", light_space_matrix)

      @light_manager.apply(shader)

      if shadow_map = @shadow_map
        shadow_map.bind_texture(5)
        shader.set_int("uShadowMap", 5)
        shader.set_int("uHasShadowMap", 1)
      else
        shader.set_int("uHasShadowMap", 0)
      end

      render_opaque(shader)
      render_transparent(shader)
    end

    private def render_opaque(shader : Renderer::Shader)
      @scene.each_renderable do |node|
        mat = node.material
        next if mat && mat.opacity < 1.0f32
        render_node(shader, node, mat)
      end
      LibGL.glPolygonMode(LibGL::GL_FRONT_AND_BACK, LibGL::GL_FILL)
    end

    private def render_transparent(shader : Renderer::Shader)
      LibGL.glEnable(LibGL::GL_BLEND)
      LibGL.glBlendFunc(LibGL::GL_SRC_ALPHA, LibGL::GL_ONE_MINUS_SRC_ALPHA)
      LibGL.glDepthMask(LibGL::GL_FALSE)

      @scene.each_renderable do |node|
        mat = node.material
        next unless mat && mat.opacity < 1.0f32
        render_node(shader, node, mat)
      end

      LibGL.glPolygonMode(LibGL::GL_FRONT_AND_BACK, LibGL::GL_FILL)
      LibGL.glDepthMask(LibGL::GL_TRUE)
      LibGL.glDisable(LibGL::GL_BLEND)
    end

    private def render_node(shader : Renderer::Shader, node : Scene::Node, mat : Renderer::Material?)
      shader.set_matrix4("uModel", node.world_matrix)
      shader.set_matrix4("uNormalMatrix", node.world_normal_matrix)

      if default_texture = @default_texture
        (0..4).each { |i| default_texture.bind(i) }
      end

      if mat
        LibGL.glPolygonMode(LibGL::GL_FRONT_AND_BACK, mat.wireframe ? LibGL::GL_LINE : LibGL::GL_FILL)
        mat.apply(shader)
      end

      if mesh = node.mesh
        mesh.draw
      end
    end

    private def render_skybox
      if skybox = @skybox
        skybox.render(@camera.view_matrix, @camera.projection_matrix)
      end
    end

    private def tick_callback(_widget : Gtk::Widget, _clock : Gdk::FrameClock) : Bool
      @area.queue_render
      true
    end
  end
end
