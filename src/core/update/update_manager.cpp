#include "update_manager.hpp"
#include "horus/logger.hpp"
#include "horus/util.hpp"

namespace horus::update {

UpdateManager::UpdateManager()
    : state_(UpdateState::IDLE)
    , auto_update_enabled_(false)
    , update_server_url_("https://updates.horus.local") {
}

UpdateManager::~UpdateManager() = default;

ResultVoid UpdateManager::initialize() {
    BEOUTOS_LOG_INFO("UpdateManager::initialize");
    return ResultVoid::ok(std::monostate);
}

ResultVoid UpdateManager::start() {
    BEOUTOS_LOG_INFO("UpdateManager::start");
    return ResultVoid::ok(std::monostate);
}

ResultVoid UpdateManager::stop() {
    state_ = UpdateState::IDLE;
    return ResultVoid::ok(std::monostate);
}

Result<std::optional<UpdateInfo>> UpdateManager::check_for_updates() {
    state_ = UpdateState::CHECKING;
    BEOUTOS_LOG_INFO("UpdateManager::check_for_updates");
    state_ = UpdateState::IDLE;
    return Result<std::optional<UpdateInfo>>::ok(std::nullopt);
}

ResultVoid UpdateManager::download_update(const UpdateInfo& info) {
    state_ = UpdateState::DOWNLOADING;
    BEOUTOS_LOG_INFO("UpdateManager::download_update: " + info.version);
    state_ = UpdateState::IDLE;
    return ResultVoid::ok(std::monostate);
}

ResultVoid UpdateManager::verify_update(const std::string& update_file) {
    state_ = UpdateState::VERIFYING;
    BEOUTOS_LOG_INFO("UpdateManager::verify_update: " + update_file);
    state_ = UpdateState::IDLE;
    return ResultVoid::ok(std::monostate);
}

ResultVoid UpdateManager::install_update(const std::string& update_file) {
    state_ = UpdateState::INSTALLING;
    BEOUTOS_LOG_INFO("UpdateManager::install_update: " + update_file);
    state_ = UpdateState::COMPLETED;
    return ResultVoid::ok(std::monostate);
}

ResultVoid UpdateManager::rollback_update() {
    BEOUTOS_LOG_INFO("UpdateManager::rollback_update");
    auto result = partition_mgr_.swap_active();
    state_ = UpdateState::IDLE;
    return result;
}

UpdateState UpdateManager::current_state() const { return state_; }
std::string UpdateManager::current_version() const { return BEOUTOS_VERSION; }

ResultVoid UpdateManager::set_update_server(const std::string& url) {
    update_server_url_ = url;
    return ResultVoid::ok(std::monostate);
}

ResultVoid UpdateManager::set_auto_update(bool enabled) {
    auto_update_enabled_ = enabled;
    return ResultVoid::ok(std::monostate);
}

} // namespace horus::update
