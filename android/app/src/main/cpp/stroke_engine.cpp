#include "stroke_engine.h"
#include "brush_textures_data.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define TAG "TSK_Stroke"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

namespace tsk {

// ═══════════════════════════════════════════════════════════════════════════════
// SHADERS
// ═══════════════════════════════════════════════════════════════════════════════

static const char* kVert =
"#version 300 es\n"
"precision highp float;\n"
"layout(location=0) in vec2 a_pos;\n"
"layout(location=1) in vec2 a_uv;\n"
"uniform vec2  u_center;\n"
"uniform float u_diameter;\n"
"uniform vec2  u_canvas;\n"
"uniform float u_rotation;\n"
"out vec2 v_uv;\n"
"void main(){\n"
"    float c=cos(u_rotation),s=sin(u_rotation);\n"
"    vec2 r=vec2(c*a_pos.x-s*a_pos.y, s*a_pos.x+c*a_pos.y);\n"
"    vec2 pos=u_center+r*u_diameter;\n"
"    vec2 uv=a_uv-0.5;\n"
"    v_uv=vec2(c*uv.x-s*uv.y,s*uv.x+c*uv.y)+0.5;\n"
"    gl_Position=vec4((pos/u_canvas)*2.0-1.0,0.0,1.0);\n"
"}\n";

// Fragment: shape + grain + noise procedural + flow accumulation
// uFlow 0.3-0.8: controla qué tan rápido se acumula el alpha
static const char* kFrag =
"#version 300 es\n"
"precision mediump float;\n"
"uniform sampler2D u_shape;\n"
"uniform sampler2D u_grain;\n"
"uniform vec4      u_color;\n"
"uniform float     u_hardness;\n"
"uniform float     u_flow;\n"
"uniform float     u_grainDepth;\n"
"uniform vec2      u_grainScale;\n"
"uniform vec2      u_canvasPos;\n"
"layout(location=0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
// Ruido procedural — rompe lo "digitalmente perfecto"
"float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}\n"
"float noise(vec2 p){\n"
"    vec2 i=floor(p),f=fract(p),u=f*f*(3.0-2.0*f);\n"
"    return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),\n"
"               mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);\n"
"}\n"
"void main(){\n"
"    float mask=texture(u_shape,v_uv).a;\n"
"    // Bordes suaves (smoothstep evita cortes duros)\n"
"    float h=min(u_hardness,0.999);\n"
"    float soft=smoothstep(0.15+0.35*h, 0.85-0.35*h, mask);\n"
"    // Noise procedural para variación orgánica per-pixel\n"
"    float n=noise(v_uv*10.0+u_canvasPos*0.007);\n"
"    soft*=(0.88+n*0.12);\n"
"    // Grain (textura de papel/carbón anclada al canvas)\n"
"    vec2 gUV=fract(u_canvasPos*u_grainScale);\n"
"    float grain=texture(u_grain,gUV).r;\n"
"    soft*=mix(1.0,grain,u_grainDepth);\n"
"    // Flow accumulation: controla qué tan opaco llega el stamp\n"
"    // Bajo flow=acumulación lenta (acuarela), alto flow=opaco rápido (tinta)\n"
"    float a=1.0-pow(1.0-soft, u_flow*2.0);\n"
"    fragColor=vec4(u_color.rgb, a);\n"
"}\n";

static const char* kEraserFrag =
"#version 300 es\n"
"precision mediump float;\n"
"uniform sampler2D u_shape;\n"
"uniform float     u_opacity;\n"
"uniform float     u_hardness;\n"
"layout(location=0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"void main(){\n"
"    float mask=texture(u_shape,v_uv).a;\n"
"    float h=min(u_hardness,0.999);\n"
"    float soft=smoothstep(0.15+0.35*h,0.85-0.35*h,mask);\n"
"    fragColor=vec4(0.0,0.0,0.0,u_opacity*soft);\n"
"}\n";

static const char* kCompositeVert =
"#version 300 es\n"
"precision highp float;\n"
"layout(location=0) in vec2 a_pos;\n"
"layout(location=1) in vec2 a_uv;\n"
"out vec2 v_uv;\n"
"void main(){gl_Position=vec4(a_pos*2.0,0.0,1.0);v_uv=a_uv;}\n";

static const char* kCompositeFrag =
"#version 300 es\n"
"precision mediump float;\n"
"uniform sampler2D u_strokeBuf;\n"
"uniform float     u_opacity;\n"
"layout(location=0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"void main(){\n"
"    vec4 s=texture(u_strokeBuf,v_uv);\n"
"    fragColor=vec4(s.rgb,s.a*u_opacity);\n"
"}\n";

static const float kQuad[]={
    -0.5f,-0.5f,0.f,0.f,  0.5f,-0.5f,1.f,0.f,
    -0.5f, 0.5f,0.f,1.f,  0.5f, 0.5f,1.f,1.f
};

// ── RNG simple ───────────────────────────────────────────────────────────────
static uint32_t s_seed=12345;
static float rnd(){s_seed^=s_seed<<13;s_seed^=s_seed>>17;s_seed^=s_seed<<5;return(s_seed&0x7FFFFFFF)/(float)0x7FFFFFFF;}
static float rnd(float lo,float hi){return lo+rnd()*(hi-lo);}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT / DESTROY
// ═══════════════════════════════════════════════════════════════════════════════

bool StrokeEngine::init(){
    while(glGetError()!=GL_NO_ERROR){}
    if(!initShaders()||!initQuad()){return false;}
    generateDefaultBrushTex();
    LOGI("StrokeEngine v3 OK (Catmull-Rom + StrokeBuffer + Flow)");
    return true;
}

void StrokeEngine::destroy(){
    destroyStrokeFBO();
    if(strokeProgram_)   {glDeleteProgram(strokeProgram_);   strokeProgram_=0;}
    if(eraserProgram_)   {glDeleteProgram(eraserProgram_);   eraserProgram_=0;}
    if(compositeProgram_){glDeleteProgram(compositeProgram_);compositeProgram_=0;}
    if(quadVBO_){glDeleteBuffers(1,&quadVBO_);quadVBO_=0;}
    if(quadVAO_){glDeleteVertexArrays(1,&quadVAO_);quadVAO_=0;}
    for(GLuint* t:{&defaultBrushTex_,&airbrushTex_,&charcoalTex_,
                   &inkTex_,&pencilTex_,&glowTex_,&watercolorTex_})
        if(*t){glDeleteTextures(1,t);*t=0;}
    for(auto& e:brushTextures_)glDeleteTextures(1,&e.tex);
    brushTextures_.clear();
    pointBuf_.clear();
}

// ═══════════════════════════════════════════════════════════════════════════════
// STROKE BUFFER FBO
// ═══════════════════════════════════════════════════════════════════════════════

bool StrokeEngine::ensureStrokeFBO(int w,int h){
    if(strokeFBO_&&strokeW_==w&&strokeH_==h)return true;
    destroyStrokeFBO();
    glGenFramebuffers(1,&strokeFBO_);
    glGenTextures(1,&strokeTex_);
    glBindTexture(GL_TEXTURE_2D,strokeTex_);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,nullptr);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
    glBindFramebuffer(GL_FRAMEBUFFER,strokeFBO_);
    glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,strokeTex_,0);
    bool ok=(glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE);
    strokeW_=w; strokeH_=h;
    glBindFramebuffer(GL_FRAMEBUFFER,layerFBO_);
    return ok;
}

void StrokeEngine::destroyStrokeFBO(){
    if(strokeTex_){glDeleteTextures(1,&strokeTex_);strokeTex_=0;}
    if(strokeFBO_){glDeleteFramebuffers(1,&strokeFBO_);strokeFBO_=0;}
    strokeW_=strokeH_=0;
}

void StrokeEngine::compositeStrokeToLayer(GLuint layerFBO){
    if(!compositeProgram_||!strokeFBO_||!strokeTex_)return;
    glBindFramebuffer(GL_FRAMEBUFFER,layerFBO);
    glViewport(0,0,strokeW_,strokeH_);
    glUseProgram(compositeProgram_);
    glEnable(GL_BLEND);
    // src-over para compositar el stroke buffer sobre el canvas
    glBlendEquationSeparate(GL_FUNC_ADD,GL_FUNC_ADD);
    glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,
                        GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,strokeTex_);
    glUniform1i(glGetUniformLocation(compositeProgram_,"u_strokeBuf"),0);
    glUniform1f(glGetUniformLocation(compositeProgram_,"u_opacity"),color_.a);
    glBindVertexArray(quadVAO_);
    glDrawArrays(GL_TRIANGLE_STRIP,0,4);
    glBindVertexArray(0);
    glDisable(GL_BLEND);
    glBlendEquationSeparate(GL_FUNC_ADD,GL_FUNC_ADD);
}

