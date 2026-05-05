#include "tskbrush_loader.h"
#include <android/log.h>
#include <fstream>
#include <sstream>
#include <dirent.h>
#include <sys/stat.h>
#include <cstring>
#include <cmath>

// ── PNG decoder (stb_image, ya incluido en el proyecto) ───────────────────────
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#include "stb_image.h"
// stb_image_write stub — activo cuando se use save()
#ifndef stbi_write_png_to_mem
static inline unsigned char* stbi_write_png_to_mem(
    const unsigned char*, int, int, int, int, int* len) {
    if (len) *len = 0; return nullptr;
}
#define STBIW_FREE(p) free(p)
#endif

// ── ZIP stub (miniz amalgamation pendiente) ───────────────────────────────────
// El ZIP real se activa cuando se sube miniz.h de la carpeta amalgamation/
// Por ahora las funciones ZIP retornan vacío — el loader carga JSON inline.
#define MZ_ZIP_NO_STDIO
typedef unsigned char mz_uint8;
typedef unsigned int  mz_uint;
typedef unsigned long mz_ulong;
struct mz_zip_archive { void* m_pState; };
struct mz_zip_archive_file_stat { size_t m_uncomp_size; };
static inline bool mz_zip_reader_init_mem(mz_zip_archive*, const void*, size_t, int) { return false; }
static inline int  mz_zip_reader_locate_file(mz_zip_archive*, const char*, const char*, int) { return -1; }
static inline bool mz_zip_reader_file_stat(mz_zip_archive*, int, mz_zip_archive_file_stat*) { return false; }
static inline bool mz_zip_reader_extract_to_mem(mz_zip_archive*, int, void*, size_t, int) { return false; }
static inline void mz_zip_reader_end(mz_zip_archive*) {}
static inline bool mz_zip_writer_init_file(mz_zip_archive*, const char*, int) { return false; }
static inline bool mz_zip_writer_add_mem(mz_zip_archive*, const char*, const void*, size_t, int) { return false; }
static inline bool mz_zip_writer_finalize_archive(mz_zip_archive*) { return false; }
static inline void mz_zip_writer_end(mz_zip_archive*) {}
#define MZ_BEST_COMPRESSION 9

#define TAG "TSK_BrushLoader"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

namespace tsk {

// ─────────────────────────────────────────────────────────────────────────────
// JSON PARSER MÍNIMO (sin dependencias externas)
// .tskbrush usa JSON simple — no necesitamos un parser completo
// ─────────────────────────────────────────────────────────────────────────────

static std::string jsonString(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    pos = json.find(':', pos + search.size());
    if (pos == std::string::npos) return "";
    pos = json.find('"', pos + 1);
    if (pos == std::string::npos) return "";
    size_t end = json.find('"', pos + 1);
    if (end == std::string::npos) return "";
    return json.substr(pos + 1, end - pos - 1);
}

static float jsonFloat(const std::string& json, const std::string& key, float def = 0.0f) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return def;
    pos = json.find(':', pos + search.size());
    if (pos == std::string::npos) return def;
    // Saltar espacios
    pos++;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) pos++;
    try { return std::stof(json.substr(pos)); }
    catch (...) { return def; }
}

static int jsonInt(const std::string& json, const std::string& key, int def = 0) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return def;
    pos = json.find(':', pos + search.size());
    if (pos == std::string::npos) return def;
    pos++;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) pos++;
    try { return std::stoi(json.substr(pos)); }
    catch (...) { return def; }
}

static bool jsonBool(const std::string& json, const std::string& key, bool def = false) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return def;
    pos = json.find(':', pos + search.size());
    if (pos == std::string::npos) return def;
    pos++;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) pos++;
    return json.substr(pos, 4) == "true";
}

// Extrae un sub-objeto JSON { ... } dado su clave
static std::string jsonObject(const std::string& json, const std::string& key) {
    std::string search = "\"" + key + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "{}";
    pos = json.find('{', pos);
    if (pos == std::string::npos) return "{}";
    int depth = 0;
    size_t start = pos;
    for (size_t i = pos; i < json.size(); i++) {
        if (json[i] == '{') depth++;
        else if (json[i] == '}') { depth--; if (depth == 0) return json.substr(start, i - start + 1); }
    }
    return "{}";
}

// ─────────────────────────────────────────────────────────────────────────────
// PARSE JSON → BrushDefinition
// ─────────────────────────────────────────────────────────────────────────────

