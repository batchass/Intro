/*{
	"CREDIT" : "Speaker visualizer by Speaker visualizer",
	"CATEGORIES" : [
		"ci"
	],
	"DESCRIPTION": "",
	"INPUTS": [
		{
			"NAME": "inputImage",
			"TYPE" : "image"
		},
		{
			"NAME": "iZoom",
			"TYPE" : "float",
			"MIN" : 0.0,
			"MAX" : 1.0,
			"DEFAULT" : 1.0
		},
		{
			"NAME": "iSteps",
			"TYPE" : "float",
			"MIN" : 2.0,
			"MAX" : 75.0,
			"DEFAULT" : 19.0
		},
		{
			"NAME" :"iMouse",
			"TYPE" : "point2D",
			"DEFAULT" : [0.0, 0.0],
			"MAX" : [640.0, 480.0],
			"MIN" : [0.0, 0.0]
		},
		{
			"NAME": "iColor", 
			"TYPE" : "color", 
			"DEFAULT" : [
				0.9, 
				0.6, 
				0.0, 
				1.0
			]
		}
	],
}
*/
// https://www.shadertoy.com/view/wsdXDN
#define PI 3.14
#define TIME (iTime * 0.2)
#define RAYMARCH_ITERATIONS 50
#define FAR_PLANE 10.0
#define LIGHT_DIRECTION normalize(vec3(0.3, 0.3, (sin(TIME) + 1.0) * 0.1 + 0.03))
#define AMBIENT_LIGHT 0.05

//uncoment to disable denoising
#define DENOISE
#define DENOISE_STRENGTH 0.4

float hash13(vec3 x)
{
 	return fract(sin(dot(x, vec3(131.4211, 152.3422, 162.9441))) * 231.421);   
}
#define FREQ_STEP (1.0 / 512.0)
/*
void buf4(  )
{
    vec2 uv = gl_FragCoord / iResolution.xy;
    uv.x = uv.x * uv.x;
    float freq = 0.0;
    for (float bandOffset = -FREQ_STEP * 3.0; bandOffset < FREQ_STEP * 3.1; bandOffset += FREQ_STEP)
    {
        freq += texture(iChannel1, vec2(bandOffset + uv.x, 0.0)).x;
    }
    freq /= 7.0;
    freq = freq * freq;
    
    //for better preview xD
    if (iResolution.x < 419.0) freq = smoothstep(0.0, 0.6, freq);
    
    gl_FragColor = vec4(1.0, 0.0, 0.0, 0.0) * freq;
}

void bufB(  )
{
    vec2 uv = gl_FragCoord / iResolution.xy;
    
    float freq = 0.0;
    for (float bandOffset = -FREQ_STEP * 3.0; bandOffset < FREQ_STEP * 3.1; bandOffset += FREQ_STEP)
    {
        freq += texture(iChannel0, vec2(bandOffset + uv.x, 0.0)).x;
    }
    freq /= 7.0;
    freq = freq;
    
    freq = freq * 0.5 + texture(iChannel1, vec2(uv.x, 0.0)).x * 0.5;
    
    float line = smoothstep(0.005, 0.0, abs((uv.y - mod(uv.y, FREQ_STEP)) - freq));
    
    gl_FragColor = vec4(1.0, 0.0, 0.0, 0.0) * freq + vec4(0.0, 1.0, 0.0, 0.0) * line;
}*/
struct speakerData
{
  	float bigMovement;
    float smallMovement;
    float hash;
};
    
struct material
{
 	float metallic;
    float smoothness;
};

mat3x3 rotationMatrix(vec3 angle)
{
    return			
          mat3x3(cos(angle.y), 0.0, sin(angle.y),
                 0.0, 1.0, 0.0,
                 -sin(angle.y), 0.0, cos(angle.y))
        

        * mat3x3(1.0, 0.0, 0.0,
                 0.0, cos(angle.x), sin(angle.x),
                 0.0, -sin(angle.x), cos(angle.x))
            
        * mat3x3(cos(angle.z), sin(angle.z), 0.0,
                 -sin(angle.z), cos(angle.z), 0.0,
                 0.0, 0.0, 1.0);

        
}

float sphereSDF(vec3 point, vec3 sphereCenter, float radius)
{
 	float dist = distance(point, sphereCenter);
    return dist - radius;
}

float extrudeSDF(float sdf, float radius)
{
 	return sdf - radius;   
}

