module Tachyon
  module Scripting
    class HandleRegistry
      Log = ::Log.for(self)

      @nodes : Hash(UInt32, Scene::Node) = {} of UInt32 => Scene::Node
      @cameras : Hash(UInt32, Renderer::Camera) = {} of UInt32 => Renderer::Camera
      @lights : Hash(UInt32, Renderer::Light) = {} of UInt32 => Renderer::Light
      @sprites : Hash(UInt32, Renderer::Sprite) = {} of UInt32 => Renderer::Sprite
      @sounds : Hash(UInt32, Audio::Sound) = {} of UInt32 => Audio::Sound
      @emitters : Hash(UInt32, Renderer::ParticleSystem::Emitter) = {} of UInt32 => Renderer::ParticleSystem::Emitter
      @next_id : UInt32 = 1_u32

      def store_node(node : Scene::Node) : UInt32
        id = @next_id
        @next_id += 1
        @nodes[id] = node
        id
      end

      def store_camera(camera : Renderer::Camera) : UInt32
        id = @next_id
        @next_id += 1
        @cameras[id] = camera
        id
      end

      def store_light(light : Renderer::Light) : UInt32
        id = @next_id
        @next_id += 1
        @lights[id] = light
        id
      end

      def store_sprite(sprite : Renderer::Sprite) : UInt32
        id = @next_id
        @next_id += 1
        @sprites[id] = sprite
        id
      end

      def store_sound(sound : Audio::Sound) : UInt32
        id = @next_id
        @next_id += 1
        @sounds[id] = sound
        id
      end

      def get_node(id : UInt32) : Scene::Node?
        @nodes[id]?
      end

      def get_camera(id : UInt32) : Renderer::Camera?
        @cameras[id]?
      end

      def get_light(id : UInt32) : Renderer::Light?
        @lights[id]?
      end

      def get_sprite(id : UInt32) : Renderer::Sprite?
        @sprites[id]?
      end

      def get_sound(id : UInt32) : Audio::Sound?
        @sounds[id]?
      end

      def store_emitter(emitter : Renderer::ParticleSystem::Emitter) : UInt32
        id = @next_id
        @next_id += 1
        @emitters[id] = emitter
        id
      end

      def get_emitter(id : UInt32) : Renderer::ParticleSystem::Emitter?
        @emitters[id]?
      end

      def release(id : UInt32)
        @nodes.delete(id)
        @cameras.delete(id)
        @lights.delete(id)
        @sprites.delete(id)
        @sounds.delete(id)
        @emitters.delete(id)
      end

      def find_handle(node : Scene::Node) : UInt32
        @nodes.each do |id, n|
          return id if n.object_id == node.object_id
        end

        0_u32
      end

      def clear
        @nodes.clear
        @cameras.clear
        @lights.clear
        @sprites.clear
        @sounds.clear
        @emitters.clear
      end
    end
  end
end
