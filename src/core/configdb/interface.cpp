#include "interface.hpp"
#include "horus/logger.hpp"

namespace horus::configdb {

InterfaceManager::InterfaceManager() {
}

InterfaceManager::~InterfaceManager() = default;

ResultVoid InterfaceManager::add_interface(const InterfaceConfig& config) {
    BEOUTOS_LOG_INFO("InterfaceManager::add_interface: " + config.name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceManager::update_interface(const std::string& name, const InterfaceConfig& config) {
    BEOUTOS_LOG_INFO("InterfaceManager::update_interface: " + name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceManager::delete_interface(const std::string& name) {
    BEOUTOS_LOG_INFO("InterfaceManager::delete_interface: " + name);
    return ResultVoid::ok(std::monostate);
}

Result<InterfaceConfig> InterfaceManager::get_interface(const std::string& name) {
    BEOUTOS_LOG_INFO("InterfaceManager::get_interface: " + name);
    return Result<InterfaceConfig>::error(StatusCode::NOT_FOUND, "Interface not found");
}

Result<std::vector<InterfaceConfig>> InterfaceManager::list_interfaces() {
    BEOUTOS_LOG_INFO("InterfaceManager::list_interfaces");
    return Result<std::vector<InterfaceConfig>>::ok({});
}

Result<std::vector<InterfaceConfig>> InterfaceManager::list_by_type(InterfaceType type) {
    BEOUTOS_LOG_INFO("InterfaceManager::list_by_type");
    return Result<std::vector<InterfaceConfig>>::ok({});
}

ResultVoid InterfaceManager::apply_all() {
    BEOUTOS_LOG_INFO("InterfaceManager::apply_all");
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceManager::apply_interface(const std::string& name) {
    BEOUTOS_LOG_INFO("InterfaceManager::apply_interface: " + name);
    return ResultVoid::ok(std::monostate);
}

} // namespace horus::configdb
