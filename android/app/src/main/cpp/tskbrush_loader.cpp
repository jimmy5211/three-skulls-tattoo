#include "tskbrush_loader.h"
#include <android/log.h>
#include <fstream>
#include <sstream>
#include <dirent.h>
#include <sys/stat.h>
#include <cstring>
#include <cmath>

// ── PNG decoder (stb_image) ──────────────────────────────────────────────────
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#include "stb_image.h"

// ── stb_image_write para save() ──────────────────────────────────────────────
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

// ── ZIP real con zlib del NDK (sin dependencias externas) ────────────────────
#include <zlib.h>
#include <cstdint>
#include <cstring>

// ── Estructuras ZIP ──────────────────────────────────────────────────────────
#pragma pack(push, 1)
struct ZipLocalHeader {
    uint32_t sig;           // 0x04034b50
    uint16_t version;
    uint16_t flags;
    uint16_t compression;   // 0=store, 8=deflate
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compSize;
    uint32_t uncompSize;
    uint16_t nameLen;
    uint16_t extraLen;
};
struct ZipCentralDir {
    uint32_t sig;           // 0x02014b50
    uint16_t versionMade;
    uint16_t versionNeeded;
    uint16_t flags;
    uint16_t compression;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compSize;
    uint32_t uncompSize;
    uint16_t nameLen;
    uint16_t extraLen;
    uint16_t commentLen;
    uint16_t diskStart;
    uint16_t intAttr;
    uint32_t extAttr;
    uint32_t localOffset;
};
struct ZipEOCD {
    uint32_t sig;           // 0x06054b50
    uint16_t diskNum;
    uint16_t diskStart;
    uint16_t entriesOnDisk;
    uint16_t totalEntries;
    uint32_t cdSize;
    uint32_t cdOffset;
    uint16_t commentLen;
};
#pragma pack(pop)

// ── ZIP Reader ────────────────────────────────────────────────────────────────

static bool zipFindEntry(const uint8_t* zip, size_t zipSize,
                          const std::string& name,
                          std::vector<uint8_t>& out) {
    if (zipSize < sizeof(ZipEOCD)) return false;

    // Buscar EOCD desde el final
    int64_t eocdPos = -1;
    for (int64_t i = (int64_t)zipSize - 4; i >= 0; i--) {
        if (zip[i] == 0x50 && zip[i+1] == 0x4b &&
            zip[i+2] == 0x05 && zip[i+3] == 0x06) {
            eocdPos = i; break;
        }
    }
    if (eocdPos < 0) return false;

    const ZipEOCD* eocd = reinterpret_cast<const ZipEOCD*>(zip + eocdPos);
    uint32_t cdOffset = eocd->cdOffset;
    uint16_t total    = eocd->totalEntries;

    // Iterar Central Directory
    size_t pos = cdOffset;
    for (int i = 0; i < total && pos + sizeof(ZipCentralDir) <= zipSize; i++) {
        const ZipCentralDir* cd = reinterpret_cast<const ZipCentralDir*>(zip + pos);
        if (cd->sig != 0x02014b50) break;

        std::string entryName((const char*)(zip + pos + sizeof(ZipCentralDir)), cd->nameLen);
        pos += sizeof(ZipCentralDir) + cd->nameLen + cd->extraLen + cd->commentLen;

        if (entryName != name) continue;

        // Ir a Local Header
        size_t lhPos = cd->localOffset;
        if (lhPos + sizeof(ZipLocalHeader) > zipSize) return false;
        const ZipLocalHeader* lh = reinterpret_cast<const ZipLocalHeader*>(zip + lhPos);
        if (lh->sig != 0x04034b50) return false;

        size_t dataOffset = lhPos + sizeof(ZipLocalHeader) + lh->nameLen + lh->extraLen;
        if (dataOffset + lh->compSize > zipSize) return false;
        const uint8_t* compData = zip + dataOffset;

        if (lh->compression == 0) {
            // Store — sin compresión
            out.assign(compData, compData + lh->uncompSize);
            return true;
        } else if (lh->compression == 8) {
            // Deflate con zlib
            out.resize(lh->uncompSize);
            z_stream zs{};
            zs.next_in  = const_cast<uint8_t*>(compData);
            zs.avail_in = lh->compSize;
            zs.next_out = out.data();
            zs.avail_out= lh->uncompSize;
            if (inflateInit2(&zs, -MAX_WBITS) != Z_OK) return false;
            int r = inflate(&zs, Z_FINISH);
            inflateEnd(&zs);
            return r == Z_STREAM_END;
        }
        return false;
    }
    return false;
}

