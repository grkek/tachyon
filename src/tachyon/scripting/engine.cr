module Tachyon
  module Scripting
    # Bridges the JS runtime to the Crystal engine via C callbacks
    class Engine
      Log = ::Log.for(self)

      alias QuickJS = Medusa::Binding::QuickJS

      getter registry : Registry
      getter input_state : InputState
      getter commands : Array(GUI::DrawCall) = [] of GUI::DrawCall

      property cursor : Cursor? = nil
      property viewport : Viewport? = nil

      @scene : Scene::Graph
      @camera : Renderer::Camera
      @light_manager : Renderer::LightManager
      @canvas : Renderer::Canvas? = nil
      @audio_engine : Audio::Engine? = nil
      @module_definition : QuickJS::JSModuleDef = Pointer(Void).null
      @context_buffer : Pointer(QuickJS::JSContext) = Pointer(QuickJS::JSContext).malloc(1)
      @module_namespace_buffer : Pointer(QuickJS::JSValue) = Pointer(QuickJS::JSValue).malloc(1)
      @has_module_namespace : Bool = false

      def initialize(@scene : Scene::Graph, @camera : Renderer::Camera, @light_manager : Renderer::LightManager)
        @registry = Registry.new
        @input_state = InputState.new
      end

      def audio_engine : Audio::Engine?
        @audio_engine
      end

      def audio_engine=(@audio_engine : Audio::Engine?)
      end

      def canvas : Renderer::Canvas?
        @canvas
      end

      def canvas=(@canvas : Renderer::Canvas?)
      end

      # Register module with the JS runtime
      def register(context : Medusa::Context)
        @context_buffer.value = context.to_unsafe
        LibTachyonBridge.TachyonBridge_InitClasses(context.runtime)
        @module_definition = LibTachyonBridge.TachyonBridge_RegisterModule(@context_buffer.value)
        register_callbacks
      end

      # Re-register callbacks after subsystems are wired
      def bind(context : Medusa::Context)
        @context_buffer.value = context.to_unsafe
        register_callbacks
      end

      # Adopt an evaluated module namespace for calling exports
      def adopt_module(namespace : QuickJS::JSValue)
        QuickJS.DupValue(@context_buffer.value, namespace)
        @module_namespace_buffer.value = namespace
        @has_module_namespace = true
      end

      # Evaluate and adopt a JS module script
      def load_script(context : Medusa::Context, source : String, filename : String = "game.js")
        result = QuickJS.JS_Eval(
          @context_buffer.value, source, source.bytesize, filename,
          (QuickJS::EvalFlag::MODULE | QuickJS::EvalFlag::COMPILE_ONLY).value
        )
        game_module = result.u.ptr.as(QuickJS::JSModuleDef)
        QuickJS.JS_EvalFunction(@context_buffer.value, result)
        namespace = QuickJS.JS_GetModuleNamespace(@context_buffer.value, game_module)
        adopt_module(namespace)
      end

      # Call the JS onStart() export
      def call_on_start
        return unless @has_module_namespace
        result = LibTachyonBridge.TachyonBridge_CallOnStart(@context_buffer.value, @module_namespace_buffer)
        Log.error { "onStart threw a JS exception" } if result == -1
      end

      # Call the JS onUpdate(dt) export
      def call_on_update(dt : Float64)
        return unless @has_module_namespace
        LibTachyonBridge.TachyonBridge_CallOnUpdate(@context_buffer.value, @module_namespace_buffer, dt)
        @input_state.begin_frame
      end

      # Call the JS onFixedUpdate(dt) export
      def call_on_fixed_update(dt : Float64)
        return unless @has_module_namespace
        LibTachyonBridge.TachyonBridge_CallOnFixedUpdate(@context_buffer.value, @module_namespace_buffer, dt)
      end

      def destroy
        if @has_module_namespace
          QuickJS.FreeValue(@context_buffer.value, @module_namespace_buffer.value)
          @has_module_namespace = false
        end
        @registry.clear
      end

      private def set_callback(slot : CallbackSlot, proc)
        LibTachyonBridge.TachyonBridge_SetCallback(slot.value, proc.pointer, proc.closure_data)
      end

      # Register all C callbacks for JS bridge
      private def register_callbacks
        audio_engine = @audio_engine
        camera = @camera
        canvas = @canvas
        commands = @commands
        engine = self
        light_manager = @light_manager
        registry = @registry
        input_state = @input_state
        scene = @scene

        register_geometry_callbacks(registry, scene)
        register_scene_callbacks(registry, scene, camera, engine)
        register_transform_callbacks(registry)
        register_property_callbacks(registry, scene)
        register_material_callbacks(registry)
        register_texture_callbacks(registry)
        register_input_callbacks(input_state, engine)
        register_gui_callbacks(commands)
        register_canvas_callbacks(canvas, commands)
        register_sprite_callbacks(registry, canvas)
        register_camera_callbacks(camera)
        register_light_callbacks(registry, light_manager)
        register_audio_callbacks(registry, audio_engine)
        register_particle_callbacks(registry, engine)
        register_configuration_callbacks(engine)
        register_pipeline_callbacks(engine)
      end

      # Geometry creation callbacks
      private def register_geometry_callbacks(registry, scene)
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
          begin
            verts, idx = Geometry::OBJLoader.load(String.new(path))
            node = Scene::Node.new
            node.mesh = Renderer::Mesh.new(verts, idx, has_uvs: true)
            node.material = Renderer::Material.new
            registry.store_node(node)
          rescue
            0_u32
          end
        })
      end

      # Scene graph manipulation callbacks
      private def register_scene_callbacks(registry, scene, camera, engine)
        set_callback(CallbackSlot::SceneAdd, ->(handle : UInt32) {
          node = registry.get_node(handle)
          scene.add(node) if node
        })

        set_callback(CallbackSlot::SceneRemove, ->(handle : UInt32) {
          node = registry.get_node(handle)
          scene.remove(node) if node
        })

        set_callback(CallbackSlot::SceneFind, ->(name : LibC::Char*) {
          found = scene.find(String.new(name))
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
            if t = ray.intersects_aabb?(node.world_aabb)
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

        set_callback(CallbackSlot::SceneSave, ->(path : LibC::Char*) {
          begin
            Scene::Serializer.save(scene, String.new(path))
          rescue exception
            Log.error { "Failed to save scene: #{exception.message}" }
          end
          0_u32
        })

        set_callback(CallbackSlot::SceneLoadFile, ->(path : LibC::Char*) {
          begin
            Scene::Serializer.load(String.new(path))
            Log.info { "Scene loaded from #{String.new(path)}" }
          rescue exception
            Log.error { "Failed to load scene: #{exception.message}" }
          end
          0_u32
        })

        set_callback(CallbackSlot::SceneLoadEnvironment, ->(path : LibC::Char*) {
          ibl = Renderer::IBL.new
          ibl.load_hdr(String.new(path))

          if ibl.ready?
            if vp = engine.viewport
              vp.pipeline.context.ibl = ibl
            end
          end

          0_u32
        })
      end

      # Node transform callbacks
      private def register_transform_callbacks(registry)
        set_callback(CallbackSlot::NodeSetPosition, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.position = Math::Vector3.new(x, y, z) if node
        })

        set_callback(CallbackSlot::NodeGetPosition, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          node = registry.get_node(h)
          if node
            pos = node.transform.position
            x.value = pos.x; y.value = pos.y; z.value = pos.z
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
          x.value = 0.0f32; y.value = 0.0f32; z.value = 0.0f32
        })

        set_callback(CallbackSlot::NodeSetScale, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          node = registry.get_node(h)
          node.transform.scale = Math::Vector3.new(x, y, z) if node
        })

        set_callback(CallbackSlot::NodeGetScale, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          node = registry.get_node(h)
          if node
            s = node.transform.scale
            x.value = s.x; y.value = s.y; z.value = s.z
          end
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
      end

      # Node property callbacks
      private def register_property_callbacks(registry, scene)
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

        set_callback(CallbackSlot::NodeDestroy, ->(h : UInt32) {
          node = registry.get_node(h)
          if node
            node.destroy
            scene.remove(node)
            registry.release(h)
          end
        })
      end

      # Material property callbacks
      private def register_material_callbacks(registry)
        set_callback(CallbackSlot::NodeSetMaterialColor, ->(h : UInt32, r : Float32, g : Float32, b : Float32) {
          node = registry.get_node(h)
          if node
            mat = node.material
            if mat
              mat.color = Math::Vector3.new(r, g, b)
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
          node = registry.get_node(h)
          node.material.try { |m| m.opacity = val } if node
        })

        set_callback(CallbackSlot::NodeSetMaterialEmissive, ->(h : UInt32, r : Float32, g : Float32, b : Float32) {
          node = registry.get_node(h)
          node.material.try { |m| m.emissive = Math::Vector3.new(r, g, b) } if node
        })

        set_callback(CallbackSlot::NodeSetMaterialEmissiveStrength, ->(h : UInt32, value : Float32) {
          node = registry.get_node(h)
          node.material.try { |m| m.emissive_strength = value } if node
        })
      end

      # Texture loading callbacks
      private def register_texture_callbacks(registry)
        set_callback(CallbackSlot::NodeLoadTexture, ->(handle : UInt32, path : LibC::Char*, slot : Int32) {
          node = registry.get_node(handle)

          if node
            mat = node.material || Renderer::Material.new

            node.material = mat

            begin
              is_color_data = slot == 0 || slot == 4
              texture = Renderer::Texture.load(String.new(path), srgb: is_color_data)
              case slot
              when 0 then mat.albedo_map = texture
              when 1 then mat.normal_map = texture
              when 2 then mat.metallic_roughness_map = texture
              when 3 then mat.ao_map = texture
              when 4 then mat.emissive_map = texture
              end
            rescue ex
              Log.error { "Failed to load texture: #{ex.message}" }
            end
          end
        })

        set_callback(CallbackSlot::NodeSetTextureScale, ->(handle : UInt32, sx : Float32, sy : Float32, _unused : Float32) {
          node = registry.get_node(handle)
          if node && node.material
            node.material.not_nil!.texture_scale_x = sx
            node.material.not_nil!.texture_scale_y = sy
          end
        })
      end

      # Keyboard and mouse input callbacks
      private def register_input_callbacks(input_state, engine)
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
          x.value = mx; y.value = my
        })

        set_callback(CallbackSlot::InputMouseDelta, ->(dx : Float32*, dy : Float32*) {
          mdx, mdy = input_state.mouse_delta
          dx.value = mdx; dy.value = mdy
        })

        set_callback(CallbackSlot::InputLockCursor, -> {
          if cr = engine.viewport.try(&.cursor)
            cr.lock(input_state)
          end
        })

        set_callback(CallbackSlot::InputUnlockCursor, -> {
          if cr = engine.viewport.try(&.cursor)
            cr.unlock
          end
        })
      end

      # GUI draw call callbacks
      private def register_gui_callbacks(commands)
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
      end

      # 2D canvas callbacks
      private def register_canvas_callbacks(canvas, commands)
        set_callback(CallbackSlot::CanvasSetup, ->(w : Float32, h : Float32) {
          canvas.try(&.setup(w, h))
          0_u32
        })

        set_callback(CallbackSlot::CanvasBackground, ->(handle : UInt32, r : Float32, g : Float32, b : Float32) {
          canvas.try(&.background(r, g, b))
        })

        set_callback(CallbackSlot::CanvasText, ->(text_ptr : LibC::Char*, x : Float32, y : Float32, scale : Float32, r : Float32, g : Float32, b : Float32, a : Float32) {
          if cv = canvas
            call = GUI::DrawCall.new
            call.command = GUI::Command::Text
            call.text = String.new(text_ptr)
            call.x = x; call.y = y; call.scale = scale
            call.r = r; call.g = g; call.b = b; call.a = a
            commands << call
          end
        })
      end

      # Sprite creation and manipulation callbacks
      private def register_sprite_callbacks(registry, canvas)
        set_callback(CallbackSlot::SpriteCreate, ->(w : Float32, h : Float32) {
          sprite = Renderer::Sprite.new(w, h)
          canvas.try(&.add_sprite(sprite))
          registry.store_sprite(sprite)
        })

        set_callback(CallbackSlot::SpriteLoad, ->(path : LibC::Char*) {
          begin
            sprite = Renderer::Sprite.from_texture(String.new(path))
            canvas.try(&.add_sprite(sprite))
            registry.store_sprite(sprite)
          rescue
            0_u32
          end
        })

        set_callback(CallbackSlot::SpriteSetPosition, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          sprite = registry.get_sprite(h)
          if sprite
            sprite.x = x; sprite.y = y
          end
        })

        set_callback(CallbackSlot::SpriteGetPosition, ->(h : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          sprite = registry.get_sprite(h)
          if sprite
            x.value = sprite.x; y.value = sprite.y
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
            canvas.try(&.remove_sprite(sprite))
            registry.release(h)
          end
        })

        set_callback(CallbackSlot::SpriteSetAtlas, ->(handle : UInt32, columns : Float32, rows : Float32, _unused : Float32) {
          sprite = registry.get_sprite(handle)
          sprite.setup_atlas(columns.to_i32, rows.to_i32) if sprite
        })

        set_callback(CallbackSlot::SpritePlayAnimation, ->(handle : UInt32, encoded : LibC::Char*) {
          sprite = registry.get_sprite(handle)
          if sprite
            parts = String.new(encoded).split('|')
            if parts.size >= 3
              frames = parts[0].split(',').compact_map { |f| f.to_i? }
              fps = parts[1].to_f32? || 12.0f32
              loop_flag = parts[2] == "1"
              sprite.play_animation(frames, fps, loop_flag)
            end
          end
        })

        set_callback(CallbackSlot::SpriteStopAnimation, ->(handle : UInt32) {
          sprite = registry.get_sprite(handle)
          sprite.stop_animation if sprite
        })

        set_callback(CallbackSlot::SpriteSetFrame, ->(handle : UInt32, frame : Int32) {
          sprite = registry.get_sprite(handle)
          sprite.frame_index = frame if sprite
        })
      end

      # Camera manipulation callbacks
      private def register_camera_callbacks(camera)
        set_callback(CallbackSlot::CameraSetPosition, ->(handle : UInt32, x : Float32, y : Float32, z : Float32) {
          camera.position = Math::Vector3.new(x, y, z)
        })

        set_callback(CallbackSlot::CameraGetPosition, ->(handle : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          pos = camera.position
          x.value = pos.x; y.value = pos.y; z.value = pos.z
        })

        set_callback(CallbackSlot::CameraSetTarget, ->(handle : UInt32, x : Float32, y : Float32, z : Float32) {
          camera.target = Math::Vector3.new(x, y, z)
        })

        set_callback(CallbackSlot::CameraGetTarget, ->(handle : UInt32, x : Float32*, y : Float32*, z : Float32*) {
          t = camera.target
          x.value = t.x; y.value = t.y; z.value = t.z
        })

        set_callback(CallbackSlot::CameraSetFOV, ->(handle : UInt32, fov : Float32) {
          camera.field_of_view = fov
        })
      end

      # Light creation and manipulation callbacks
      private def register_light_callbacks(registry, light_manager)
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
      end

      # Audio playback callbacks
      private def register_audio_callbacks(registry, audio_engine)
        Log.info { "register_audio_callbacks: audio_engine=#{audio_engine.nil? ? "nil" : "present"}" }

        set_callback(CallbackSlot::AudioPlaySound, ->(path : LibC::Char*) {
          Log.info { "AudioPlaySound: #{String.new(path)}, engine=#{audio_engine.nil? ? "nil" : "present"}" }
          audio_engine.try(&.play(String.new(path)))
          0_u32
        })

        set_callback(CallbackSlot::AudioLoadSound, ->(path : LibC::Char*) {
          if ae = audio_engine
            sound = Audio::Sound.new(ae, String.new(path))
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

        set_callback(CallbackSlot::AudioSetLooping, ->(h : UInt32, looping : Int32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.looping = looping != 0 } if sound
        })

        set_callback(CallbackSlot::AudioSetSpatial, ->(h : UInt32, enabled : Int32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.spatial = enabled != 0 } if sound
        })

        set_callback(CallbackSlot::AudioSetSoundPosition, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.position = Math::Vector3.new(x, y, z) } if sound
        })

        set_callback(CallbackSlot::AudioSetMinDistance, ->(h : UInt32, distance : Float32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.min_distance = distance } if sound
        })

        set_callback(CallbackSlot::AudioSetMaxDistance, ->(h : UInt32, distance : Float32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.max_distance = distance } if sound
        })

        set_callback(CallbackSlot::AudioSetRolloff, ->(h : UInt32, rolloff : Float32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.rolloff = rolloff } if sound
        })

        set_callback(CallbackSlot::AudioSetPitch, ->(h : UInt32, pitch : Float32) {
          sound = registry.get_sound(h)
          sound.try { |s| s.pitch = pitch } if sound
        })

        set_callback(CallbackSlot::AudioStartSound, ->(h : UInt32) {
          sound = registry.get_sound(h)
          sound.try(&.play) if sound
        })
      end

      # Particle system callbacks
      private def register_particle_callbacks(registry, engine)
        set_callback(CallbackSlot::ParticleCreateEmitter, ->(_unused : Float32, max_particles : Int32, _pad : Int32) {
          emitter = Renderer::ParticleSystem::Emitter.new(max_particles: max_particles)
          if vp = engine.viewport
            if ps = vp.particle_system
              ps.add_emitter(emitter)
            end
          end
          registry.store_emitter(emitter)
        })

        set_callback(CallbackSlot::ParticleDestroyEmitter, ->(handle : UInt32) {
          emitter = registry.get_emitter(handle)
          if emitter
            if vp = engine.viewport
              if ps = vp.particle_system
                ps.remove_emitter(emitter)
              end
            end
            registry.release(handle)
          end
        })

        set_callback(CallbackSlot::ParticleSetPosition, ->(handle : UInt32, x : Float32, y : Float32, z : Float32) {
          emitter = registry.get_emitter(handle)
          emitter.position = Math::Vector3.new(x, y, z) if emitter
        })

        set_callback(CallbackSlot::ParticleSetDirection, ->(handle : UInt32, x : Float32, y : Float32, z : Float32) {
          emitter = registry.get_emitter(handle)
          emitter.direction = Math::Vector3.new(x, y, z) if emitter
        })

        set_callback(CallbackSlot::ParticleSetColors, ->(hf : Float32, sr : Float32, sg : Float32, sb : Float32, er : Float32, eg : Float32, eb : Float32, _unused : Float32) {
          handle = hf.unsafe_as(UInt32)
          emitter = registry.get_emitter(handle)
          if emitter
            emitter.color_start = Math::Vector3.new(sr, sg, sb)
            emitter.color_end = Math::Vector3.new(er, eg, eb)
          end
        })

        set_callback(CallbackSlot::ParticleSetSizes, ->(h : UInt32, start_size : Float32, end_size : Float32, _unused : Float32) {
          emitter = registry.get_emitter(h)
          if emitter
            emitter.size_start = start_size; emitter.size_end = end_size
          end
        })

        set_callback(CallbackSlot::ParticleSetSpeed, ->(h : UInt32, min_speed : Float32, max_speed : Float32, _unused : Float32) {
          emitter = registry.get_emitter(h)
          if emitter
            emitter.speed_min = min_speed; emitter.speed_max = max_speed
          end
        })

        set_callback(CallbackSlot::ParticleSetLifetime, ->(h : UInt32, min_lt : Float32, max_lt : Float32, _unused : Float32) {
          emitter = registry.get_emitter(h)
          if emitter
            emitter.lifetime_min = min_lt; emitter.lifetime_max = max_lt
          end
        })

        set_callback(CallbackSlot::ParticleSetGravity, ->(h : UInt32, x : Float32, y : Float32, z : Float32) {
          emitter = registry.get_emitter(h)
          emitter.gravity = Math::Vector3.new(x, y, z) if emitter
        })

        set_callback(CallbackSlot::ParticleSetRate, ->(h : UInt32, rate : Float32) {
          emitter = registry.get_emitter(h)
          emitter.emit_rate = rate if emitter
        })

        set_callback(CallbackSlot::ParticleSetSpread, ->(h : UInt32, spread : Float32) {
          emitter = registry.get_emitter(h)
          emitter.spread = spread if emitter
        })

        set_callback(CallbackSlot::ParticleSetActive, ->(h : UInt32, active : Int32) {
          emitter = registry.get_emitter(h)
          emitter.active = active != 0 if emitter
        })

        set_callback(CallbackSlot::ParticleEmitBurst, ->(h : UInt32, count : Int32) {
          emitter = registry.get_emitter(h)
          emitter.emit(count) if emitter
        })

        set_callback(CallbackSlot::ParticleLoadTexture, ->(h : UInt32, path : LibC::Char*) {
          emitter = registry.get_emitter(h)

          if emitter
            begin
              texture = Renderer::Texture.load(String.new(path), srgb: false)
              Log.info { "Texture loaded: #{texture.width}x#{texture.height}, #{texture.channels} channels" }
              emitter.texture = texture
              Log.info { "Assigned texture '#{String.new(path)}' to emitter #{h}" }
            rescue ex
              Log.error { "Failed to load particle texture: #{ex.message}" }
            end
          else
            Log.warn { "No emitter found for handle #{h}" }
          end
        })

        set_callback(CallbackSlot::ParticleSetBlendAdditive, ->(h : UInt32, additive : Int32) {
          emitter = registry.get_emitter(h)
          emitter.blend_additive = additive != 0 if emitter
        })
      end

      # Configuration callbacks - let JS edit rendering settings live
      private def register_configuration_callbacks(engine)
        set_callback(CallbackSlot::ToggleFog, ->(enabled : Int32) {
          Configuration.instance.fog.enabled = !Configuration.instance.fog.enabled
          Configuration.instance.fog.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::SetFogParameters, ->(r : Float32, g : Float32, b : Float32, near : Float32, far : Float32, density : Float32, mode : Float32, _unused : Float32) {
          fog = Configuration.instance.fog

          fog.color = Math::Vector3.new(r, g, b)
          fog.near = near
          fog.far = far
          fog.density = density
          fog.mode = mode.to_i32
        })

        set_callback(CallbackSlot::ToggleBloom, -> {
          Configuration.instance.bloom.enabled = !Configuration.instance.bloom.enabled
          Configuration.instance.bloom.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::ToggleSSAO, -> {
          Configuration.instance.ssao.enabled = !Configuration.instance.ssao.enabled
          Configuration.instance.ssao.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::ToggleShadow, -> {
          Configuration.instance.shadow.enabled = !Configuration.instance.shadow.enabled
          Configuration.instance.shadow.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::SetShadowResolution, ->(resolution : Int32) {
          Configuration.instance.shadow.resolution = resolution
        })

        set_callback(CallbackSlot::ToggleSkybox, -> {
          Configuration.instance.skybox.enabled = !Configuration.instance.skybox.enabled
          Configuration.instance.skybox.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::SetSkyboxTopColor, ->(r : Float32, g : Float32, b : Float32) {
          Configuration.instance.skybox.top_color = Math::Vector3.new(r, g, b)
        })

        set_callback(CallbackSlot::SetSkyboxBottomColor, ->(r : Float32, g : Float32, b : Float32) {
          Configuration.instance.skybox.bottom_color = Math::Vector3.new(r, g, b)
        })

        set_callback(CallbackSlot::ToggleVignette, -> {
          Configuration.instance.vignette.enabled = !Configuration.instance.vignette.enabled
          Configuration.instance.vignette.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::ToggleChromaticAberration, -> {
          Configuration.instance.chromatic_aberration.enabled = !Configuration.instance.chromatic_aberration.enabled
          Configuration.instance.chromatic_aberration.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::ToggleColorGrading, -> {
          Configuration.instance.color_grading.enabled = !Configuration.instance.color_grading.enabled
          Configuration.instance.color_grading.enabled ? 1_u32 : 0_u32
        })

        set_callback(CallbackSlot::ToggleFXAA, -> {
          Configuration.instance.fxaa.enabled = !Configuration.instance.fxaa.enabled
          Configuration.instance.fxaa.enabled ? 1_u32 : 0_u32
        })
      end

      # Pipeline manipulation callbacks - let JS toggle/reorder stages
      private def register_pipeline_callbacks(engine)
        set_callback(CallbackSlot::PipelineToggleStage, ->(name_ptr : LibC::Char*, enabled : Int32) {
          if vp = engine.viewport
            vp.pipeline.toggle(String.new(name_ptr), enabled != 0)
          end
        })

        set_callback(CallbackSlot::PipelineMoveStage, ->(name_ptr : LibC::Char*, new_index : Int32) {
          if vp = engine.viewport
            vp.pipeline.move(String.new(name_ptr), new_index)
          end
          0_u32
        })

        set_callback(CallbackSlot::PipelineRemoveStage, ->(name_ptr : LibC::Char*) {
          if vp = engine.viewport
            vp.pipeline.remove(String.new(name_ptr))
          end
          0_u32
        })
      end
    end
  end
end
