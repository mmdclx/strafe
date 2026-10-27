/// Native translation of the approved circular Contact echo prototype.
/// Geometry is radial in points; highlights may vary around the rim, but its radius never does.
enum ContactEchoShader {
    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;
    struct Uniforms {
        float4 screen;
        float4 material;
        float4 first;
        float4 second;
        float4 third;
    };
    struct Vertex { float4 position [[position]]; };
    vertex Vertex echoVertex(uint id [[vertex_id]]) {
        const float2 positions[] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
        return { float4(positions[id], 0, 1) };
    }
    float gaussian(float x, float w) { return exp(-x*x/(2*w*w)); }
    float radiusAt(float t) { return 8+50*(1-exp(-4*t)); }
    float envelopeAt(float t) { return smoothstep(0.0, .025, t)*(1-smoothstep(.55, 1.1, t)); }
    float heightAt(float dist, float t, float depth) {
        float bounce=-sin(t*21)*exp(-4.4*t);
        float q=dist-radiusAt(t);
        float h=10.5*bounce*gaussian(dist,19+18*t);
        h+=1.8*exp(-2.5*t)*gaussian(q,3.8+3*t);
        return h*depth*envelopeAt(t);
    }
    fragment float4 echoFragment(Vertex input [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
        float2 p=input.position.xy*u.screen.xy/u.screen.zw;
        float2 uv=p/u.screen.xy;
        float darkness=u.material.x, depth=u.material.y, shimmer=u.material.z;
        float3 base=mix(float3(243,244,239)/255, float3(38,41,34)/255, darkness);
        float flatbox=exp(-pow((uv.x*.8+uv.y*.55-.47)*4.8,2.0));
        float3 col=base+float3((flatbox-.45)*mix(.013,.020,darkness));
        float4 pulses[] = {u.first,u.second,u.third};
        for(int j=0;j<3;j++) {
            float4 pulse=pulses[j];
            if(pulse.w<=0) continue;
            float2 delta=p-pulse.xy;
            float dist=length(delta), t=pulse.z;
            float h=heightAt(dist,t,depth);
            float derivative=(heightAt(dist+.3,t,depth)-heightAt(dist-.3,t,depth))/.6;
            float2 gradient=delta/max(dist,.001)*derivative;
            float3 normal=normalize(float3(-gradient,1));
            float2 warped=uv+normal.xy*.11;
            float3 light=normalize(float3(-.45,-.65,1));
            float3 halfLight=normalize(light+float3(0,0,1));
            float lighting=dot(normal,light)-light.z;
            float spec=pow(max(dot(normal,halfLight),0.0),42.0)-pow(halfLight.z,42.0);
            float softbox=exp(-pow((warped.x*.8+warped.y*.55-.47)*4.8,2.0));
            float slope=length(normal.xy);
            float angle=slope>.00001 ? atan2(normal.y,normal.x) : 0;
            float phase=fract(.53+angle*.159154943+slope*1.7+h*.027+t*.12);
            float3 spectrum=mix(float3(.025,.16,1),float3(0,.94,1),smoothstep(0.0,.25,phase));
            spectrum=mix(spectrum,float3(1,.015,.57),smoothstep(.25,.55,phase));
            spectrum=mix(spectrum,float3(1,.70,.06),smoothstep(.55,.80,phase));
            spectrum=mix(spectrum,float3(.025,.16,1),smoothstep(.80,1.0,phase));
            float facing=pow(max(dot(normal.xy/max(slope,.0001),normalize(float2(-.55,-.8))),0.0),2.0);
            float glint=pow(max(spec,0.0),1.5)*1.65+exp(-pow((slope-.145)/.022,2.0))*.14*facing;
            float fold=smoothstep(.018,.10,slope)*(1-smoothstep(.38,.65,slope));
            float film=shimmer*glint*fold;
            col+=float3((softbox-flatbox)*.12);
            col+=float3(lighting*mix(.28,.24,darkness));
            col+=float3(spec*mix(.09,.22,darkness));
            col=mix(col,spectrum*mix(.78,1.0,darkness),clamp(film*1.35,0.0,.86));
            col+=float3(pow(max(spec,0.0),3.0)*.06);
            float rim=gaussian(dist-radiusAt(t),.72)*envelopeAt(t)*exp(-1.4*t);
            col+=float3(rim*mix(-.085,.11,darkness)*mix(1.0,2.5,u.material.w));
            col+=spectrum*rim*shimmer*.12;
        }
        for(int i=0;i<3;i++) {
            float4 r=pulses[i];
            if(r.w>0 && r.z<.13) {
                float radius=mix(4.5,1.0,clamp(r.z/.13,0.0,1.0));
                float alpha=(1-smoothstep(radius-.7,radius+.7,length(p-r.xy)))*(1-smoothstep(.035,.13,r.z));
                col=mix(col,mix(float3(.22,.25,.20),float3(.85,.88,.81),darkness),alpha*.8);
            }
        }
        return float4(clamp(col,0.0,1.0),1);
    }
    """#
}