bool StrokeEngine::initCompositeShader(){
    GLuint cv=compileShader(GL_VERTEX_SHADER,kCompositeVert);
    GLuint cf=compileShader(GL_FRAGMENT_SHADER,kCompositeFrag);
    if(!cv||!cf){if(cv)glDeleteShader(cv);if(cf)glDeleteShader(cf);return false;}
    compositeProgram_=linkProgram(cv,cf);
    return compositeProgram_!=0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATMULL-ROM INTERPOLATION
// ═══════════════════════════════════════════════════════════════════════════════

static Point catmull(const Point& p0,const Point& p1,
                     const Point& p2,const Point& p3,float t){
    float t2=t*t, t3=t2*t;
    auto cmr=[&](float a,float b,float c,float d)->float{
        return 0.5f*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t2+(-a+3*b-3*c+d)*t3);
    };
    return {cmr(p0.x,p1.x,p2.x,p3.x),
            cmr(p0.y,p1.y,p2.y,p3.y),
            p1.pressure+(p2.pressure-p1.pressure)*t};
}

// ── Suavizado exponencial del punto entrante ──────────────────────────────────
static Point smooth(const Point& prev,const Point& cur,float k=0.65f){
    return {prev.x+k*(cur.x-prev.x),
            prev.y+k*(cur.y-prev.y),
            prev.pressure+k*(cur.pressure-prev.pressure)};
}

