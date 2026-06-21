#include "overlay_manager.hpp"
#include "horus/logger.hpp"
#include "horus/util.hpp"

namespace horus::overlay {

OverlayManager::OverlayManager()
    : base_root_("/usr/share/horus/base")
    , overlay_root_("/usr/share/horus/overlay") {
}

OverlayManager::~OverlayManager() = default;

ResultVoid OverlayManager::initialize() {
    BEOUTOS_LOG_INFO("OverlayManager::initialize");
    Util::create_directory(base_root_);
    Util::create_directory(overlay_root_);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::start() {
    BEOUTOS_LOG_INFO("OverlayManager::start");
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::stop() {
    BEOUTOS_LOG_INFO("OverlayManager::stop");
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::create_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::create_overlay: " + name);
    OverlayLayer layer;
    layer.name = name;
    layer.overlay_path = overlay_root_ + "/" + name;
    layer.active = false;
    overlays_.push_back(layer);
    Util::create_directory(layer.overlay_path);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::delete_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::delete_overlay: " + name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::activate_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::activate_overlay: " + name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::deactivate_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::deactivate_overlay: " + name);
    return ResultVoid::ok(std::monostate);
}

Result<std::vector<OverlayLayer>> OverlayManager::list_overlays() {
    return Result<std::vector<OverlayLayer>>::ok(overlays_);
}

Result<OverlayLayer> OverlayManager::get_overlay(const std::string& name) {
    for (const auto& layer : overlays_) {
        if (layer.name == name) {
            return Result<OverlayLayer>::ok(layer);
        }
    }
    return Result<OverlayLayer>::error(StatusCode::NOT_FOUND, "Overlay not found: " + name);
}

ResultVoid OverlayManager::merge_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::merge_overlay: " + name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::commit_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::commit_overlay: " + name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::rollback_overlay(const std::string& name) {
    BEOUTOS_LOG_INFO("OverlayManager::rollback_overlay: " + name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid OverlayManager::sync_all() {
    BEOUTOS_LOG_INFO("OverlayManager::sync_all");
    return ResultVoid::ok(std::monostate);
}

Result<std::string> OverlayManager::resolve_path(const std::string& path) {
    BEOUTOS_LOG_INFO("OverlayManager::resolve_path: " + path);
    return Result<std::string>::ok(path);
}

} // namespace horus::overlay