// ── ZIP Writer ────────────────────────────────────────────────────────────────

struct ZipEntry {
    std::string name;
    std::vector<uint8_t> data; // datos ya comprimidos
    uint32_t uncompSize;
    uint32_t crc;
    uint16_t compression;      // 0=store, 8=deflate
};

static uint32_t zipCrc32(const uint8_t* data, size_t size) {
    return (uint32_t)crc32(0, data, (uInt)size);
}

static bool zipCompress(const uint8_t* in, size_t inSize,
                         std::vector<uint8_t>& out) {
    uLongf bound = compressBound(inSize);
    out.resize(bound);
    // Usar deflate raw (-MAX_WBITS) para formato ZIP
    z_stream zs{};
    zs.next_in   = const_cast<uint8_t*>(in);
    zs.avail_in  = (uInt)inSize;
    zs.next_out  = out.data();
    zs.avail_out = (uInt)bound;
    if (deflateInit2(&zs, Z_BEST_COMPRESSION, Z_DEFLATED,
                     -MAX_WBITS, 8, Z_DEFAULT_STRATEGY) != Z_OK) return false;
    int r = deflate(&zs, Z_FINISH);
    deflateEnd(&zs);
    if (r != Z_STREAM_END) return false;
    out.resize(zs.total_out);
    return true;
}

static void zipWriteU16(std::vector<uint8_t>& buf, uint16_t v) {
    buf.push_back(v & 0xff); buf.push_back((v >> 8) & 0xff);
}
static void zipWriteU32(std::vector<uint8_t>& buf, uint32_t v) {
    buf.push_back(v & 0xff); buf.push_back((v >> 8) & 0xff);
    buf.push_back((v >> 16) & 0xff); buf.push_back((v >> 24) & 0xff);
}