float ringSDF(vec3 point, float radius, float width, float height)
{
    float ring2D = abs(length(point.xy) - radius) - width;
    vec2 w = vec2( ring2D, abs(point.z) - height );
    return min(max(w.x,w.y),0.0) + length(max(w,0.0));
}

float torusSDF(vec3 point, float ringPosition, float ringRadius, float lineRadius)
{
    point.z -= ringPosition;
 	vec2 flattedUV = vec2(length(point.xy) - ringRadius, point.z);
    return length(flattedUV) - lineRadius;
}

float torusSDFRescaled(vec3 point, float ringPosition, float ringRadius, float lineRadius, vec3 scale)
{
    point.z -= ringPosition;
    point *= scale;
 	vec2 flattedUV = vec2(length(point.xy) - ringRadius, point.z);
    return length(flattedUV) - lineRadius;
}

float planeSDF(vec3 point, float planeZPos)
{
 	return point.z - planeZPos;   
}

float cylinderSDF(vec3 point, float radius)
{
 	return length(point.xy) - radius;   
}

float coneSDF( vec3 point, vec3 coneCenter, float angle)
{
    vec2 c = vec2(sin(angle), cos(angle));
    vec3 pos = point - coneCenter;
    
    return dot(c, vec2(length(pos.xy), pos.z));
}

float addObjectsSmooth(float obj1, float obj2, float smoothness ) 
{
    float h = clamp( 0.5 + 0.5 * (obj2-obj1) / smoothness, 0.0, 1.0 );
    return mix( obj2, obj1, h ) - smoothness * h * (1.0 - h); 
}

float addObjects(float object, float objectToAdd)
{
	return min(object, objectToAdd);
}

float multiplyObjects(float object, float objectToMul)
{
 	return max(object, objectToMul);   
}

float sdfObject(vec3 point, speakerData data)
{
    float movementRegion = smoothstep(2.12, 1.85, length(point.xy));
    point.z += movementRegion * 0.23 * data.bigMovement;
    point.z += (data.hash - 0.5) * data.smallMovement * movementRegion;
    
 	float object = 9999.9;
    object = addObjects(object, torusSDF(point, -0.04, 2.0, 0.1));
    float plane = multiplyObjects(planeSDF(point, 0.0), -sphereSDF(point, vec3(0.0), 2.0));
    object = addObjectsSmooth(object, plane, 0.01);
    
    float insideSpeaker = coneSDF(point, vec3(0.0, 0.0, -1.64), -0.7);
    
    float waves = smoothstep(0.45, 0.35, abs(length(point.xy) - 1.35));
    insideSpeaker -= max(sin(length(point.xy * 60.0)), -0.5) * 0.004 * waves;
    insideSpeaker = addObjectsSmooth(insideSpeaker, sphereSDF(point, vec3(0.0, 0.0, -1.94), 1.2), 0.04);
    insideSpeaker = multiplyObjects(insideSpeaker, sphereSDF(point, vec3(0.0), 1.911));
   
    object = addObjectsSmooth(object, insideSpeaker, 0.01);
    
    float frame = extrudeSDF(ringSDF(point - vec3(0.0, 0.0, 0.0), 2.25, 0.07, 0.005), 0.003);
    object = addObjectsSmooth(object, frame, 0.01);

    return object;
}

vec3 getNormal(vec3 hitPoint, speakerData data)
{
    float hitPointDist = sdfObject(hitPoint, data);
    vec3 normal = vec3(0.0, 0.0, 0.0);
    normal.x = -hitPointDist + sdfObject(hitPoint + vec3(1.0, 0.0, 0.0) * 0.001, data);
    normal.y = -hitPointDist + sdfObject(hitPoint + vec3(0.0, 1.0, 0.0) * 0.001, data);
    normal.z = -hitPointDist + sdfObject(hitPoint + vec3(0.0, 0.0, 1.0) * 0.001, data);
    return normalize(normal);
}


//xyz - hit point
vec3 rayMarch(vec3 rayOrigin, vec3 rayDirection, speakerData data)
{
    rayDirection = normalize(rayDirection);
	for (int i = 0; i < RAYMARCH_ITERATIONS; i++)
    {
        float distanceToObject = sdfObject(rayOrigin, data);
        rayOrigin += rayDirection * distanceToObject * 0.6;
    }
    
    return rayOrigin;
}

