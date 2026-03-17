module Tachyon
  module Geometry
    module OBJLoader
      # Loads a Wavefront OBJ file and returns vertices + indices
      # Vertex layout: [x, y, z, nx, ny, nz, u, v] — 8 floats per vertex
      def self.load(path : String) : {Array(Float32), Array(UInt32)}
        positions = [] of Math::Vector3
        normals = [] of Math::Vector3
        texcoords = [] of {Float32, Float32}
        vertices = [] of Float32
        indices = [] of UInt32
        vertex_cache = {} of String => UInt32

        File.each_line(path) do |raw_line|
          line = raw_line.strip
          next if line.empty? || line.starts_with?('#')

          parts = line.split(/\s+/)
          case parts[0]
          when "v"
            next unless parts.size >= 4
            positions << Math::Vector3.new(
              parts[1].to_f32,
              parts[2].to_f32,
              parts[3].to_f32
            )
          when "vn"
            next unless parts.size >= 4
            normals << Math::Vector3.new(
              parts[1].to_f32,
              parts[2].to_f32,
              parts[3].to_f32
            )
          when "vt"
            next unless parts.size >= 3
            texcoords << {parts[1].to_f32, parts[2].to_f32}
          when "f"
            # Triangulate faces (fan triangulation for convex polygons)
            face_indices = [] of UInt32
            (1...parts.size).each do |i|
              key = parts[i]
              if cached = vertex_cache[key]?
                face_indices << cached
              else
                idx = emit_vertex(key, positions, normals, texcoords, vertices)
                vertex_cache[key] = idx
                face_indices << idx
              end
            end

            # Fan triangulation: 0-1-2, 0-2-3, 0-3-4, ...
            (1...face_indices.size - 1).each do |i|
              indices << face_indices[0]
              indices << face_indices[i]
              indices << face_indices[i + 1]
            end
          end
        end

        # Generate flat normals if OBJ had none
        if normals.empty?
          compute_flat_normals(vertices, indices)
        end

        {vertices, indices}
      end

      private def self.emit_vertex(key : String,
                                   positions : Array(Math::Vector3),
                                   normals : Array(Math::Vector3),
                                   texcoords : Array({Float32, Float32}),
                                   vertices : Array(Float32)) : UInt32
        idx = (vertices.size // 8).to_u32
        parts = key.split('/')

        # Position index (1-based)
        vi = parts[0].to_i - 1
        pos = positions[vi]? || Math::Vector3.zero
        vertices << pos.x << pos.y << pos.z

        # Normal index (parts[2], 1-based)
        if parts.size >= 3 && !parts[2].empty?
          ni = parts[2].to_i - 1
          n = normals[ni]? || Math::Vector3.up
          vertices << n.x << n.y << n.z
        else
          vertices << 0.0f32 << 1.0f32 << 0.0f32
        end

        # Texcoord index (parts[1], 1-based)
        if parts.size >= 2 && !parts[1].empty?
          ti = parts[1].to_i - 1
          tc = texcoords[ti]? || {0.0f32, 0.0f32}
          vertices << tc[0] << tc[1]
        else
          vertices << 0.0f32 << 0.0f32
        end

        idx
      end

      private def self.compute_flat_normals(vertices : Array(Float32), indices : Array(UInt32))
        # Reset all normals to zero
        i = 0
        while i < vertices.size
          vertices[i + 3] = 0.0f32
          vertices[i + 4] = 0.0f32
          vertices[i + 5] = 0.0f32
          i += 8
        end

        # Compute face normals and accumulate
        tri = 0
        while tri < indices.size
          i0 = indices[tri].to_i * 8
          i1 = indices[tri + 1].to_i * 8
          i2 = indices[tri + 2].to_i * 8

          v0 = Math::Vector3.new(vertices[i0], vertices[i0 + 1], vertices[i0 + 2])
          v1 = Math::Vector3.new(vertices[i1], vertices[i1 + 1], vertices[i1 + 2])
          v2 = Math::Vector3.new(vertices[i2], vertices[i2 + 1], vertices[i2 + 2])

          edge1 = v1 - v0
          edge2 = v2 - v0
          normal = edge1.cross(edge2)

          {i0, i1, i2}.each do |vi|
            vertices[vi + 3] += normal.x
            vertices[vi + 4] += normal.y
            vertices[vi + 5] += normal.z
          end

          tri += 3
        end

        # Normalize
        i = 0
        while i < vertices.size
          nx = vertices[i + 3]
          ny = vertices[i + 4]
          nz = vertices[i + 5]
          len = ::Math.sqrt(nx * nx + ny * ny + nz * nz).to_f32
          if len > 0.0001f32
            vertices[i + 3] = nx / len
            vertices[i + 4] = ny / len
            vertices[i + 5] = nz / len
          end
          i += 8
        end
      end
    end
  end
end
