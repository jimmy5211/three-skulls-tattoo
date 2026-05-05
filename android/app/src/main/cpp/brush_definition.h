#pragma once
#include <string>
#include <vector>
#include <cstdint>

namespace tsk {

// ─── Curva de presión (4 puntos de control) ──────────────────────────────────
struct PressureCurve {
    float p0 = 0.0f;
    float p1 = 0.3f;
    float p2 = 0.7f;
    float p3 = 1.0f;

    // Evalúa la curva en [0,1] con interpolación lineal por tramos
    float evaluate(float t) const {
        t = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
        if (t < 0.333f) {
            float s = t / 0.333f;
            return p0 + (p1 - p0) * s;
        } else if (t < 0.666f) {
            float s = (t - 0.333f) / 0.333f;
            return p1 + (p2 - p1) * s;
        } else {
            float s = (t - 0.666f) / 0.334f;
            return p2 + (p3 - p2) * s;
        }
    }
};

// ─── Jitter (variación aleatoria) ────────────────────────────────────────────
struct JitterParams {
    float position = 0.03f;  // desplazamiento XY del stamp (fracción del tamaño)
    float size     = 0.02f;  // variación de tamaño (±%)
    float rotation = 6.28f;  // rotación aleatoria (radianes, 6.28 = libre 360°)
};

// ─── Spacing dinámico ────────────────────────────────────────────────────────
struct SpacingParams {
    float base             = 0.04f;  // fracción del tamaño base
    float velocityInfluence= 0.001f; // cuánto afecta la velocidad
    float minSpacing       = 1.0f;   // mínimo absoluto en píxeles
};

// ─── Definición completa de un pincel .tskbrush ──────────────────────────────
struct BrushDefinition {
    // Metadatos
    std::string id;
    std::string name;
    std::string category;
    int         version     = 1;

    // Tamaño y opacidad
    float size              = 25.0f;
    float opacity           = 1.0f;
    float hardness          = 0.8f;
    float flow              = 0.85f;

    // Spacing
    SpacingParams spacing;

    // Jitter
    JitterParams jitter;

    // Curva de presión
    PressureCurve pressureCurve;

    // Texturas (IDs después de cargar en GPU)
    int   shapeTexId        = -1;  // -1 = usar textura procedural del motor
    int   grainTexId        = -1;  // -1 = sin grain
    float grainDepth        = 0.3f;// intensidad del grain (0=sin, 1=máximo)

    // Textura orgánica interna del motor C++
    // -10=airbrush -11=charcoal -12=ink -13=pencil -14=glow -15=watercolor
    int   internalTexId     = -12; // ink por defecto

    // Rotación
    bool  followStroke      = true; // rota según dirección del trazo
    float randomRotation    = 6.28f;// 0=fijo, 6.28=libre

    // Flags
    bool  isEraser          = false;
    bool  isLoaded          = false;// true si los assets fueron cargados en GPU

    // Rutas de assets (relativas al .tskbrush)
    std::string shapeAsset; // "shape.png" o vacío si usa internalTexId
    std::string grainAsset; // "grain.png" o vacío

    // Preview PNG (para mostrar en la UI)
    std::vector<uint8_t> previewPng;
};

// ─── Catálogo de pinceles cargados ───────────────────────────────────────────
struct BrushCatalog {
    std::vector<BrushDefinition> brushes;

    const BrushDefinition* findById(const std::string& id) const {
        for (const auto& b : brushes)
            if (b.id == id) return &b;
        return nullptr;
    }
};

} // namespace tsk