bool TskBrushLoader::parseJson(const std::string& json, BrushDefinition& out) {
    out.name        = jsonString(json, "name");
    out.id          = jsonString(json, "id");
    out.category    = jsonString(json, "category");
    out.version     = jsonInt   (json, "version", 1);

    out.size        = jsonFloat (json, "size",     25.0f);
    out.opacity     = jsonFloat (json, "opacity",   1.0f);
    out.hardness    = jsonFloat (json, "hardness",  0.8f);
    out.flow        = jsonFloat (json, "flow",      0.85f);
    out.grainDepth  = jsonFloat (json, "grainDepth",0.3f);
    out.internalTexId = jsonInt (json, "internalTexId", -12);

    out.shapeAsset  = jsonString(json, "shape");
    out.grainAsset  = jsonString(json, "grain");

    out.followStroke   = jsonBool (json, "followStroke", true);
    out.randomRotation = jsonFloat(json, "randomRotation", 6.28f);
    out.isEraser       = jsonBool (json, "isEraser", false);

    // Spacing
    std::string sp = jsonObject(json, "spacing");
    out.spacing.base              = jsonFloat(sp, "base",              0.04f);
    out.spacing.velocityInfluence = jsonFloat(sp, "velocityInfluence", 0.001f);
    out.spacing.minSpacing        = jsonFloat(sp, "minSpacing",        1.0f);

    // Jitter
    std::string jt = jsonObject(json, "jitter");
    out.jitter.position = jsonFloat(jt, "position", 0.03f);
    out.jitter.size     = jsonFloat(jt, "size",     0.02f);
    out.jitter.rotation = jsonFloat(jt, "rotation", 6.28f);

    // Curva de presión
    std::string pc = jsonObject(json, "pressureCurve");
    out.pressureCurve.p0 = jsonFloat(pc, "p0", 0.0f);
    out.pressureCurve.p1 = jsonFloat(pc, "p1", 0.3f);
    out.pressureCurve.p2 = jsonFloat(pc, "p2", 0.7f);
    out.pressureCurve.p3 = jsonFloat(pc, "p3", 1.0f);

    if (out.name.empty()) {
        LOGE("JSON parse error: missing 'name' field");
        return false;
    }
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// PNG DECODE
// ─────────────────────────────────────────────────────────────────────────────

bool TskBrushLoader::decodePng(const uint8_t* data, size_t size,
                                std::vector<uint8_t>& rgba, int& w, int& h) {
    int comp = 0;
    uint8_t* pixels = stbi_load_from_memory(data, (int)size, &w, &h, &comp, 4);
    if (!pixels) {
        LOGE("PNG decode failed: %s", stbi_failure_reason());
        return false;
    }
    rgba.assign(pixels, pixels + w * h * 4);
    stbi_image_free(pixels);
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// ZIP ENTRY READ (via miniz)
// ─────────────────────────────────────────────────────────────────────────────

bool TskBrushLoader::readZipEntry(const uint8_t* zipData, size_t zipSize,
                                   const std::string& entryName,
                                   std::vector<uint8_t>& out) {
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));

    if (!mz_zip_reader_init_mem(&zip, zipData, zipSize, 0)) {
        LOGE("Failed to open ZIP in memory");
        return false;
    }

    int idx = mz_zip_reader_locate_file(&zip, entryName.c_str(), nullptr, 0);
    if (idx < 0) {
        mz_zip_reader_end(&zip);
        return false; // entrada no existe (no es error fatal)
    }

    mz_zip_archive_file_stat stat;
    if (!mz_zip_reader_file_stat(&zip, idx, &stat)) {
        mz_zip_reader_end(&zip);
        return false;
    }

    out.resize(stat.m_uncomp_size);
    if (!mz_zip_reader_extract_to_mem(&zip, idx, out.data(), out.size(), 0)) {
        LOGE("Failed to extract '%s' from ZIP", entryName.c_str());
        mz_zip_reader_end(&zip);
        return false;
    }

    mz_zip_reader_end(&zip);
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// LOAD FROM MEMORY
// ─────────────────────────────────────────────────────────────────────────────

LoadResult TskBrushLoader::loadFromMemory(const uint8_t* data, size_t size,
                                           BrushDefinition& out) {
    // 1. Extraer brush.json del ZIP
    std::vector<uint8_t> jsonBytes;
    if (!readZipEntry(data, size, "brush.json", jsonBytes)) {
        LOGE("brush.json not found in .tskbrush");
        return LoadResult::INVALID_FORMAT;
    }

    std::string json(jsonBytes.begin(), jsonBytes.end());
    if (!parseJson(json, out)) {
        return LoadResult::JSON_PARSE_ERROR;
    }

    // 2. Cargar shape.png si existe
    if (!out.shapeAsset.empty()) {
        std::vector<uint8_t> shapePng;
        if (readZipEntry(data, size, out.shapeAsset, shapePng)) {
            std::vector<uint8_t> rgba;
            int w = 0, h = 0;
            if (decodePng(shapePng.data(), shapePng.size(), rgba, w, h)) {
                int id = uploadFn_(rgba.data(), w, h);
                if (id >= 0) {
                    out.shapeTexId = id;
                    LOGI("Shape texture loaded: %dx%d → id=%d", w, h, id);
                } else {
                    LOGE("GPU upload failed for shape texture");
                    return LoadResult::GPU_UPLOAD_FAILED;
                }
            }
        }
    }

    // 3. Cargar grain.png si existe (opcional)
    if (!out.grainAsset.empty()) {
        std::vector<uint8_t> grainPng;
        if (readZipEntry(data, size, out.grainAsset, grainPng)) {
            std::vector<uint8_t> rgba;
            int w = 0, h = 0;
            if (decodePng(grainPng.data(), grainPng.size(), rgba, w, h)) {
                int id = uploadFn_(rgba.data(), w, h);
                if (id >= 0) {
                    out.grainTexId = id;
                    LOGI("Grain texture loaded: %dx%d → id=%d", w, h, id);
                }
            }
        }
    }

    // 4. Cargar preview.png si existe
    readZipEntry(data, size, "preview.png", out.previewPng);

    out.isLoaded = true;
    LOGI("Brush '%s' loaded OK (shape=%d grain=%d)",
         out.name.c_str(), out.shapeTexId, out.grainTexId);
    return LoadResult::OK;
}

// ─────────────────────────────────────────────────────────────────────────────
// LOAD FROM DISK
// ─────────────────────────────────────────────────────────────────────────────

LoadResult TskBrushLoader::load(const std::string& path, BrushDefinition& out) {
    std::ifstream f(path, std::ios::binary);
    if (!f.is_open()) {
        LOGE("File not found: %s", path.c_str());
        return LoadResult::FILE_NOT_FOUND;
    }
    std::vector<uint8_t> data((std::istreambuf_iterator<char>(f)),
                               std::istreambuf_iterator<char>());
    f.close();
    return loadFromMemory(data.data(), data.size(), out);
}

// ─────────────────────────────────────────────────────────────────────────────
// PARSE METADATA ONLY (sin GPU upload)
// ─────────────────────────────────────────────────────────────────────────────

LoadResult TskBrushLoader::parseMetadata(const std::string& path, BrushDefinition& out) {
    std::ifstream f(path, std::ios::binary);
    if (!f.is_open()) return LoadResult::FILE_NOT_FOUND;
    std::vector<uint8_t> data((std::istreambuf_iterator<char>(f)),
                               std::istreambuf_iterator<char>());
    f.close();

    std::vector<uint8_t> jsonBytes;
    if (!readZipEntry(data.data(), data.size(), "brush.json", jsonBytes))
        return LoadResult::INVALID_FORMAT;

    std::string json(jsonBytes.begin(), jsonBytes.end());
    if (!parseJson(json, out)) return LoadResult::JSON_PARSE_ERROR;

    // Preview
    readZipEntry(data.data(), data.size(), "preview.png", out.previewPng);
    return LoadResult::OK;
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERATE JSON
// ─────────────────────────────────────────────────────────────────────────────

std::string TskBrushLoader::generateJson(const BrushDefinition& def) {
    std::ostringstream o;
    o << "{\n";
    o << "  \"id\": \""       << def.id       << "\",\n";
    o << "  \"name\": \""     << def.name     << "\",\n";
    o << "  \"category\": \"" << def.category << "\",\n";
    o << "  \"version\": "    << def.version  << ",\n";
    o << "  \"size\": "       << def.size     << ",\n";
    o << "  \"opacity\": "    << def.opacity  << ",\n";
    o << "  \"hardness\": "   << def.hardness << ",\n";
    o << "  \"flow\": "       << def.flow     << ",\n";
    o << "  \"grainDepth\": " << def.grainDepth << ",\n";
    o << "  \"internalTexId\": " << def.internalTexId << ",\n";
    if (!def.shapeAsset.empty())
        o << "  \"shape\": \"" << def.shapeAsset << "\",\n";
    if (!def.grainAsset.empty())
        o << "  \"grain\": \"" << def.grainAsset << "\",\n";
    o << "  \"followStroke\": "    << (def.followStroke ? "true" : "false") << ",\n";
    o << "  \"randomRotation\": "  << def.randomRotation << ",\n";
    o << "  \"isEraser\": "        << (def.isEraser ? "true" : "false") << ",\n";
    o << "  \"spacing\": {\n";
    o << "    \"base\": "              << def.spacing.base              << ",\n";
    o << "    \"velocityInfluence\": " << def.spacing.velocityInfluence << ",\n";
    o << "    \"minSpacing\": "        << def.spacing.minSpacing        << "\n";
    o << "  },\n";
    o << "  \"jitter\": {\n";
    o << "    \"position\": " << def.jitter.position << ",\n";
    o << "    \"size\": "     << def.jitter.size     << ",\n";
    o << "    \"rotation\": " << def.jitter.rotation << "\n";
    o << "  },\n";
    o << "  \"pressureCurve\": {\n";
    o << "    \"p0\": " << def.pressureCurve.p0 << ",\n";
    o << "    \"p1\": " << def.pressureCurve.p1 << ",\n";
    o << "    \"p2\": " << def.pressureCurve.p2 << ",\n";
    o << "    \"p3\": " << def.pressureCurve.p3 << "\n";
    o << "  }\n";
    o << "}\n";
    return o.str();
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE TO DISK
// ─────────────────────────────────────────────────────────────────────────────

bool TskBrushLoader::save(const BrushDefinition& def,
                           const std::string& path,
                           const std::vector<uint8_t>& shapeRgba,
                           int shapeW, int shapeH,
                           const std::vector<uint8_t>& grainRgba,
                           int grainW, int grainH) {
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));

    if (!mz_zip_writer_init_file(&zip, path.c_str(), 0)) {
        LOGE("Cannot create ZIP at: %s", path.c_str());
        return false;
    }

    // brush.json
    std::string json = generateJson(def);
    mz_zip_writer_add_mem(&zip, "brush.json",
                          json.c_str(), json.size(),
                          MZ_BEST_COMPRESSION);

    // shape.png (si hay píxeles)
    if (!shapeRgba.empty() && shapeW > 0 && shapeH > 0) {
        int pngLen = 0;
        void* pngData = stbi_write_png_to_mem(
            (const unsigned char*)shapeRgba.data(),
            shapeW * 4, shapeW, shapeH, 4, &pngLen);
        if (pngData && pngLen > 0) {
            mz_zip_writer_add_mem(&zip, "shape.png", pngData, pngLen, MZ_BEST_COMPRESSION);
            STBIW_FREE(pngData);
        }
    }

    // grain.png (si hay píxeles)
    if (!grainRgba.empty() && grainW > 0 && grainH > 0) {
        int pngLen = 0;
        void* pngData = stbi_write_png_to_mem(
            (const unsigned char*)grainRgba.data(),
            grainW * 4, grainW, grainH, 4, &pngLen);
        if (pngData && pngLen > 0) {
            mz_zip_writer_add_mem(&zip, "grain.png", pngData, pngLen, MZ_BEST_COMPRESSION);
            STBIW_FREE(pngData);
        }
    }

    mz_zip_writer_finalize_archive(&zip);
    mz_zip_writer_end(&zip);
    LOGI("Brush '%s' saved to: %s", def.name.c_str(), path.c_str());
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN DIRECTORY
// ─────────────────────────────────────────────────────────────────────────────

std::vector<std::string> TskBrushLoader::scanDirectory(const std::string& dir) {
    std::vector<std::string> result;
    DIR* d = opendir(dir.c_str());
    if (!d) return result;
    struct dirent* entry;
    while ((entry = readdir(d)) != nullptr) {
        std::string name = entry->d_name;
        if (name.size() > 9 && name.substr(name.size() - 9) == ".tskbrush")
            result.push_back(dir + "/" + name);
    }
    closedir(d);
    return result;
}

} // namespace tsk
