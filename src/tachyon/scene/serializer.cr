module Tachyon
  module Scene
    module Serializer
      Log = ::Log.for(self)

      def self.save(graph : Graph, path : String)
        data = serialize_graph(graph)
        File.write(path, data.to_pretty_json)
        Log.info { "Scene saved to #{path}" }
      end

      def self.save_to_string(graph : Graph) : String
        data = serialize_graph(graph)
        data.to_pretty_json
      end

      def self.load(path : String) : {Array(NodeData), SceneData}
        json = File.read(path)
        load_from_string(json)
      end

      def self.load_from_string(json : String) : {Array(NodeData), SceneData}
        data = JSON.parse(json)

        scene_data = SceneData.new
        if ambient = data["ambient"]?
          scene_data.ambient_r = ambient[0].as_f.to_f32
          scene_data.ambient_g = ambient[1].as_f.to_f32
          scene_data.ambient_b = ambient[2].as_f.to_f32
        end

        if fog = data["fog"]?
          scene_data.fog_enabled = fog["enabled"]?.try(&.as_bool) || false
          if color = fog["color"]?
            scene_data.fog_color_r = color[0].as_f.to_f32
            scene_data.fog_color_g = color[1].as_f.to_f32
            scene_data.fog_color_b = color[2].as_f.to_f32
          end
          scene_data.fog_near = fog["near"]?.try(&.as_f.to_f32) || 10.0f32
          scene_data.fog_far = fog["far"]?.try(&.as_f.to_f32) || 100.0f32
          scene_data.fog_density = fog["density"]?.try(&.as_f.to_f32) || 0.01f32
          scene_data.fog_mode = fog["mode"]?.try(&.as_i.to_i32) || 0
        end

        nodes = [] of NodeData
        if children = data["nodes"]?
          children.as_a.each do |child_json|
            nodes << deserialize_node(child_json)
          end
        end

        {nodes, scene_data}
      end

      class NodeData
        property name : String = ""
        property position : {Float32, Float32, Float32} = {0.0f32, 0.0f32, 0.0f32}
        property rotation : {Float32, Float32, Float32, Float32} = {0.0f32, 0.0f32, 0.0f32, 1.0f32}
        property scale : {Float32, Float32, Float32} = {1.0f32, 1.0f32, 1.0f32}
        property visible : Bool = true
        property geometry_type : String = ""
        property geometry_params : Hash(String, Float64) = {} of String => Float64
        property mesh_path : String? = nil
        property albedo : {Float32, Float32, Float32} = {0.8f32, 0.8f32, 0.8f32}
        property metallic : Float32 = 0.0f32
        property roughness : Float32 = 0.5f32
        property opacity : Float32 = 1.0f32
        property emissive : {Float32, Float32, Float32} = {0.0f32, 0.0f32, 0.0f32}
        property emissive_strength : Float32 = 0.0f32
        property albedo_map_path : String? = nil
        property normal_map_path : String? = nil
        property children : Array(NodeData) = [] of NodeData
      end

      class SceneData
        property ambient_r : Float32 = 0.1f32
        property ambient_g : Float32 = 0.1f32
        property ambient_b : Float32 = 0.12f32
        property fog_enabled : Bool = false
        property fog_color_r : Float32 = 0.7f32
        property fog_color_g : Float32 = 0.7f32
        property fog_color_b : Float32 = 0.7f32
        property fog_near : Float32 = 10.0f32
        property fog_far : Float32 = 100.0f32
        property fog_density : Float32 = 0.01f32
        property fog_mode : Int32 = 0
      end

      private def self.serialize_graph(graph : Graph) : JSON::Any
        nodes = graph.root.children.map { |child| serialize_node(child) }

        JSON::Any.new({
          "ambient" => JSON::Any.new([
            JSON::Any.new(graph.ambient_color.x.to_f64),
            JSON::Any.new(graph.ambient_color.y.to_f64),
            JSON::Any.new(graph.ambient_color.z.to_f64),
          ] of JSON::Any),
          "nodes" => JSON::Any.new(nodes),
        } of String => JSON::Any)
      end

      private def self.serialize_node(node : Node) : JSON::Any
        data = {} of String => JSON::Any

        data["name"] = JSON::Any.new(node.name)

        position = node.transform.position
        data["position"] = JSON::Any.new([
          JSON::Any.new(position.x.to_f64),
          JSON::Any.new(position.y.to_f64),
          JSON::Any.new(position.z.to_f64),
        ] of JSON::Any)

        rotation = node.transform.rotation
        data["rotation"] = JSON::Any.new([
          JSON::Any.new(rotation.x.to_f64),
          JSON::Any.new(rotation.y.to_f64),
          JSON::Any.new(rotation.z.to_f64),
          JSON::Any.new(rotation.w.to_f64),
        ] of JSON::Any)

        scale = node.transform.scale
        data["scale"] = JSON::Any.new([
          JSON::Any.new(scale.x.to_f64),
          JSON::Any.new(scale.y.to_f64),
          JSON::Any.new(scale.z.to_f64),
        ] of JSON::Any)

        data["visible"] = JSON::Any.new(node.visible)

        if material = node.material
          mat_data = {} of String => JSON::Any
          mat_data["albedo"] = JSON::Any.new([
            JSON::Any.new(material.albedo.x.to_f64),
            JSON::Any.new(material.albedo.y.to_f64),
            JSON::Any.new(material.albedo.z.to_f64),
          ] of JSON::Any)
          mat_data["metallic"] = JSON::Any.new(material.metallic.to_f64)
          mat_data["roughness"] = JSON::Any.new(material.roughness.to_f64)
          mat_data["opacity"] = JSON::Any.new(material.opacity.to_f64)
          mat_data["emissive"] = JSON::Any.new([
            JSON::Any.new(material.emissive.x.to_f64),
            JSON::Any.new(material.emissive.y.to_f64),
            JSON::Any.new(material.emissive.z.to_f64),
          ] of JSON::Any)
          mat_data["emissiveStrength"] = JSON::Any.new(material.emissive_strength.to_f64)
          data["material"] = JSON::Any.new(mat_data)
        end

        unless node.children.empty?
          data["children"] = JSON::Any.new(node.children.map { |child| serialize_node(child) })
        end

        JSON::Any.new(data)
      end

      private def self.deserialize_node(json : JSON::Any) : NodeData
        node_data = NodeData.new
        node_data.name = json["name"]?.try(&.as_s) || ""

        if position = json["position"]?
          node_data.position = {
            position[0].as_f.to_f32,
            position[1].as_f.to_f32,
            position[2].as_f.to_f32,
          }
        end

        if rotation = json["rotation"]?
          node_data.rotation = {
            rotation[0].as_f.to_f32,
            rotation[1].as_f.to_f32,
            rotation[2].as_f.to_f32,
            rotation[3].as_f.to_f32,
          }
        end

        if scale = json["scale"]?
          node_data.scale = {
            scale[0].as_f.to_f32,
            scale[1].as_f.to_f32,
            scale[2].as_f.to_f32,
          }
        end

        node_data.visible = json["visible"]?.try(&.as_bool) || true

        if geometry = json["geometry"]?
          node_data.geometry_type = geometry["type"]?.try(&.as_s) || ""
          if params = geometry["params"]?
            params.as_h.each do |key, value|
              node_data.geometry_params[key] = value.as_f
            end
          end
        end

        node_data.mesh_path = json["meshPath"]?.try(&.as_s)

        if material = json["material"]?
          if albedo = material["albedo"]?
            node_data.albedo = {
              albedo[0].as_f.to_f32,
              albedo[1].as_f.to_f32,
              albedo[2].as_f.to_f32,
            }
          end
          node_data.metallic = material["metallic"]?.try(&.as_f.to_f32) || 0.0f32
          node_data.roughness = material["roughness"]?.try(&.as_f.to_f32) || 0.5f32
          node_data.opacity = material["opacity"]?.try(&.as_f.to_f32) || 1.0f32
          if emissive = material["emissive"]?
            node_data.emissive = {
              emissive[0].as_f.to_f32,
              emissive[1].as_f.to_f32,
              emissive[2].as_f.to_f32,
            }
          end
          node_data.emissive_strength = material["emissiveStrength"]?.try(&.as_f.to_f32) || 0.0f32
          node_data.albedo_map_path = material["albedoMap"]?.try(&.as_s)
          node_data.normal_map_path = material["normalMap"]?.try(&.as_s)
        end

        if children = json["children"]?
          children.as_a.each do |child_json|
            node_data.children << deserialize_node(child_json)
          end
        end

        node_data
      end
    end
  end
end