// ═══════════════════════════════════════════════════════════════════════════════
// STROKE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════════════════

void StrokeEngine::beginStroke(const Point& p,const BrushParams& brush,
                                const Color& color,int cw,int ch){
    brush_=brush; color_=color;
    canvasW_=cw; canvasH_=ch;
    lastPoint_=p; accDist_=0.0f; lastSpeed_=0.0f;
    active_=true;
    s_seed=(uint32_t)(p.x*1000+p.y);
    pointBuf_.clear();
    pointBuf_.push_back(p); // primer punto

    GLint fbo=0;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING,&fbo);
    layerFBO_=(GLuint)fbo;

    if(!brush_.isEraser&&ensureStrokeFBO(cw,ch)){
        // Limpiar stroke buffer — todos los stamps de este trazo van aquí
        glBindFramebuffer(GL_FRAMEBUFFER,strokeFBO_);
        glViewport(0,0,cw,ch);
        glClearColor(0,0,0,0);
        glClear(GL_COLOR_BUFFER_BIT);
        glBindFramebuffer(GL_FRAMEBUFFER,layerFBO_);
    }

    // Primer stamp en el punto inicial
    renderStampAt(p.x,p.y,p.pressure,brush_.size,rnd(0.f,6.28f));
}

bool StrokeEngine::addPoint(const Point& rawP){
    if(!active_)return false;

    // Suavizado de entrada
    Point p=smooth(lastPoint_,rawP);

    pointBuf_.push_back(p);
    if(pointBuf_.size()<2){lastPoint_=p;return false;}

    // Spacing dinámico: bajo (4% del tamaño) → denso → sin bolitas
    // Velocidad alta → un poco más separado (natural)
    float dx=p.x-lastPoint_.x, dy=p.y-lastPoint_.y;
    float dist=std::sqrt(dx*dx+dy*dy);
    lastSpeed_=dist*0.3f+lastSpeed_*0.7f;
    float spacing=std::max(brush_.spacingMinPx, brush_.size*(brush_.spacingBase+lastSpeed_*brush_.spacingVelocity));

    accDist_+=dist;
    bool rendered=false;

    // Catmull-Rom: usar los 4 últimos puntos para curva suave
    size_t n=pointBuf_.size();
    const Point& p0=(n>=4)?pointBuf_[n-4]:pointBuf_[0];
    const Point& p1=(n>=3)?pointBuf_[n-3]:pointBuf_[0];
    const Point& p2=pointBuf_[n-2];
    const Point& p3=pointBuf_[n-1];

    while(accDist_>=spacing){
        float t=(dist-(accDist_-spacing))/std::max(dist,0.001f);
        Point s=catmull(p0,p1,p2,p3,t);

        float diameter=s.pressure>0.05f
            ? brush_.size*(0.65f+s.pressure*0.35f)  // presión → tamaño
            : brush_.size;
        // Jitter mínimo — solo para imperfección orgánica, no para bolitas
        diameter*=(1.0f+rnd(-brush_.jitterSize,brush_.jitterSize));

        // Scatter controlado por jitter del pincel
        float sc=brush_.size*brush_.jitterPos;
        float sx=s.x+rnd(-sc,sc);
        float sy=s.y+rnd(-sc,sc);

        float rotation=rnd(0.f, brush_.jitterRot);
        renderStampAt(sx,sy,s.pressure,diameter,rotation);

        if(symmetryEnabled_&&!brush_.isEraser){
            float mx=symmetryAxis_==0?(float)canvasW_-sx:sx;
            float my=symmetryAxis_==0?sy:(float)canvasH_-sy;
            renderStampAt(mx,my,s.pressure,diameter,-rotation);
        }
        accDist_-=spacing;
        rendered=true;
    }
    lastPoint_=p;
    return rendered;
}

