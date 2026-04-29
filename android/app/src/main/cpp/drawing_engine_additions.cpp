// ─────────────────────────────────────────────────────────────────────────────
// PATCH: Agregar estos dos métodos a drawing_engine.cpp
// Buscar la función `void DrawingEngine::cancelStroke()` y agregar después:
// ─────────────────────────────────────────────────────────────────────────────

// ── NUEVO: Simetría ────────────────────────────────────────────────────────
// Delega a StrokeEngine. Debe llamarse en el GL thread (ya garantizado por JNI).
void DrawingEngine::setSymmetry(bool enabled, int axis) {
    if (impl_) impl_->strokeEngine_.setSymmetry(enabled, axis);
}

// ── NUEVO: Restaurar canvas desde bytes RGBA (undo/redo Kotlin) ─────────────
// Sube los bytes directamente a la textura del layer activo vía glTexSubImage2D.
// Después de esto, jniExportPixels devuelve el canvas restaurado.
// Llamar SIEMPRE en GL thread (DrawingEngineJNI.glHandler.post).
void DrawingEngine::restoreFromPixels(const uint8_t* rgba, int w, int h) {
    if (!impl_) return;
    auto* layer = impl_->layerManager_.activeLayer();
    if (!layer || !layer->isValid()) {
        LOGE("restoreFromPixels: no active layer or invalid FBO");
        return;
    }
    // Subir los bytes a la textura del layer activo
    glBindTexture(GL_TEXTURE_2D, layer->texture);
    glTexSubImage2D(GL_TEXTURE_2D, 0,
                    0, 0, w, h,
                    GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    glBindTexture(GL_TEXTURE_2D, 0);
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        LOGE("restoreFromPixels: glTexSubImage2D error 0x%X", err);
    }
    // Re-renderizar para que el FBO de composite esté actualizado
    render();
}
