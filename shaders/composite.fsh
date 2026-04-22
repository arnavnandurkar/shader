#version 330 compatibility
#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float frameTimeCounter; 

float hash(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
   
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5)); 
    
    for (int i = 0; i < 5; ++i) {
        value += amplitude * noise(p);
        p = rot * p * 2.0; 
        amplitude *= 0.5; 
    }
    return value;
}

const vec3 blocklightColor = vec3(1.0, 0.75, 0.35);
const vec3 skylightColorDay = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColorDay = vec3(1.0, 1.0, 1.0);
const vec3 ambientColorDay  = vec3(0.1, 0.1, 0.1);
const vec3 skylightColorNight = vec3(0.02, 0.03, 0.05); 
const vec3 moonlightColor     = vec3(0.015, 0.025, 0.04); 
const vec3 ambientColorNight  = vec3(0.01, 0.015, 0.02);


in vec2 texcoord;
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
   vec4 homPos = projectionMatrix * vec4(position, 1.0);
   return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos){
   
    if (shadowScreenPos.x < 0.0 || shadowScreenPos.x > 1.0 ||
        shadowScreenPos.y < 0.0 || shadowScreenPos.y > 1.0) {
        return vec3(1.0);
    }

    float shadowMapRes = 2048.0; 
    float texelSize = 1.0 / shadowMapRes;
    
    float visibility = 0.0;
    int samples = 0;
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            
            vec2 offset = vec2(x, y) * texelSize;
            
            float shadowDepth = texture(shadowtex0, shadowScreenPos.xy + offset).r;
           
            visibility += step(shadowScreenPos.z, shadowDepth);
            samples++;
        }
    }

    visibility /= float(samples);

    return vec3(visibility);
}

void main() {
    float sunElevation = dot(normalize(sunPosition), normalize(upPosition));
    float dayFactor = smoothstep(-0.1, 0.1, sunElevation);
    vec3 currentSkylightColor = mix(skylightColorNight, skylightColorDay, dayFactor);
    vec3 currentAmbientColor  = mix(ambientColorNight, ambientColorDay, dayFactor);
    vec3 currentSunlightColor = mix(moonlightColor, sunlightColorDay, dayFactor);
    
    vec4 normalData = texture(colortex2, texcoord);
    vec3 normal = normalize((normalData.rgb - 0.5) * 2.0);
    
    float trueDepth = texture(depthtex0, texcoord).r;
    float isWater = (normalData.a < 0.5 && trueDepth < 1.0) ? 1.0 : 0.0;
    vec2 fetchTexcoord = texcoord; 
    
    if (isWater > 0.5) {
      
        vec2 distortion = normal.xz * 0.02; 
        fetchTexcoord += distortion;
        fetchTexcoord = clamp(fetchTexcoord, 0.001, 0.999); 
    }

    vec2 lightmap = texture(colortex1, fetchTexcoord).xy;
    vec3 lightVector = normalize(shadowLightPosition);
    vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
    
    color = texture(colortex0, fetchTexcoord);
    color.rgb = pow(color.rgb, vec3(2.2));
  
    float depth = texture(depthtex0, fetchTexcoord).r;
    if (depth == 1.0) {
        vec3 ndcSky = vec3(fetchTexcoord.xy, 1.0) * 2.0 - 1.0;
        vec3 viewSky = projectAndDivide(gbufferProjectionInverse, ndcSky);
        vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewSky);
        if (worldDir.y > 0.05) { 
        float cloudHeight = 250.0; 
        float safeY = max(worldDir.y, 0.01); 
        float distanceToPlane = min(cloudHeight / safeY, 8000.0); 
        vec3 hitPos = worldDir * distanceToPlane;
        vec2 cloudCoord = hitPos.xz * 0.0015; 
            cloudCoord += vec2(10000.0); 
            cloudCoord.x += frameTimeCounter * 0.02;
            float noiseVal = fbm(cloudCoord);
            float cloudDensity = smoothstep(0.4, 0.65, noiseVal);
            float shadowNoise = fbm(cloudCoord + vec2(0.1));
            float cloudShadow = smoothstep(0.3, 0.7, shadowNoise);
            vec3 cloudColorDay = vec3(1.0, 1.0, 1.0); 
            vec3 cloudColorNight = vec3(0.04, 0.06, 0.1); 
            vec3 currentCloudColor = mix(cloudColorNight, cloudColorDay, dayFactor);
            currentCloudColor = mix(currentCloudColor, currentCloudColor * 0.4, cloudShadow);
           float horizonFade = smoothstep(0.15, 0.35, worldDir.y);
            float finalCloudAlpha = cloudDensity * horizonFade;
            color.rgb = mix(color.rgb, currentCloudColor, finalCloudAlpha);
        }
        color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
        return;
    }
    vec3 ndcPos = vec3(fetchTexcoord.xy, depth) * 2.0 - 1.0;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz; 
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    shadowClipPos.z -= 0.001;
    shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
    vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
    vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;
    vec3 shadow = getShadow(shadowScreenPos);
    vec3 blocklight = lightmap.x * blocklightColor;
    vec3 skylight = lightmap.y * currentSkylightColor;
    vec3 ambient = currentAmbientColor;
    vec3 sunlight = currentSunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow;

    color.rgb *= blocklight + skylight + ambient + sunlight;
    if (isWater > 0.5) {
        vec3 viewVector = normalize(viewPos);
        float waterFresnel = pow(1.0 - max(dot(normal, -viewVector), 0.0), 4.0);
        vec3 reflectionColor = currentSkylightColor * 1.5; 
        vec3 reflectDir = reflect(viewVector, normal);
        float sunHighlight = pow(max(dot(reflectDir, worldLightVector), 0.0), 250.0);
        reflectionColor += currentSunlightColor * sunHighlight * 5.0 * shadow;
        color.rgb = mix(color.rgb, reflectionColor, waterFresnel);
    }
    float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 grayscaleColor = vec3(luma);
    vec3 nightTextureColor = mix(grayscaleColor, color.rgb, 0.80);
    color.rgb = mix(nightTextureColor, color.rgb, dayFactor);
    color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}