void StrokeEngine::endStroke(){
    if(active_&&!brush_.isEraser&&strokeFBO_){
        // COMMIT: compositar stroke buffer → canvas CON opacidad del usuario
        // Los stamps individuales tienen alpha=1 en el buffer → se fusionaron
        // Aquí se aplica la opacidad global UNA SOLA VEZ → sin bolitas
        compositeStrokeToLayer(layerFBO_);
        glBindFramebuffer(GL_FRAMEBUFFER,layerFBO_);
        glViewport(0,0,canvasW_,canvasH_);
    }
    active_=false;
    pointBuf_.clear();
}

void StrokeEngine::cancelStroke(){
    active_=false;
    pointBuf_.clear();
}

void StrokeEngine::stampAt(float x,float y){
    if(!active_)return;
    renderStampAt(x,y,1.0f,brush_.size,rnd(0.f,6.28f));
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER STAMP
// ═══════════════════════════════════════════════════════════════════════════════

void StrokeEngine::renderStamp(const Point& p,float diameterOverride){
    float d=diameterOverride>0?diameterOverride:brush_.size;
    if(!brush_.isEraser){
        d*=(0.65f+p.pressure*0.35f);
        d*=(1.0f+rnd(-0.02f,0.02f));
    }
    renderStampAt(p.x,p.y,p.pressure,d,rnd(0.f,6.28f));
}

void StrokeEngine::renderStampAt(float x,float y,float pressure,
                                  float diameter,float rotation){
    GLuint prog=brush_.isEraser?eraserProgram_:strokeProgram_;
    glUseProgram(prog);

    if(brush_.isEraser){
        // Borrador: dstOut directo → WYSIWYG
        glBindFramebuffer(GL_FRAMEBUFFER,layerFBO_);
        glViewport(0,0,canvasW_,canvasH_);
        glEnable(GL_BLEND);
        glBlendEquationSeparate(GL_FUNC_ADD,GL_FUNC_ADD);
        glBlendFuncSeparate(GL_ZERO,GL_ONE,GL_ZERO,GL_ONE_MINUS_SRC_ALPHA);
    } else if(strokeFBO_){
        // Pincel: al stroke buffer con src-over ESTÁNDAR
        // Stamps se fusionan → trazo continuo sin bolitas
        glBindFramebuffer(GL_FRAMEBUFFER,strokeFBO_);
        glViewport(0,0,canvasW_,canvasH_);
        glEnable(GL_BLEND);
        glBlendEquationSeparate(GL_FUNC_ADD,GL_FUNC_ADD);
        glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,
                            GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
    }

    glUniform2f(glGetUniformLocation(prog,"u_center"),x,y);
    glUniform1f(glGetUniformLocation(prog,"u_diameter"),diameter);
    glUniform2f(glGetUniformLocation(prog,"u_canvas"),(float)canvasW_,(float)canvasH_);
    glUniform1f(glGetUniformLocation(prog,"u_hardness"),brush_.hardness);
    glUniform1f(glGetUniformLocation(prog,"u_rotation"),rotation);

    if(brush_.isEraser){
        glUniform1f(glGetUniformLocation(prog,"u_opacity"),color_.a);
    } else {
        // Stamps en el buffer siempre a alpha=1
        // La opacidad del usuario se aplica en compositeStrokeToLayer
        glUniform4f(glGetUniformLocation(prog,"u_color"),
                    color_.r,color_.g,color_.b,1.0f);
        // Flow: controla acumulación dentro del stamp individual
        // 0.5=acuarela suave, 1.0=tinta opaca rápida
        float flow=brush_.grainDepth>0?0.6f:0.8f;
        glUniform1f(glGetUniformLocation(prog,"u_flow"),flow);
        glUniform1f(glGetUniformLocation(prog,"u_grainDepth"),brush_.grainDepth);
        glUniform2f(glGetUniformLocation(prog,"u_grainScale"),1.f/160.f,1.f/160.f);
        glUniform2f(glGetUniformLocation(prog,"u_canvasPos"),x,y);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D,getGrainTexture());
        glUniform1i(glGetUniformLocation(prog,"u_grain"),1);
    }
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,getBrushTexture());
    glUniform1i(glGetUniformLocation(prog,"u_shape"),0);
    glBindVertexArray(quadVAO_);
    glDrawArrays(GL_TRIANGLE_STRIP,0,4);
    glBindVertexArray(0);
    glDisable(GL_BLEND);
    glBlendEquationSeparate(GL_FUNC_ADD,GL_FUNC_ADD);
    glActiveTexture(GL_TEXTURE0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXTURAS
// ═══════════════════════════════════════════════════════════════════════════════

static GLuint loadAlpha(const uint8_t* a,int W){
    std::vector<uint8_t> rgba(W*W*4);
    for(int i=0;i<W*W;i++){
        rgba[i*4]=rgba[i*4+1]=rgba[i*4+2]=255;
        rgba[i*4+3]=a[i];
    }
    GLuint t;glGenTextures(1,&t);
    glBindTexture(GL_TEXTURE_2D,t);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,W,W,0,GL_RGBA,GL_UNSIGNED_BYTE,rgba.data());
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_REPEAT);
    glBindTexture(GL_TEXTURE_2D,0);
    return t;
}