float lightDotRayMarch(vec3 rayOrigin, vec3 rayDirection, speakerData data)
{
    vec3 startRayOrigin = rayOrigin;
    rayDirection = normalize(rayDirection);
    float minDist = 10.0;
    float distanceToObject = 0.0;
	for (int i = 0; i < RAYMARCH_ITERATIONS; i++)
    {
        distanceToObject = sdfObject(rayOrigin, data);
        rayOrigin += rayDirection * distanceToObject * 0.7;
        
        minDist = min(minDist, abs(distanceToObject / distance(startRayOrigin, rayOrigin))); 
    }
    
    return minDist * smoothstep(0.0, 1.0, distanceToObject);
}



//x - diffuse
//y - specular
//z - shadow
vec3 getLight(vec3 hitPoint, vec3 normal, vec3 lightDirection, vec3 viewDirection, speakerData data, material mat)
{
	float diff = clamp(dot(normal, lightDirection), 0.0, 1.0);
    vec3 halfWay = normalize((lightDirection + viewDirection) * 0.5);
    float spec = pow(clamp(dot(normal, halfWay), 0.0, 1.0), mat.smoothness);
    
    float lightDot = lightDotRayMarch(hitPoint + lightDirection * 0.1, lightDirection, data);
    float shadow = smoothstep(0.0, 0.1, lightDot);
    
    return vec3(diff * (1.0 - mat.metallic), spec * mat.metallic, (shadow + AMBIENT_LIGHT) * 0.8);
}

//x - diffuse
//y - specular
vec2 getCheapLight(vec3 hitPoint, vec3 normal, vec3 lightDirection, vec3 viewDirection, speakerData data, material mat)
{
 	float diff = clamp(dot(normal, lightDirection), 0.0, 1.0);
    vec3 halfWay = normalize((lightDirection + viewDirection) * 0.5);
    float spec = pow(clamp(dot(normal, halfWay), 0.0, 1.0), mat.smoothness);
    
    return vec2(diff * (1.0 - mat.metallic), spec * mat.metallic);  
}

float musicVizualization(vec2 uv)
{
    float radius = 2.18;
    float bandsCount = 200.0;
    vec2 polarUV = vec2(atan(uv.y, uv.x), length(uv));
    polarUV.x += PI;
    polarUV.x /= PI * 2.0;
    
    
    float bandX = fract(polarUV.x * bandsCount);
    
    polarUV.x -= mod(polarUV.x, 1.0 / bandsCount);
    polarUV.x = pow(polarUV.x, 0.5);
    
    float border = smoothstep(0.4, 0.32, abs(bandX - 0.5));
    float freq = texture(iChannel0, vec2(polarUV.x * polarUV.x, polarUV.y)).x;
    freq *= freq * polarUV.x;
    freq = smoothstep(-0.04, 0.4, freq) * 0.15;
    return smoothstep(radius, radius + 0.01, polarUV.y) 
        * smoothstep(radius + freq, radius + freq - 0.01, polarUV.y)
        * border * freq * 7.0;
}

