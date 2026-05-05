#pragma once
#include "brush_definition.h"
#include <string>
#include <vector>
#include <functional>

namespace tsk {

// Resultado de carga
enum class LoadResult {
    OK,
    FILE_NOT_FOUND,
    INVALID_FORMAT,
    JSON_PARSE_ERROR,
    MISSING_SHAPE,
    GPU_UPLOAD_FAILED,
};

// Callback para subir textura PNG al GPU
// Recibe: píxeles RGBA, ancho, alto → devuelve el texId asignado
using UploadTextureFn = std::function<int(const uint8_t*, int, int)>;

class TskBrushLoader {
public:
    explicit TskBrushLoader(UploadTextureFn uploadFn)
        : uploadFn_(uploadFn) {}

    // Carga un .tskbrush desde ruta en disco
    // Llena 'out' con la definición completa
    LoadResult load(const std::string& path, BrushDefinition& out);

    // Carga desde bytes en memoria (útil para assets de la app)
    LoadResult loadFromMemory(const uint8_t* data, size_t size, BrushDefinition& out);

    // Exporta un BrushDefinition a un .tskbrush en disco
    bool save(const BrushDefinition& def,
              const std::string& path,
              const std::vector<uint8_t>& shapeRgba = {},
              int shapeW = 0, int shapeH = 0,
              const std::vector<uint8_t>& grainRgba = {},
              int grainW = 0, int grainH = 0);

    // Escanea un directorio y retorna lista de archivos .tskbrush encontrados
    static std::vector<std::string> scanDirectory(const std::string& dir);

    // Genera un JSON mínimo para un pincel nuevo
    static std::string generateJson(const BrushDefinition& def);

    // Parsea solo los metadatos (name, category, version) sin cargar assets al GPU
    // Útil para mostrar la lista de pinceles disponibles
    static LoadResult parseMetadata(const std::string& path, BrushDefinition& out);

private:
    UploadTextureFn uploadFn_;

    // Parsea el JSON y llena los campos de BrushDefinition
    static bool parseJson(const std::string& json, BrushDefinition& out);

    // Decodifica un PNG en memoria → RGBA bytes
    static bool decodePng(const uint8_t* data, size_t size,
                          std::vector<uint8_t>& rgba, int& w, int& h);

    // Lee el contenido de un archivo ZIP en memoria
    // Retorna false si el archivo no existe dentro del ZIP
    static bool readZipEntry(const uint8_t* zipData, size_t zipSize,
                              const std::string& entryName,
                              std::vector<uint8_t>& out);
};

} // namespace tsk
