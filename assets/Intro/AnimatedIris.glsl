// https://www.shadertoy.com/view/wtX3Dl
#define PI 3.1415926
#define PUPIL_RADIUS 0.12
#define IRIS_RADIUS 0.545
#define ALIASING 0.01
#define POW2(x) x*x

float hash(vec2 uv)
{
 	return fract(sin(dot(uv, vec2(20.974, 80.2171))) * 300.963);   
}

float noise(vec2 uv)
{
    vec2 f = smoothstep(0.0, 1.0, fract(uv));
 	vec2 uv00 = floor(uv);
    vec2 uv01 = uv00 + vec2(0,1);
    vec2 uv10 = uv00 + vec2(1,0);
    vec2 uv11 = uv00 + 1.0;
    
    float v00 = hash(uv00);
    float v01 = hash(uv01);
    float v10 = hash(uv10);
    float v11 = hash(uv11);
    
    float v0 = mix(v00, v01, f.y);
    float v1 = mix(v10, v11, f.y);
    
    return mix(v0, v1, f.x);
}

float radialNoise(vec2 uv, float dist, float noiseScale)
{
    //x - 360 angle mapped from 0 to 1
 	vec2 polarUV = vec2((atan(uv.y, uv.x) + PI) / (2.0 * PI), dist);
    
    //x - angle mapped drom 0 to noiseScale
    polarUV.x *= noiseScale;
    
    if(polarUV.x + 0.5 > noiseScale) polarUV.x -= noiseScale;
    
    //for debug
    	//polarUV.x = floor(polarUV.x);
    polarUV.x += hash(vec2(polarUV.y, 2.0)) * 834.1;
    
    return noise(polarUV);
}

float irisNoise(vec2 uv, float len, float deltaDist, float densityMultiplier, float distanceStart)
{
 	float dist = len + (radialNoise(uv, deltaDist, 30.0) - 0.5) * 0.1 + distanceStart;
    float lerpVal = fract(dist / deltaDist);
    
    float firstIndex = floor(dist / deltaDist);
    float secondIndex = firstIndex + 1.0;
    
    float firstDist = firstIndex * deltaDist;
    float secondDist = secondIndex * deltaDist;
    
    float firstDensity = firstIndex * densityMultiplier;
    float secondDensity = secondIndex * densityMultiplier;
    
    float firstNoise = radialNoise(uv, firstDist, firstDensity);
    float secondNoise = radialNoise(uv, secondDist, secondDensity);
    
    return mix(firstNoise, secondNoise, lerpVal);
}

float fractalNoise(vec2 uv, in float alphaMul, in float sizeMul, in float layers)
{
 	float fNoise = 0.0;
    float size = 1.0;
    float alpha = 1.0;
    for(float i = 0.0; i < layers; i++)
    {
        fNoise += noise(uv) * alpha;
        alpha *= alphaMul;
        size *= sizeMul;
    }
    
    fNoise /= layers;
    
    return fNoise;
}


void main(void)
{
	vec2 uv = (2.0 * gl_FragCoord.xy - iResolution.xy) / iResolution.x;

    float dist = length(uv);
    
    float pupilModifier = (1.0 - sqrt(noise(vec2(iTime * 0.5, 2.1))) * 0.75);
    float vDist = (-IRIS_RADIUS + dist) * pupilModifier;
    
    
    float pupilRadius = PUPIL_RADIUS;
    
    float pupil = 1.0 - smoothstep(pupilRadius, pupilRadius + ALIASING * pupilModifier, vDist + pupilRadius * 2.0);
    float pupil2 = 1.0 - smoothstep(pupilRadius * 1.05, pupilRadius * 1.05 + ALIASING * 4.0 * pupilModifier, vDist + pupilRadius * 2.0);
    float iris = irisNoise(uv, vDist,  0.015, 60.0, 0.15);
    float irisCenter = irisNoise(uv, vDist,  0.015, 120.0, 0.15);
    float irisDetails = irisNoise(uv, vDist,  0.016, 150.0, 0.14);
    float irisBorder = 1.0 - smoothstep(0.0, IRIS_RADIUS, abs(dist - IRIS_RADIUS));
    float irisWhiteBorder = 1.0 - smoothstep(0.0, 0.2 * (1.0 - pow(pupilModifier, 1.4)), abs(dist - IRIS_RADIUS + 0.001));
    float whiteEye = smoothstep(IRIS_RADIUS, IRIS_RADIUS + ALIASING * 3.0, dist);
    
    vec3 eye = smoothstep(-0.5, 1.0, iris) * vec3(0.8, 0.8, 0.5) * 0.9;
    eye = mix(eye, eye * irisDetails * irisDetails + irisWhiteBorder * 0.7 * vec3(0.6,1,1), 0.3);
    eye = mix(eye, eye * irisCenter * 0.3, pupil2);
    eye = mix(eye, vec3(0.0), pupil);
    eye = mix(eye, vec3(1.0), whiteEye);
    eye = mix(eye, vec3(irisBorder), 0.4);
    //eye = mix(eye, vec3(irisWhiteBorder) * irisDetails, 0.5);
    
    eye = smoothstep(0.1, 1.0, eye);
    
    float reflection = smoothstep(0.0, 1.0, 0.5 - distance(uv, vec2(0.16, 0.22))) * 1.2;

    gl_FragColor = vec4(eye + reflection, 1.0);
}
