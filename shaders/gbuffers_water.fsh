#version 330 compatibility

uniform sampler2D gtexture;
uniform float frameTimeCounter;

in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 worldPos;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightLevelData;
layout(location = 2) out vec4 encodedNormal;

vec3 calculateWaterNormal(vec3 worldPosition) {
    float time = frameTimeCounter * 1.5; 
    float scale = 1.0; 

    float wave1 = sin(worldPosition.x * scale + time) * cos(worldPosition.z * scale + time);
    float wave2 = sin(worldPosition.x * scale * 2.0 - time) * cos(worldPosition.z * scale * 2.0 - time) * 0.5;
    
    float totalWave = (wave1 + wave2) * 0.1;

    vec3 waterNormal = vec3(totalWave, 1.0, totalWave);
    return normalize(waterNormal);
}

void main() {
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    vec3 finalNormal = normal;
    
    if (normal.y > 0.9) { 
        finalNormal = calculateWaterNormal(worldPos);
    }

    vec3 watercolor = vec3(0.02, 0.12, 0.22); 
    albedo.rgb = mix(albedo.rgb, watercolor, 0.9);

    vec3 viewVector = normalize(-worldPos); 
    float fresnel = pow(1.0 - max(dot(finalNormal, viewVector), 0.0), 4.0);
    albedo.a = mix(0.75, 0.95, fresnel); 

    color = albedo;
    lightLevelData = vec4(1.0); 
    encodedNormal = vec4(finalNormal * 0.5 + 0.5, 0.2); 
} 
