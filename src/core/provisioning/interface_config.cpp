#include "interface_config.hpp"
#include "horus/logger.hpp"

namespace horus::provisioning {

InterfaceConfigurator::InterfaceConfigurator() {
}

InterfaceConfigurator::~InterfaceConfigurator() = default;

ResultVoid InterfaceConfigurator::configure_wan(const InterfaceConfig& config) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::configure_wan: " + config.name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceConfigurator::configure_lan(const InterfaceConfig& config) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::configure_lan: " + config.name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceConfigurator::configure_management(const InterfaceConfig& config) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::configure_management: " + config.name);
    return ResultVoid::ok(std::monostate);
}

Result<InterfaceConfig> InterfaceConfigurator::get_interface_config(const std::string& interface_name) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::get_interface_config: " + interface_name);
    return Result<InterfaceConfig>::error(StatusCode::NOT_FOUND, "Interface not found");
}

Result<std::vector<InterfaceConfig>> InterfaceConfigurator::list_interfaces() {
    return Result<std::vector<InterfaceConfig>>::ok(interfaces_);
}

ResultVoid InterfaceConfigurator::apply_config(const std::string& interface_name) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::apply_config: " + interface_name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceConfigurator::reset_interface(const std::string& interface_name) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::reset_interface: " + interface_name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceConfigurator::set_dns(const std::string& primary, const std::string& secondary) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::set_dns");
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceConfigurator::enable_dhcp(const std::string& interface_name) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::enable_dhcp: " + interface_name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid InterfaceConfigurator::disable_dhcp(const std::string& interface_name) {
    BEOUTOS_LOG_INFO("InterfaceConfigurator::disable_dhcp: " + interface_name);
    return ResultVoid::ok(std::monostate);
}

} // namespace horus::provisioning