float musicVizualization2(vec2 uv)
{
 	float len = length(uv);
    len *= 9.0;
    float bandX = fract(len);
    
    
    
    float freq = texture(iChannel0, vec2(fract(floor(len /*+ TIME * 23.0*/) * 0.1 + 0.1), 0.0)).x; 
    freq *= length(uv) + 0.2;
    freq = smoothstep(0.0, 0.6, freq);
    freq *= freq * freq;
    
    float centerLight = smoothstep(2.0, 0.0, length(uv));
    centerLight *= pow(textureLod(iChannel0, vec2(0.3, 0.0), 0.5).x, 4.0) * 0.3;
    
    float borderWidth = 0.1 + centerLight * 3.0;
    float border = smoothstep(borderWidth, borderWidth - 0.01, abs(bandX - 0.5));
    
    return freq * border * (smoothstep(0.8, 0.6, length(uv))) 
        + centerLight + centerLight * smoothstep(0.8, 0.79, length(uv)) * 0.5;
}
/*
    //vec3 cameraCenter = vec3(sin(TIME * 3.5) * 2.7, cos(TIME * 3.5) * 2.7, cos(TIME * 3.0) * 0.5 + 1.1);
    vec3 cameraCenter = vec3(0.1, 1.1, -0.51);
    vec3 castPlaneCoord = castPlaneCoordFromUV(uv);
    
    vec3 angle = vec3(-0.67 - cos(TIME * 3.0) * 0.2, sin(TIME * 2.7) * 0.3, TIME * 3.5);
    //vec3 angle = vec3(-1.0,  1.3, 1.0);
    
        
    //castPlaneCoord *= rotationMatrix(angle);


*/
vec3 castPlaneCoordFromUV(vec2 uv)
{
	return vec3(uv.x, -0.4, uv.y); // was -0.8 = zoom
}
void main(void)
{
    vec2 uv = (2.0 * gl_FragCoord.xy - iResolution.xy) / iResolution.x;
    
    vec3 cameraCenter = vec3(sin(TIME * 3.5) * 2.7, cos(TIME * 3.5) * 2.7, cos(TIME * 3.0) * 0.5 + 1.1);
    vec3 castPlaneCoord = castPlaneCoordFromUV(uv);
    
    vec3 angle = vec3(-0.67 - cos(TIME * 3.0) * 0.2, sin(TIME * 2.7) * 0.3, TIME * 3.5);
    
        
    castPlaneCoord *= rotationMatrix(angle);
    
    vec3 rayOrigin = cameraCenter;
    vec3 rayDirection = castPlaneCoord;
    
    speakerData data;
    //data.bigMovement = sin(iTime * 100.0) * pow(textureLod(iChannel0, vec2(0.1, 0.0), 0.1).x * 1.0, 4.0) * 0.4;
    data.bigMovement = sin(iTime * 100.0) * iFreq0 * 0.04;

    //data.bigMovement += sin(iTime * 143.0) * pow(textureLod(iChannel0, vec2(0.05, 0.0), 0.1).x * 1.0, 4.0) * 0.4;
    data.bigMovement += sin(iTime * 143.0) * iFreq1 * 0.04;
    //data.bigMovement += sin(iTime * 50.0) * pow(textureLod(iChannel0, vec2(0.02, 0.0), 0.1).x * 1.0, 4.0) * 0.4;
    // particles
    data.smallMovement =  iFreq2 * 0.15;
    data.hash = smoothstep(0.0, 1.0, hash13(vec3(uv, sin(iTime * 0.1))));
    
    vec3 hitPoint = rayMarch(rayOrigin, rayDirection, data);
    float distanceToHitPoint = distance(cameraCenter, hitPoint);
    
    vec3 col = vec3(0.0);
    if (distanceToHitPoint < FAR_PLANE)
    {
        col = vec3(0.1);
        
        material mat;
        float centerRingRegion = smoothstep(0.55, 0.54, abs(length(hitPoint.xy) - 1.35));
        
        vec3 visColor = vec3(2.0, 0.0, 4.0);
        
        col += centerRingRegion * 0.7 * visColor;
        mat.metallic = mix(0.8, 0.6, centerRingRegion);
        mat.smoothness = mix(16.0, 4.0, centerRingRegion);
        
        vec3 normal = getNormal(hitPoint, data);
        data.hash = hash13(vec3(uv, sin(iTime * 0.1)));
        vec3 light = getLight(hitPoint, normal, LIGHT_DIRECTION, -rayDirection, data, mat);
        
        vec3 centerLightDirection = normalize(hitPoint - vec3(0.0, 0.0, -2.0));
        mat.metallic = 1.0;
        vec2 centerLight = getCheapLight(hitPoint, normal, -centerLightDirection, -rayDirection, data, mat);

        float musicBounce = pow(textureLod(iChannel0, vec2(0.3, 0.0), 0.5).x, 4.0) * 2.0;

        col = col * (light.x + light.y) * 0.4 * light.z * mix(visColor, vec3(1.0), 0.5) 
            + visColor * musicVizualization(hitPoint.xy) * smoothstep(-0.1, 0.2, musicBounce) * 0.6
            + visColor * musicVizualization2(hitPoint.xy);
        col += visColor * (centerLight.x + centerLight.y) * smoothstep(2.0, 1.0, length(hitPoint.xy)) * musicBounce * 3.0;
        col *= 2.4;
        col *= smoothstep(3.0, 2.4, length(hitPoint.xy));
        //col += mix(diffuse, diffuse2, 0.0);
    }
    

    // Output to screen
    float freq = texture(iChannel0, vec2(gl_FragCoord.xy / iResolution.xy)).y;
    //col = smoothstep(-0.07, 0.8, col);
    //gl_FragColor = vec4(1.0) * freq;
    gl_FragColor = vec4(col, 1.0);// * 0.7 + texture(iChannel0, gl_FragCoord.xy / iResolution.xy) * 0.3;
}
