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

      def initialize(@name : String = "")
        @transform = Transform.new
        @children = [] of Node
      end

      def add_child(child : Node)
        child.parent.try(&.remove_child(child))
        child.parent = self
        @children << child
      end

      def remove_child(child : Node)
        @children.delete(child)
        child.parent = nil
      end

      # World-space model matrix (accounts for parent hierarchy)
      def world_matrix : Math::Matrix4
        local = @transform.model_matrix
        if p = @parent
          p.world_matrix * local
        else
          local
        end
      end

      # World-space normal matrix
      def world_normal_matrix : Math::Matrix4
        local = @transform.normal_matrix
        if p = @parent
          p.world_normal_matrix * local
        else
          local
        end
      end

      def world_aabb : Math::AABB
        mesh = @mesh
        return Math::AABB.new unless mesh

        model = world_matrix
        min = mesh.bounds_min
        max = mesh.bounds_max

        # Transform all 8 corners of the local AABB by the model matrix
        # and find the new min/max
        corners = [
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

        Math::AABB.new(world_min, world_max)
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
    end
  end
end
