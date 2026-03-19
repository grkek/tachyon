{% if flag?(:darwin) %}
  @[Link(framework: "OpenGL")]
{% else %}
  @[Link("epoxy")]
{% end %}
lib LibGL
  # Types
  alias GLenum = UInt32
  alias GLuint = UInt32
  alias GLint = Int32
  alias GLsizei = Int32
  alias GLboolean = UInt8
  alias GLfloat = Float32
  alias GLchar = UInt8
  alias GLsizeiptr = Int64
  alias GLbitfield = UInt32

  # Clear
  GL_COLOR_BUFFER_BIT = 0x00004000_u32
  GL_DEPTH_BUFFER_BIT = 0x00000100_u32

  # Primitives
  GL_TRIANGLES = 0x0004_u32

  # Shaders
  GL_VERTEX_SHADER   = 0x8B31_u32
  GL_FRAGMENT_SHADER = 0x8B30_u32
  GL_COMPILE_STATUS  = 0x8B81_u32
  GL_LINK_STATUS     = 0x8B82_u32
  GL_INFO_LOG_LENGTH = 0x8B84_u32
  GL_CLAMP_TO_BORDER = 0x812D_u32

  # Buffer targets
  GL_ARRAY_BUFFER         = 0x8892_u32
  GL_ELEMENT_ARRAY_BUFFER = 0x8893_u32
  GL_RENDERBUFFER         = 0x8D41_u32
  GL_UNIFORM_BUFFER = 0x8A11_u32

  # Usage hints
  GL_STATIC_DRAW  = 0x88E4_u32
  GL_DYNAMIC_DRAW = 0x88E8_u32
  GL_STREAM_DRAW  =     0x88E0

  # Data types
  GL_FLOAT         = 0x1406_u32
  GL_UNSIGNED_INT  = 0x1405_u32
  GL_UNSIGNED_BYTE = 0x1401_u32

  # Boolean
  GL_FALSE = 0_u8
  GL_TRUE  = 1_u8

  # Enable caps
  GL_DEPTH_TEST = 0x0B71_u32
  GL_CULL_FACE  = 0x0B44_u32
  GL_BLEND      = 0x0BE2_u32

  # Blend functions
  GL_SRC_ALPHA           = 0x0302_u32
  GL_ONE_MINUS_SRC_ALPHA = 0x0303_u32
  GL_ONE = 1_u32

  fun glBlendFunc(sfactor : GLenum, dfactor : GLenum) : Void

  # Depth
  GL_LEQUAL = 0x0203_u32
  GL_LESS   = 0x0201_u32
  GL_ALWAYS = 0x0207_u32

  fun glDepthFunc(func : GLenum) : Void
  fun glDepthMask(flag : GLboolean) : Void

  # State
  fun glEnable(cap : GLenum) : Void
  fun glDisable(cap : GLenum) : Void
  fun glClearColor(red : GLfloat, green : GLfloat, blue : GLfloat, alpha : GLfloat) : Void
  fun glClear(mask : GLbitfield) : Void
  fun glViewport(x : GLint, y : GLint, width : GLsizei, height : GLsizei) : Void

  # Shaders
  fun glCreateShader(type : GLenum) : GLuint
  fun glShaderSource(shader : GLuint, count : GLsizei, string : UInt8**, length : Int32*) : Void
  fun glCompileShader(shader : GLuint) : Void
  fun glGetShaderiv(shader : GLuint, pname : GLenum, params : GLint*) : Void
  fun glGetShaderInfoLog(shader : GLuint, maxLength : GLsizei, length : GLsizei*, infoLog : GLchar*) : Void
  fun glDeleteShader(shader : GLuint) : Void
  fun glBlitFramebuffer(srcX0 : GLint, srcY0 : GLint, srcX1 : GLint, srcY1 : GLint,
                        dstX0 : GLint, dstY0 : GLint, dstX1 : GLint, dstY1 : GLint,
                        mask : GLbitfield, filter : GLenum) : Void

  # Program
  fun glCreateProgram : GLuint
  fun glAttachShader(program : GLuint, shader : GLuint) : Void
  fun glLinkProgram(program : GLuint) : Void
  fun glUseProgram(program : GLuint) : Void
  fun glGetProgramiv(program : GLuint, pname : GLenum, params : GLint*) : Void
  fun glGetProgramInfoLog(program : GLuint, maxLength : GLsizei, length : GLsizei*, infoLog : GLchar*) : Void
  fun glDeleteProgram(program : GLuint) : Void

  # Uniforms
  fun glGetUniformLocation(program : GLuint, name : GLchar*) : GLint
  fun glUniformMatrix4fv(location : GLint, count : GLsizei, transpose : GLboolean, value : GLfloat*) : Void
  fun glUniform3f(location : GLint, v0 : GLfloat, v1 : GLfloat, v2 : GLfloat) : Void
  fun glUniform1f(location : GLint, v0 : GLfloat) : Void
  fun glUniform1i(location : GLint, v0 : GLint) : Void
  fun glUniform2f(location : GLint, v0 : GLfloat, v1 : GLfloat) : Void
  fun glUniform4f(location : GLint, v0 : GLfloat, v1 : GLfloat, v2 : GLfloat, v3 : GLfloat) : Void

  # Face culling
  GL_BACK  = 0x0405_u32
  GL_FRONT = 0x0404_u32
  GL_CCW   = 0x0901_u32
  GL_CW    = 0x0900_u32
  fun glCullFace(mode : GLenum) : Void
  fun glFrontFace(mode : GLenum) : Void

  # VAO
  fun glGenVertexArrays(n : GLsizei, arrays : GLuint*) : Void
  fun glBindVertexArray(array : GLuint) : Void
  fun glDeleteVertexArrays(n : GLsizei, arrays : GLuint*) : Void

  # Buffers
  fun glGenBuffers(n : GLsizei, buffers : GLuint*) : Void
  fun glBindBuffer(target : GLenum, buffer : GLuint) : Void
  fun glBufferData(target : GLenum, size : GLsizeiptr, data : Void*, usage : GLenum) : Void
  fun glDeleteBuffers(n : GLsizei, buffers : GLuint*) : Void
  fun glGenRenderbuffers(n : Int32, renderbuffers : UInt32*) : Void
  fun glBindRenderbuffer(target : UInt32, renderbuffer : UInt32) : Void
  fun glRenderbufferStorage(target : UInt32, internalformat : UInt32, width : Int32, height : Int32) : Void
  fun glFramebufferRenderbuffer(target : UInt32, attachment : UInt32, renderbuffertarget : UInt32, renderbuffer : UInt32) : Void
  fun glDeleteRenderbuffers(n : Int32, renderbuffers : UInt32*) : Void
  fun glBindBufferBase(target : GLenum, index : GLuint, buffer : GLuint) : Void
  fun glBufferSubData(target : GLenum, offset : GLsizeiptr, size : GLsizeiptr, data : Void*) : Void
  fun glGetUniformBlockIndex(program : GLuint, uniformBlockName : GLchar*) : GLuint
  fun glUniformBlockBinding(program : GLuint, uniformBlockIndex : GLuint, uniformBlockBinding : GLuint) : Void

  # Vertex attributes
  fun glEnableVertexAttribArray(index : GLuint) : Void
  fun glVertexAttribPointer(index : GLuint, size : GLint, type : GLenum, normalized : GLboolean, stride : GLsizei, pointer : Void*) : Void

  # Draw
  fun glDrawArrays(mode : GLenum, first : GLint, count : GLsizei) : Void
  fun glDrawElements(mode : GLenum, count : GLsizei, type : GLenum, indices : Void*) : Void
  fun glDrawArraysInstanced(mode : GLenum, first : GLint, count : GLsizei, instancecount : GLsizei) : Void
  fun glDrawElementsInstanced(mode : GLenum, count : GLsizei, type : GLenum, indices : Void*, instancecount : GLsizei) : Void
  fun glVertexAttribDivisor(index : GLuint, divisor : GLuint) : Void

  # Textures
  GL_TEXTURE_2D                  = 0x0DE1_u32
  GL_TEXTURE_CUBE_MAP            = 0x8513_u32
  GL_TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515_u32
  GL_TEXTURE0                    = 0x84C0_u32
  GL_TEXTURE1                    = 0x84C1_u32
  GL_TEXTURE2                    = 0x84C2_u32
  GL_TEXTURE3                    = 0x84C3_u32
  GL_TEXTURE4                    = 0x84C4_u32
  GL_TEXTURE5                    = 0x84C5_u32
  GL_TEXTURE6                    = 0x84C6_u32

  GL_RGB                = 0x1907_u32
  GL_RGBA               = 0x1908_u32
  GL_SRGB               = 0x8C40_u32
  GL_SRGB8              = 0x8C41_u32
  GL_SRGB_ALPHA         = 0x8C42_u32
  GL_SRGB8_ALPHA8       = 0x8C43_u32
  GL_DEPTH_COMPONENT    = 0x1902_u32
  GL_DEPTH_COMPONENT16  = 0x81A5_u32
  GL_DEPTH_COMPONENT24  = 0x81A6_u32
  GL_DEPTH_COMPONENT32F = 0x8CAC_u32
  GL_RED                = 0x1903_u32
  GL_R8                 = 0x8229_u32
  GL_RG                 = 0x8227_u32
  GL_RG8                = 0x822B_u32
  GL_RG16F              = 0x822F_u32
  GL_RGB8               = 0x8051_u32
  GL_RGBA8              = 0x8058_u32
  GL_RGB16F             = 0x881B_u32
  GL_RGBA16F            = 0x881A_u32

  GL_TEXTURE_WRAP_S     = 0x2802_u32
  GL_TEXTURE_WRAP_T     = 0x2803_u32
  GL_TEXTURE_WRAP_R     = 0x8072_u32
  GL_TEXTURE_MIN_FILTER = 0x2801_u32
  GL_TEXTURE_MAG_FILTER = 0x2800_u32

  GL_NEAREST                = 0x2600_u32
  GL_LINEAR                 = 0x2601_u32
  GL_LINEAR_MIPMAP_LINEAR   = 0x2703_u32
  GL_LINEAR_MIPMAP_NEAREST  = 0x2701_u32
  GL_NEAREST_MIPMAP_LINEAR  = 0x2702_u32
  GL_NEAREST_MIPMAP_NEAREST = 0x2700_u32

  GL_REPEAT          = 0x2901_u32
  GL_CLAMP_TO_EDGE   = 0x812F_u32
  GL_MIRRORED_REPEAT = 0x8370_u32

  GL_TEXTURE_COMPARE_MODE   = 0x884C_u32
  GL_TEXTURE_COMPARE_FUNC   = 0x884D_u32
  GL_TEXTURE_BORDER_COLOR = 0x1004_u32
  GL_COMPARE_REF_TO_TEXTURE = 0x884E_u32

  fun glGenTextures(n : GLsizei, textures : GLuint*) : Void
  fun glBindTexture(target : GLenum, texture : GLuint) : Void
  fun glDeleteTextures(n : GLsizei, textures : GLuint*) : Void
  fun glTexImage2D(target : GLenum, level : GLint, internalformat : GLint, width : GLsizei, height : GLsizei, border : GLint, format : GLenum, type : GLenum, pixels : Void*) : Void
  fun glTexParameteri(target : GLenum, pname : GLenum, param : GLint) : Void
  fun glTexParameterf(target : GLenum, pname : GLenum, param : GLfloat) : Void
  fun glTexParameterfv(target : GLenum, pname : GLenum, params : Float32*) : Void
  fun glGenerateMipmap(target : GLenum) : Void
  fun glActiveTexture(texture : GLenum) : Void

  # Framebuffers
  GL_FRAMEBUFFER          = 0x8D40_u32
  GL_READ_FRAMEBUFFER     = 0x8CA8_u32
  GL_DRAW_FRAMEBUFFER     = 0x8CA9_u32
  GL_DEPTH_ATTACHMENT     = 0x8D00_u32
  GL_COLOR_ATTACHMENT0    = 0x8CE0_u32
  GL_FRAMEBUFFER_COMPLETE = 0x8CD5_u32
  GL_VIEWPORT             = 0x0BA2_u32
  GL_NONE                 =      0_u32

  fun glGenFramebuffers(n : GLsizei, framebuffers : GLuint*) : Void
  fun glBindFramebuffer(target : GLenum, framebuffer : GLuint) : Void
  fun glDeleteFramebuffers(n : GLsizei, framebuffers : GLuint*) : Void
  fun glFramebufferTexture2D(target : GLenum, attachment : GLenum, textarget : GLenum, texture : GLuint, level : GLint) : Void
  fun glCheckFramebufferStatus(target : GLenum) : GLenum
  fun glDrawBuffer(buf : GLenum) : Void
  fun glReadBuffer(src : GLenum) : Void

  # Polygon offset (for shadow mapping)
  GL_POLYGON_OFFSET_FILL = 0x8037_u32
  fun glPolygonOffset(factor : GLfloat, units : GLfloat) : Void

  # Polygon mode (wireframe)
  GL_POINT          = 0x1B00_u32
  GL_LINE           = 0x1B01_u32
  GL_FILL           = 0x1B02_u32
  GL_FRONT_AND_BACK = 0x0408_u32
  fun glPolygonMode(face : GLenum, mode : GLenum) : Void
  fun glLineWidth(width : GLfloat) : Void

  # State query
  GL_FRAMEBUFFER_BINDING = 0x8CA6_u32
  fun glGetIntegerv(pname : GLenum, data : GLint*) : Void
  fun glGetError : GLenum
end