void StrokeEngine::generateDefaultBrushTex(){
    constexpr int S=128;
    std::vector<uint8_t> a(S*S);
    float C=S/2.0f;
    for(int y=0;y<S;y++)for(int x=0;x<S;x++){
        float dx=(x+.5f-C)/C,dy=(y+.5f-C)/C;
        a[y*S+x]=(uint8_t)(std::max(0.f,std::exp(-2.5f*(dx*dx+dy*dy)))*255);
    }
    defaultBrushTex_=loadAlpha(a.data(),S);
    airbrushTex_   =loadAlpha(kAirbrushTex,  kBrushTexSize);
    charcoalTex_   =loadAlpha(kCharcoalTex,  kBrushTexSize);
    inkTex_        =loadAlpha(kInkTex,       kBrushTexSize);
    pencilTex_     =loadAlpha(kPencilTex,    kBrushTexSize);
    glowTex_       =loadAlpha(kGlowTex,      kBrushTexSize);
    watercolorTex_ =loadAlpha(kWatercolorTex,kBrushTexSize);
    LOGI("Brush textures: default+6 organic loaded");
}

GLuint StrokeEngine::getBrushTexture()const{
    if(brush_.brushTextureId>=0)
        for(auto& e:brushTextures_)if(e.id==brush_.brushTextureId)return e.tex;
    return getBrushTextureForCategory();
}