static std::vector<uint8_t> zipBuild(const std::vector<ZipEntry>& entries) {
    std::vector<uint8_t> buf;
    std::vector<uint32_t> offsets;

    // Local headers + data
    for (const auto& e : entries) {
        offsets.push_back((uint32_t)buf.size());
        // Local file header
        zipWriteU32(buf, 0x04034b50);
        zipWriteU16(buf, 20);               // version needed
        zipWriteU16(buf, 0);                // flags
        zipWriteU16(buf, e.compression);
        zipWriteU16(buf, 0);                // mod time
        zipWriteU16(buf, 0);                // mod date
        zipWriteU32(buf, e.crc);
        zipWriteU32(buf, (uint32_t)e.data.size()); // comp size
        zipWriteU32(buf, e.uncompSize);
        zipWriteU16(buf, (uint16_t)e.name.size());
        zipWriteU16(buf, 0);                // extra len
        buf.insert(buf.end(), e.name.begin(), e.name.end());
        buf.insert(buf.end(), e.data.begin(), e.data.end());
    }

    // Central directory
    uint32_t cdOffset = (uint32_t)buf.size();
    for (size_t i = 0; i < entries.size(); i++) {
        const auto& e = entries[i];
        zipWriteU32(buf, 0x02014b50);
        zipWriteU16(buf, 20);               // version made
        zipWriteU16(buf, 20);               // version needed
        zipWriteU16(buf, 0);                // flags
        zipWriteU16(buf, e.compression);
        zipWriteU16(buf, 0);                // mod time
        zipWriteU16(buf, 0);                // mod date
        zipWriteU32(buf, e.crc);
        zipWriteU32(buf, (uint32_t)e.data.size());
        zipWriteU32(buf, e.uncompSize);
        zipWriteU16(buf, (uint16_t)e.name.size());
        zipWriteU16(buf, 0);                // extra
        zipWriteU16(buf, 0);                // comment
        zipWriteU16(buf, 0);                // disk start
        zipWriteU16(buf, 0);                // int attr
        zipWriteU32(buf, 0);                // ext attr
        zipWriteU32(buf, offsets[i]);
        buf.insert(buf.end(), e.name.begin(), e.name.end());
    }
    uint32_t cdSize = (uint32_t)buf.size() - cdOffset;

    // EOCD
    zipWriteU32(buf, 0x06054b50);
    zipWriteU16(buf, 0);                    // disk num
    zipWriteU16(buf, 0);                    // disk start
    zipWriteU16(buf, (uint16_t)entries.size());
    zipWriteU16(buf, (uint16_t)entries.size());
    zipWriteU32(buf, cdSize);
    zipWriteU32(buf, cdOffset);
    zipWriteU16(buf, 0);                    // comment len

    return buf;
}

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
    bool ok = zipFindEntry(zipData, zipSize, entryName, out);
    if (!ok) LOGE("ZIP entry not found: %s", entryName.c_str());
    return ok;
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
    std::vector<ZipEntry> entries;

    // 1. brush.json
    {
        std::string json = generateJson(def);
        ZipEntry e;
        e.name = "brush.json";
        e.uncompSize = (uint32_t)json.size();
        e.crc = zipCrc32((const uint8_t*)json.data(), json.size());
        if (!zipCompress((const uint8_t*)json.data(), json.size(), e.data)) {
            // fallback: store sin comprimir
            e.data.assign(json.begin(), json.end());
            e.compression = 0;
        } else {
            e.compression = 8;
        }
        entries.push_back(std::move(e));
    }

    // 2. shape.png
    if (!shapeRgba.empty() && shapeW > 0 && shapeH > 0) {
        int pngLen = 0;
        unsigned char* pngData = stbi_write_png_to_mem(
            shapeRgba.data(), shapeW * 4, shapeW, shapeH, 4, &pngLen);
        if (pngData && pngLen > 0) {
            ZipEntry e;
            e.name = "shape.png";
            e.uncompSize = (uint32_t)pngLen;
            e.crc = zipCrc32(pngData, pngLen);
            // PNG ya está comprimido — usar store
            e.data.assign(pngData, pngData + pngLen);
            e.compression = 0;
            entries.push_back(std::move(e));
            STBIW_FREE(pngData);
        }
    }

    // 3. grain.png
    if (!grainRgba.empty() && grainW > 0 && grainH > 0) {
        int pngLen = 0;
        unsigned char* pngData = stbi_write_png_to_mem(
            grainRgba.data(), grainW * 4, grainW, grainH, 4, &pngLen);
        if (pngData && pngLen > 0) {
            ZipEntry e;
            e.name = "grain.png";
            e.uncompSize = (uint32_t)pngLen;
            e.crc = zipCrc32(pngData, pngLen);
            e.data.assign(pngData, pngData + pngLen);
            e.compression = 0;
            entries.push_back(std::move(e));
            STBIW_FREE(pngData);
        }
    }

    // 4. Construir ZIP y escribir a disco
    auto zipBytes = zipBuild(entries);
    std::ofstream f(path, std::ios::binary);
    if (!f.is_open()) {
        LOGE("Cannot write to: %s", path.c_str());
        return false;
    }
    f.write((const char*)zipBytes.data(), zipBytes.size());
    f.close();

    LOGI("Brush '%s' saved to: %s (%zu bytes)",
         def.name.c_str(), path.c_str(), zipBytes.size());
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
