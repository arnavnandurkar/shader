#version 330 compatibility

out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 worldPos; 

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    
    normal = gl_NormalMatrix * gl_Normal;
    normal = mat3(gbufferModelViewInverse) * normal;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (gbufferModelViewInverse * viewPos).xyz;
}