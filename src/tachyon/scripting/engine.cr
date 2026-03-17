module Tachyon
  module Scripting
    class Engine
      Log = ::Log.for(self)

      alias QuickJS = Medusa::Binding::QuickJS

      getter registry : HandleRegistry
      getter input_state : InputState
      getter commands : Array(GUI::DrawCall) = [] of GUI::DrawCall
      property cursor : Cursor? = nil

      @scene : Scene::Graph
      @camera : Renderer::Camera
      @light_manager : Renderer::LightManager
      @canvas : Renderer::Canvas? = nil
      @audio : Audio::Engine? = nil
      @module_definition : QuickJS::JSModuleDef = Pointer(Void).null
      @module_namespace : QuickJS::JSValue = QuickJS::JSValue.new
      @has_module_namespace : Bool = false
      @context : QuickJS::JSContext = Pointer(Void).null

      def initialize(@scene : Scene::Graph, @camera : Renderer::Camera, @light_manager : Renderer::LightManager)
        @registry = HandleRegistry.new
        @input_state = InputState.new
      end

      def audio : Audio::Engine?
        @audio
      end

      def audio=(@audio : Audio::Engine?)
      end

      def register(context : Medusa::Context)
        @context = context.to_unsafe

        LibTachyonBridge.TachyonBridge_InitClasses(context.runtime)

        @module_definition = LibTachyonBridge.TachyonBridge_RegisterModule(@context)
        register_callbacks
      end

      def bind(context : Medusa::Context)
        @context = context.to_unsafe
        register_callbacks
      end

      def adopt_module(namespace : QuickJS::JSValue)
        @module_namespace = namespace
        @has_module_namespace = true
      end

      def load_script(context : Medusa::Context, source : String, filename : String = "game.js")
        result = QuickJS.JS_Eval(@context, source, source.bytesize, filename,
          (QuickJS::EvalFlag::MODULE | QuickJS::EvalFlag::COMPILE_ONLY).value)

        game_module = result.u.ptr.as(QuickJS::JSModuleDef)
        QuickJS.JS_EvalFunction(@context, result)

        @module_namespace = QuickJS.JS_GetModuleNamespace(@context, game_module)
        @has_module_namespace = true
      end

      def call_on_start
        return unless @has_module_namespace
        LibTachyonBridge.TachyonBridge_CallOnStart(@context, @module_namespace)
      end

      def call_on_update(dt : Float64)
        return unless @has_module_namespace
        LibTachyonBridge.TachyonBridge_CallOnUpdate(@context, @module_namespace, dt)
        @input_state.begin_frame
      end

      def call_on_fixed_update(dt : Float64)
        return unless @has_module_namespace
        LibTachyonBridge.TachyonBridge_CallOnFixedUpdate(@context, @module_namespace, dt)
      end

      def canvas : Renderer::Canvas?
        @canvas
      end

      def canvas=(@canvas : Renderer::Canvas?)
      end

      def destroy
        if @has_module_namespace
          QuickJS.FreeValue(@context, @module_namespace)
          @has_module_namespace = false
        end
        @registry.clear
      end

      # Register a proc as a callback, extracting pointer + closure_data
      private def set_callback(slot : CallbackSlot, proc)
        LibTachyonBridge.TachyonBridge_SetCallback(
          slot.value,
          proc.pointer,
          proc.closure_data
        )
      end

      private def register_callbacks
        scene = @scene
        registry = @registry
        camera = @camera
        input_state = @input_state

        # Geometry constructors
        set_callback(CallbackSlot::CreateCube, ->(w : Float32, h : Float32, d : Float32) {
          verts, idx = Geometry::Cube.generate(w, h, d)
          node = Scene::Node.new
          node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
          node.material = Renderer::Material.new
          registry.store_node(node)
        })

        set_callback(CallbackSlot::CreateSphere, ->(r : Float32, seg : Int32, rings : Int32) {
          verts, idx = Geometry::Sphere.generate(r, seg, rings)
          node = Scene::Node.new
          node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
          node.material = Renderer::Material.new
          registry.store_node(node)
        })

        set_callback(CallbackSlot::CreatePlane, ->(w : Float32, h : Float32) {
          verts, idx = Geometry::Plane.generate(w, h)
          node = Scene::Node.new
          node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
          node.material = Renderer::Material.new
          registry.store_node(node)
        })

        set_callback(CallbackSlot::CreateCylinder, ->(r : Float32, h : Float32, seg : Int32) {
          verts, idx = Geometry::Cylinder.generate(r, h, seg)
          node = Scene::Node.new
          node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
          node.material = Renderer::Material.new
          registry.store_node(node)
        })

        set_callback(CallbackSlot::CreateCone, ->(r : Float32, h : Float32, seg : Int32) {
          verts, idx = Geometry::Cone.generate(r, h, seg)
          node = Scene::Node.new
          node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
          node.material = Renderer::Material.new
          registry.store_node(node)
        })

        set_callback(CallbackSlot::CreateTorus, ->(major : Float32, minor : Float32, seg : Int32) {
          verts, idx = Geometry::Torus.generate(major, minor, seg, 16)
          node = Scene::Node.new
          node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
          node.material = Renderer::Material.new
          registry.store_node(node)
        })

        set_callback(CallbackSlot::LoadMesh, ->(path : LibC::Char*) {
          cr_path = String.new(path)
          begin
            verts, idx = Geometry::OBJLoader.load(cr_path)
            node = Scene::Node.new
            node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
            node.material = Renderer::Material.new
            registry.store_node(node)
          rescue
            0_u32
          end
        })

        # Scene
        set_callback(CallbackSlot::SceneAdd, ->(handle : UInt32) {
          node = registry.get_node(handle)
          scene.add(node) if node
        })

        set_callback(CallbackSlot::SceneRemove, ->(handle : UInt32) {
          node = registry.get_node(handle)
          scene.remove(node) if node
        })

        set_callback(CallbackSlot::SceneFind, ->(name : LibC::Char*) {
          cr_name = String.new(name)
          found = scene.find(cr_name)
          found ? registry.store_node(found) : 0_u32
        })

        set_callback(CallbackSlot::SceneClear, -> {
          scene.clear
          registry.clear
        })

        set_callback(CallbackSlot::ScenePick, ->(screen_x : Float32, screen_y : Float32) {
          sf = camera.scale_factor

          logical_w = camera.viewport_width // sf
          logical_h = camera.viewport_height // sf

          ray = camera.screen_to_ray(screen_x, screen_y, logical_w, logical_h)

          closest_handle = 0_u32
          closest_dist = Float32::MAX

          candidates = [] of {Scene::Node, Float32}

          scene.each_renderable do |node|
            aabb = node.world_aabb

            if t = ray.intersects_aabb?(aabb)
              candidates << {node, t}
            end
          end

          candidates.sort_by! { |c| c[1] }

          candidates.each do |node, aabb_t|
            break if aabb_t > closest_dist

            if t = node.raycast(ray)
              if t < closest_dist
                closest_dist = t
                closest_handle = registry.find_handle(node)
              end
            end
          end

          closest_handle
        })

        # Node properties
        set_callback(CallbackSlot::NodeSetPosition, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.position = Math::Vector3.new(x, y, z) if node
        })

        set_callback(CallbackSlot::NodeGetPosition, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          node = registry.get_node(h)

          if node
            position = node.transform.position

            x.value = position.x
            y.value = position.y
            z.value = position.z
          end
        })

        set_callback(CallbackSlot::NodeSetRotation, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)

          if node
            node.transform.rotation = Math::Quaternion.from_euler(
              Math.to_radians(x), Math.to_radians(y), Math.to_radians(z)
            )
          end
        })

        set_callback(CallbackSlot::NodeGetRotation, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          x.value = 0.0f32
          y.value = 0.0f32
          z.value = 0.0f32
        })

        set_callback(CallbackSlot::NodeSetScale, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.scale = Math::Vector3.new(x, y, z) if node
        })

        set_callback(CallbackSlot::NodeGetScale, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          node = registry.get_node(h)

          if node
            scale = node.transform.scale

            x.value = scale.x
            y.value = scale.y
            z.value = scale.z
          end
        })

        set_callback(CallbackSlot::NodeSetName, ->(h : UInt32, name : LibC::Char*) {
          node = registry.get_node(h)
          node.name = String.new(name) if node
        })

        set_callback(CallbackSlot::NodeSetVisible, ->(h : UInt32, visible : Int32) {
          node = registry.get_node(h)
          node.visible = visible != 0 if node
        })

        set_callback(CallbackSlot::NodeGetVisible, ->(h : UInt32) {
          node = registry.get_node(h)
          node ? (node.visible ? 1 : 0) : 0
        })

        set_callback(CallbackSlot::NodeRotate, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.rotate(x, y, z) if node
        })

        set_callback(CallbackSlot::NodeTranslate, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.translate(x, y, z) if node
        })

        set_callback(CallbackSlot::NodeLookAt, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.look_at(Math::Vector3.new(x, y, z)) if node
        })

        set_callback(CallbackSlot::NodeDestroy, ->(h : UInt32) {
          node = registry.get_node(h)

          if node
            node.destroy
            scene.remove(node)
            registry.release(h)
          end
        })

        # Material
        set_callback(CallbackSlot::NodeSetMaterialColor, ->(h : UInt32, r : Float32, g : Float32, b : Float32) {
          node = registry.get_node(h)

          if node
            material = node.material

            if material
              material.color = Math::Vector3.new(r, g, b)
            else
              node.material = Renderer::Material.new(albedo: Math::Vector3.new(r, g, b))
            end
          end
        })

        set_callback(CallbackSlot::NodeSetMaterialRoughness, ->(h : UInt32, val : Float32) {
          node = registry.get_node(h)
          node.material.try { |m| m.roughness = val } if node
        })

        set_callback(CallbackSlot::NodeSetMaterialMetallic, ->(h : UInt32, val : Float32) {
          node = registry.get_node(h)
          node.material.try { |m| m.metallic = val } if node
        })

        set_callback(CallbackSlot::NodeSetWireframe, ->(h : UInt32, wireframe : Int32) {
          node = registry.get_node(h)
          if node && node.material
            node.material.not_nil!.wireframe = wireframe != 0
          end
        })

        set_callback(CallbackSlot::NodeSetMaterialOpacity, ->(h : UInt32, val : Float32) {
          # TODO
        })

        # Input
        set_callback(CallbackSlot::InputKeyDown, ->(key : LibC::Char*) {
          input_state.key_down?(String.new(key)) ? 1 : 0
        })

        set_callback(CallbackSlot::InputKeyPressed, ->(key : LibC::Char*) {
          input_state.key_pressed?(String.new(key)) ? 1 : 0
        })

        set_callback(CallbackSlot::InputKeyReleased, ->(key : LibC::Char*) {
          input_state.key_released?(String.new(key)) ? 1 : 0
        })

        set_callback(CallbackSlot::InputMouseButtonDown, ->(btn : Int32) {
          input_state.mouse_button_down?(btn) ? 1 : 0
        })

        set_callback(CallbackSlot::InputMouseButtonPressed, ->(btn : Int32) {
          input_state.mouse_button_pressed?(btn) ? 1 : 0
        })

        set_callback(CallbackSlot::InputMousePosition, ->(x : Float32*, y : Float32*) {
          mx, my = input_state.mouse_position
          x.value = mx
          y.value = my
        })

        set_callback(CallbackSlot::InputMouseDelta, ->(dx : Float32*, dy : Float32*) {
          mdx, mdy = input_state.mouse_delta
          dx.value = mdx
          dy.value = mdy
        })

        cursor = @cursor
        input_state = @input_state

        set_callback(CallbackSlot::InputLockCursor, -> {
          if c = cursor
            c.lock(input_state)
          end
        })

        set_callback(CallbackSlot::InputUnlockCursor, -> {
          if c = cursor
            c.unlock
          end
        })

        # GUI
        commands = @commands

        set_callback(CallbackSlot::GUIDrawRect, ->(x : Float32, y : Float32, w : Float32, h : Float32, r : Float32, g : Float32, b : Float32, a : Float32) {
          call = GUI::DrawCall.new
          call.command = GUI::Command::Rect
          call.x = x; call.y = y; call.w = w; call.h = h
          call.r = r; call.g = g; call.b = b; call.a = a
          commands << call
        })

        set_callback(CallbackSlot::GUIDrawText, ->(text_ptr : LibC::Char*, x : Float32, y : Float32, scale : Float32, r : Float32, g : Float32, b : Float32, a : Float32) {
          call = GUI::DrawCall.new
          call.command = GUI::Command::Text
          call.text = String.new(text_ptr)
          call.x = x; call.y = y; call.scale = scale
          call.r = r; call.g = g; call.b = b; call.a = a
          commands << call
        })

        set_callback(CallbackSlot::GUIClear, -> {
          commands.clear
        })

        # Canvas
        canvas_ref = @canvas

        set_callback(CallbackSlot::CanvasSetup, ->(w : Float32, h : Float32) {
          if canvas = canvas_ref
            canvas.setup(w, h)
          end

          0_u32
        })

        set_callback(CallbackSlot::CanvasBackground, ->(handle : UInt32, r : Float32, g : Float32, b : Float32) {
          if canvas = canvas_ref
            canvas.background(r, g, b)
          end
        })

        set_callback(CallbackSlot::CanvasText, ->(text_ptr : LibC::Char*, x : Float32, y : Float32, scale : Float32, r : Float32, g : Float32, b : Float32, a : Float32) {
          if canvas = canvas_ref
            call = GUI::DrawCall.new

            call.command = GUI::Command::Text
            call.text = String.new(text_ptr)

            call.x = x; call.y = y; call.scale = scale
            call.r = r; call.g = g; call.b = b; call.a = a

            commands << call
          end
        })

        # Sprite
        set_callback(CallbackSlot::SpriteCreate, ->(w : Float32, h : Float32) {
          sprite = Renderer::Sprite.new(w, h)

          if canvas = canvas_ref
            canvas.add_sprite(sprite)
          end

          registry.store_sprite(sprite)
        })

        set_callback(CallbackSlot::SpriteLoad, ->(path : LibC::Char*) {
          begin
            sprite = Renderer::Sprite.from_texture(String.new(path))

            if canvas = canvas_ref
              canvas.add_sprite(sprite)
            end

            registry.store_sprite(sprite)
          rescue
            0_u32
          end
        })

        set_callback(CallbackSlot::SpriteSetPosition, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          sprite = registry.get_sprite(h)

          if sprite
            sprite.x = x
            sprite.y = y
          end
        })

        set_callback(CallbackSlot::SpriteGetPosition, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          sprite = registry.get_sprite(h)

          if sprite
            x.value = sprite.x
            y.value = sprite.y
          end
        })

        set_callback(CallbackSlot::SpriteSetColor, ->(h : UInt32, r : Float32, g : Float32, b : Float32) {
          sprite = registry.get_sprite(h)

          if sprite
            sprite.r = r; sprite.g = g; sprite.b = b
          end
        })

        set_callback(CallbackSlot::SpriteSetVisible, ->(h : UInt32, visible : Int32) {
          sprite = registry.get_sprite(h)
          sprite.visible = visible != 0 if sprite
        })

        set_callback(CallbackSlot::SpriteSetLayer, ->(h : UInt32, layer : Int32) {
          sprite = registry.get_sprite(h)
          sprite.layer = layer if sprite
        })

        set_callback(CallbackSlot::SpriteDestroy, ->(h : UInt32) {
          sprite = registry.get_sprite(h)

          if sprite
            canvas_ref.try(&.remove_sprite(sprite))
            registry.release(h)
          end
        })

        # Camera
        set_callback(CallbackSlot::CameraSetPosition, ->(handle : UInt32, x : Float32, y : Float32, z : Float32) {
          camera.position = Math::Vector3.new(x, y, z)
        })

        set_callback(CallbackSlot::CameraGetPosition, ->(handle : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          pos = camera.position
          x.value = pos.x
          y.value = pos.y
          z.value = pos.z
        })

        set_callback(CallbackSlot::CameraSetTarget, ->(handle : UInt32, x : Float32, y : Float32, z : Float32) {
          camera.target = Math::Vector3.new(x, y, z)
        })

        set_callback(CallbackSlot::CameraGetTarget, ->(handle : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          t = camera.target
          x.value = t.x
          y.value = t.y
          z.value = t.z
        })

        set_callback(CallbackSlot::CameraSetFOV, ->(handle : UInt32, fov : Float32) {
          camera.field_of_view = fov
        })

        # Light
        light_manager = @light_manager

        set_callback(CallbackSlot::CreatePointLight, ->(x : Float32, y : Float32, z : Float32) {
          light = Renderer::Light.new(
            type: Renderer::Light::Type::Point,
            position: Math::Vector3.new(x, y, z),
            intensity: 1.0f32,
            range: 10.0f32
          )

          light_manager.add(light)
          registry.store_light(light)
        })

        set_callback(CallbackSlot::LightSetPosition, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          light = registry.get_light(h)
          light.position = Math::Vector3.new(x, y, z) if light
        })

        set_callback(CallbackSlot::LightSetColor, ->(h : UInt32, r : Float32, g : Float32, b : Float32) {
          light = registry.get_light(h)
          light.color = Math::Vector3.new(r, g, b) if light
        })

        set_callback(CallbackSlot::LightSetIntensity, ->(h : UInt32, val : Float32) {
          light = registry.get_light(h)
          light.intensity = val if light
        })

        set_callback(CallbackSlot::LightSetRange, ->(h : UInt32, range : Float32) {
          light = registry.get_light(h)
          light.range = range if light
        })

        # Audio
        audio_engine = @audio

        set_callback(CallbackSlot::AudioPlaySound, ->(path : LibC::Char*) {
          if engine = audio_engine
            engine.play(String.new(path))
          end
          0_u32
        })

        set_callback(CallbackSlot::AudioLoadSound, ->(path : LibC::Char*) {
          if engine = audio_engine
            sound = Audio::Sound.new(engine, String.new(path))
            registry.store_sound(sound)
          else
            0_u32
          end
        })

        set_callback(CallbackSlot::AudioStopSound, ->(h : UInt32) {
          sound = registry.get_sound(h)
          sound.try(&.stop) if sound
        })

        set_callback(CallbackSlot::AudioSetVolume, ->(h : UInt32, vol : Float32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.volume = vol } if sound
        })
      end
    end
  end
end