GLuint StrokeEngine::getBrushTextureForCategory()const{
    switch(brush_.brushTextureId){
        case -10:return airbrushTex_   ?airbrushTex_   :defaultBrushTex_;
        case -11:return charcoalTex_   ?charcoalTex_   :defaultBrushTex_;
        case -12:return inkTex_        ?inkTex_        :defaultBrushTex_;
        case -13:return pencilTex_     ?pencilTex_     :defaultBrushTex_;
        case -14:return glowTex_       ?glowTex_       :defaultBrushTex_;
        case -15:return watercolorTex_ ?watercolorTex_ :defaultBrushTex_;
        default: return defaultBrushTex_;
    }
}

GLuint StrokeEngine::getGrainTexture()const{
    if(brush_.grainTextureId>=0)
        for(auto& e:brushTextures_)if(e.id==brush_.grainTextureId)return e.tex;
    return defaultBrushTex_;
}

int StrokeEngine::loadBrushTexture(const uint8_t* rgba,int w,int h){
    GLuint tex;glGenTextures(1,&tex);
    glBindTexture(GL_TEXTURE_2D,tex);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,rgba);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_REPEAT);
    glBindTexture(GL_TEXTURE_2D,0);
    int id=nextBrushTexId_++;
    brushTextures_.push_back({id,tex,w,h});
    LOGI("loadBrushTexture %dx%d → id=%d",w,h,id);
    return id;
}

void StrokeEngine::unloadBrushTexture(int id){
    auto it=std::find_if(brushTextures_.begin(),brushTextures_.end(),
        [id](auto& e){return e.id==id;});
    if(it!=brushTextures_.end()){glDeleteTextures(1,&it->tex);brushTextures_.erase(it);}
}

// ═══════════════════════════════════════════════════════════════════════════════
// GL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

bool StrokeEngine::initShaders(){
    LOGI("Compiling shaders (Catmull-Rom + StrokeBuffer + Flow + Noise)...");
    auto mk=[&](const char* v,const char* f)->GLuint{
        GLuint vs=compileShader(GL_VERTEX_SHADER,v);
        GLuint fs=compileShader(GL_FRAGMENT_SHADER,f);
        if(!vs||!fs){if(vs)glDeleteShader(vs);if(fs)glDeleteShader(fs);return 0;}
        return linkProgram(vs,fs);
    };
    strokeProgram_=mk(kVert,kFrag);       if(!strokeProgram_)return false;
    eraserProgram_=mk(kVert,kEraserFrag); if(!eraserProgram_)return false;
    initCompositeShader();
    LOGI("All shaders OK");
    return true;
}

bool StrokeEngine::initQuad(){
    glGenVertexArrays(1,&quadVAO_);
    glGenBuffers(1,&quadVBO_);
    glBindVertexArray(quadVAO_);
    glBindBuffer(GL_ARRAY_BUFFER,quadVBO_);
    glBufferData(GL_ARRAY_BUFFER,sizeof(kQuad),kQuad,GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,16,(void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1,2,GL_FLOAT,GL_FALSE,16,(void*)8);
    glBindVertexArray(0);glBindBuffer(GL_ARRAY_BUFFER,0);
    return glGetError()==GL_NO_ERROR;
}

GLuint StrokeEngine::compileShader(GLenum type,const char* src){
    GLuint s=glCreateShader(type);if(!s)return 0;
    glShaderSource(s,1,&src,nullptr);glCompileShader(s);
    GLint ok=0;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if(!ok){char b[1024];glGetShaderInfoLog(s,1024,nullptr,b);LOGE("Shader fail:\n%s",b);glDeleteShader(s);return 0;}
    return s;
}

GLuint StrokeEngine::linkProgram(GLuint v,GLuint f){
    GLuint p=glCreateProgram();
    glAttachShader(p,v);glAttachShader(p,f);
    glLinkProgram(p);
    glDeleteShader(v);glDeleteShader(f);
    GLint ok=0;glGetProgramiv(p,GL_LINK_STATUS,&ok);
    if(!ok){char b[512];glGetProgramInfoLog(p,512,nullptr,b);LOGE("Link fail:%s",b);glDeleteProgram(p);return 0;}
    return p;
}

} // namespace tsk
