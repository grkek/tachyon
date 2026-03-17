module Tachyon
  module Scene
    class Graph
      Log = ::Log.for(self)

      getter root : Node
      property ambient_color : Math::Vector3

      def initialize
        @root = Node.new("root")
        @ambient_color = Math::Vector3.new(0.1f32, 0.1f32, 0.12f32)
      end

      def add(node : Node)
        @root.add_child(node)
      end

      def add(*nodes : Node)
        nodes.each { |n| @root.add_child(n) }
      end

      def remove(node : Node)
        @root.remove_child(node)
      end

      def find(name : String) : Node?
        find_recursive(@root, name)
      end

      def clear
        @root.children.each(&.destroy)
        @root.children.clear
      end

      # Traverse all visible nodes that have a mesh, yielding each
      def each_renderable(&block : Node ->)
        traverse_renderable(@root, &block)
      end

      def destroy
        @root.destroy
      end

      private def find_recursive(node : Node, name : String) : Node?
        return node if node.name == name
        node.children.each do |child|
          result = find_recursive(child, name)
          return result if result
        end
        nil
      end

      private def traverse_renderable(node : Node, &block : Node ->)
        return unless node.visible
        block.call(node) if node.mesh
        node.children.each { |child| traverse_renderable(child, &block) }
      end
    end
  end
end
