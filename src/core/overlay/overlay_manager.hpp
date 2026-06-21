#pragma once

#include <string>
#include <vector>
#include <optional>
#include "horus/types.hpp"

namespace horus::overlay {

struct OverlayLayer {
    std::string name;
    std::string base_path;
    std::string overlay_path;
    std::string merge_path;
    bool active;
};

class OverlayManager {
public:
    OverlayManager();
    ~OverlayManager();

    ResultVoid initialize();
    ResultVoid start();
    ResultVoid stop();

    ResultVoid create_overlay(const std::string& name);
    ResultVoid delete_overlay(const std::string& name);
    ResultVoid activate_overlay(const std::string& name);
    ResultVoid deactivate_overlay(const std::string& name);

    Result<std::vector<OverlayLayer>> list_overlays();
    Result<OverlayLayer> get_overlay(const std::string& name);

    ResultVoid merge_overlay(const std::string& name);
    ResultVoid commit_overlay(const std::string& name);
    ResultVoid rollback_overlay(const std::string& name);

    ResultVoid sync_all();
    Result<std::string> resolve_path(const std::string& path);

private:
    std::vector<OverlayLayer> overlays_;
    std::string base_root_;
    std::string overlay_root_;
};

} // namespace horus::overlay
