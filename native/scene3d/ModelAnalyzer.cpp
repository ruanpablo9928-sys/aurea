#include "ModelAnalyzer.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cstring>

namespace aurea {

ModelAnalysisReport ModelAnalyzer::analyzeFile(const std::string& filePath, const DeviceProfile& profile) {
    ModelAnalysisReport report;
    report.filePath = filePath;

    std::ifstream file(filePath, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        report.isSafeForDevice = false;
        report.warnings.push_back("Arquivo 3D nao encontrado ou inacessivel.");
        return report;
    }

    report.fileSizeBytes = static_cast<int64_t>(file.tellg());
    file.seekg(0, std::ios::beg);

    std::string lowerPath = filePath;
    std::transform(lowerPath.begin(), lowerPath.end(), lowerPath.begin(), ::tolower);

    bool parsed = false;
    if (lowerPath.ends_with(".glb")) {
        parsed = analyzeGlb(filePath, report);
    } else if (lowerPath.ends_with(".gltf")) {
        parsed = analyzeGltf(filePath, report);
    } else if (lowerPath.ends_with(".obj")) {
        parsed = analyzeObj(filePath, report);
    } else {
        report.warnings.push_back("Formato nao suportado para pre-analise rapida.");
    }

    if (!parsed) {
        // Estimativa estatística preliminar baseada no tamanho do arquivo se o parser leve falhar
        report.meshCount = 1;
        report.vertexCount = static_cast<int>(report.fileSizeBytes / 36);
        report.triangleCount = report.vertexCount / 3;
    }

    // Cálculo de Memória Estimada
    // CPU: Dados brutos + estruturas intermediárias
    report.estimatedCpuMemoryMb = static_cast<float>(report.fileSizeBytes * 2.5) / (1024.0f * 1024.0f);

    // GPU: Geometria (pos, norm, uv = 32 bytes) + Indices (3 * 4 = 12 bytes) + Texturas (RGBA8)
    int64_t geomBytes = static_cast<int64_t>(report.vertexCount) * 32 + static_cast<int64_t>(report.triangleCount) * 12;
    int texDim = profile.clampTextureDimension(
        report.largestTextureWidth > 0 ? report.largestTextureWidth : 2048,
        report.largestTextureHeight > 0 ? report.largestTextureHeight : 2048
    );
    int64_t texBytes = static_cast<int64_t>(report.textureCount > 0 ? report.textureCount : 1) * texDim * texDim * 4;

    report.estimatedGpuMemoryMb = static_cast<float>(geomBytes + texBytes) / (1024.0f * 1024.0f);

    // Verificação contra limites do dispositivo
    const auto& caps = profile.getCapabilities();
    if (report.triangleCount > caps.maxTrianglesPerMesh) {
        report.recommendedLOD = 1;
        report.warnings.push_back("Contagem de triangulos excede o limite ideal do aparelho. LOD recomendado.");
    }

    if (report.estimatedGpuMemoryMb > static_cast<float>(caps.maxVramBudgetMb)) {
        report.isSafeForDevice = false;
        report.recommendedLOD = 2;
        report.warnings.push_back("Memoria de GPU estimada ultrapassa o orcamento seguro do aparelho.");
    }

    return report;
}

bool ModelAnalyzer::analyzeGlb(const std::string& filePath, ModelAnalysisReport& report) {
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    // Cabeçalho GLB: 12 bytes (magic, version, length)
    uint32_t header[3];
    file.read(reinterpret_cast<char*>(header), 12);
    if (file.gcount() < 12) return false;

    // Magic: 0x46546C67 ("glTF")
    if (header[0] != 0x46546C67 || header[1] != 2) {
        return false;
    }

    // Primeiro chunk: JSON (chunkLength, chunkType = 0x4E4F534A)
    uint32_t chunkHeader[2];
    file.read(reinterpret_cast<char*>(chunkHeader), 8);
    if (file.gcount() < 8 || chunkHeader[1] != 0x4E4F534A) {
        return false;
    }

    uint32_t jsonLen = chunkHeader[0];
    if (jsonLen > 50 * 1024 * 1024) return false; // Proteção contra arquivos gigantes

    std::vector<char> jsonBytes(jsonLen + 1);
    file.read(jsonBytes.data(), jsonLen);
    jsonBytes[jsonLen] = '\0';
    std::string jsonStr(jsonBytes.data(), jsonLen);

    // Contagem rápida de ocorrências no JSON sem depender de parser pesado
    auto countKeys = [&jsonStr](const std::string& key) -> int {
        int count = 0;
        size_t pos = 0;
        while ((pos = jsonStr.find(key, pos)) != std::string::npos) {
            ++count;
            pos += key.length();
        }
        return count;
    };

    report.meshCount = std::max(1, countKeys("\"primitives\""));
    report.materialCount = countKeys("\"materials\"");
    report.textureCount = countKeys("\"textures\"");
    report.boneCount = countKeys("\"joints\"");
    report.animationCount = countKeys("\"animations\"");
    report.nodeCount = countKeys("\"nodes\"");

    // Estimativa de vértices a partir do tamanho dos buffers declarados
    size_t byteLengthPos = jsonStr.find("\"byteLength\"");
    if (byteLengthPos != std::string::npos) {
        report.vertexCount = static_cast<int>((report.fileSizeBytes - jsonLen) / 36);
        report.triangleCount = report.vertexCount / 3;
    }

    return true;
}

bool ModelAnalyzer::analyzeGltf(const std::string& filePath, ModelAnalysisReport& report) {
    std::ifstream file(filePath);
    if (!file.is_open()) return false;

    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string jsonStr = buffer.str();

    auto countKeys = [&jsonStr](const std::string& key) -> int {
        int count = 0;
        size_t pos = 0;
        while ((pos = jsonStr.find(key, pos)) != std::string::npos) {
            ++count;
            pos += key.length();
        }
        return count;
    };

    report.meshCount = std::max(1, countKeys("\"primitives\""));
    report.materialCount = countKeys("\"materials\"");
    report.textureCount = countKeys("\"textures\"");
    report.boneCount = countKeys("\"joints\"");
    report.animationCount = countKeys("\"animations\"");
    report.nodeCount = countKeys("\"nodes\"");

    report.vertexCount = static_cast<int>(report.fileSizeBytes / 36);
    report.triangleCount = report.vertexCount / 3;
    return true;
}

bool ModelAnalyzer::analyzeObj(const std::string& filePath, ModelAnalysisReport& report) {
    std::ifstream file(filePath);
    if (!file.is_open()) return false;

    std::string line;
    int vCount = 0;
    int fCount = 0;
    int matCount = 0;

    int lineLimit = 10000; // Analisa as primeiras 10k linhas para estimativa rápida
    int linesRead = 0;

    while (std::getline(file, line) && linesRead < lineLimit) {
        linesRead++;
        if (line.starts_with("v ")) vCount++;
        else if (line.starts_with("f ")) fCount++;
        else if (line.starts_with("usemtl ")) matCount++;
    }

    if (linesRead >= lineLimit && report.fileSizeBytes > 0) {
        // Extrapola para o arquivo completo
        double factor = static_cast<double>(report.fileSizeBytes) / (linesRead * 30.0);
        report.vertexCount = static_cast<int>(vCount * factor);
        report.triangleCount = static_cast<int>(fCount * factor);
    } else {
        report.vertexCount = vCount;
        report.triangleCount = fCount;
    }

    report.meshCount = 1;
    report.materialCount = std::max(1, matCount);
    report.textureCount = 1;
    return true;
}

} // namespace aurea
