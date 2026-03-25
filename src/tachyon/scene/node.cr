module Tachyon
  module Scene
    class Node
      Log = ::Log.for(self)

      property name : String
      property transform : Transform
      property mesh : Renderer::Mesh? = nil
      property material : Renderer::Material? = nil
      property visible : Bool = true
      property parent : Node? = nil
      getter children : Array(Node)

      # Cached world-space matrices — recomputed only when the transform
      # (or any ancestor's transform) changes.
      @world_dirty : Bool = true
      @cached_world_matrix : Math::Matrix4 = Math::Matrix4.identity
      @cached_world_normal : Math::Matrix4 = Math::Matrix4.identity
      @cached_world_aabb : Math::AABB = Math::AABB.new

      def initialize(@name : String = "")
        @transform = Transform.new
        @children = [] of Node
      end

      def add_child(child : Node)
        child.parent.try(&.remove_child(child))
        child.parent = self
        @children << child
        child.invalidate_world_cache
      end

      def remove_child(child : Node)
        @children.delete(child)
        child.parent = nil
        child.invalidate_world_cache
      end

      # Mark this node and all descendants as needing a world-matrix refresh.
      # Called when this node's transform changes or when it's reparented.
      def invalidate_world_cache
        return if @world_dirty # already dirty — subtree must be too
        @world_dirty = true
        @children.each(&.invalidate_world_cache)
      end

      # Call once per frame, before rendering, to refresh caches top-down.
      # Only recomputes nodes whose local transform actually changed.
      def update_world_cache(parent_matrix : Math::Matrix4 = Math::Matrix4.identity,
                             parent_normal : Math::Matrix4 = Math::Matrix4.identity,
                             force : Bool = false)
        needs_update = force || @world_dirty || @transform.dirty?

        if needs_update
          local = @transform.model_matrix   # uses Transform's own cache
          local_normal = @transform.normal_matrix

          @cached_world_matrix = parent_matrix * local
          @cached_world_normal = parent_normal * local_normal
          @world_dirty = false

          # Recompute AABB if we have a mesh
          if m = @mesh
            recompute_aabb(m)
          end
        end

        @children.each do |child|
          child.update_world_cache(@cached_world_matrix, @cached_world_normal, needs_update)
        end
      end

      # World-space model matrix (cached)
      def world_matrix : Math::Matrix4
        @cached_world_matrix
      end

      # World-space normal matrix (cached)
      def world_normal_matrix : Math::Matrix4
        @cached_world_normal
      end

      def world_aabb : Math::AABB
        @cached_world_aabb
      end

      # Full precision raycast against the mesh triangles
      def raycast(ray : Math::Ray) : Float32?
        mesh = @mesh
        return nil unless mesh
        mesh.raycast(ray.origin, ray.direction, world_matrix)
      end

      def destroy
        @mesh.try(&.destroy)
        @children.each(&.destroy)
        @children.clear
      end

      private def recompute_aabb(mesh : Renderer::Mesh)
        model = @cached_world_matrix
        min = mesh.bounds_min
        max = mesh.bounds_max

        corners = StaticArray[
          Math::Vector3.new(min.x, min.y, min.z),
          Math::Vector3.new(max.x, min.y, min.z),
          Math::Vector3.new(min.x, max.y, min.z),
          Math::Vector3.new(max.x, max.y, min.z),
          Math::Vector3.new(min.x, min.y, max.z),
          Math::Vector3.new(max.x, min.y, max.z),
          Math::Vector3.new(min.x, max.y, max.z),
          Math::Vector3.new(max.x, max.y, max.z),
        ]

        world_min = Math::Vector3.new(Float32::MAX, Float32::MAX, Float32::MAX)
        world_max = Math::Vector3.new(Float32::MIN, Float32::MIN, Float32::MIN)

        corners.each do |corner|
          world_corner = model.transform_point(corner)
          world_min = Math::Vector3.new(
            ::Math.min(world_min.x, world_corner.x).to_f32,
            ::Math.min(world_min.y, world_corner.y).to_f32,
            ::Math.min(world_min.z, world_corner.z).to_f32
          )
          world_max = Math::Vector3.new(
            ::Math.max(world_max.x, world_corner.x).to_f32,
            ::Math.max(world_max.y, world_corner.y).to_f32,
            ::Math.max(world_max.z, world_corner.z).to_f32
          )
        end

        @cached_world_aabb = Math::AABB.new(world_min, world_max)
      end
    end
  end
end
