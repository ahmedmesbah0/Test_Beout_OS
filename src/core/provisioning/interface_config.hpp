#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::provisioning {

class InterfaceConfigurator {
public:
    InterfaceConfigurator();
    ~InterfaceConfigurator();

    ResultVoid configure_wan(const InterfaceConfig& config);
    ResultVoid configure_lan(const InterfaceConfig& config);
    ResultVoid configure_management(const InterfaceConfig& config);

    Result<InterfaceConfig> get_interface_config(const std::string& interface_name);
    Result<std::vector<InterfaceConfig>> list_interfaces();

    ResultVoid apply_config(const std::string& interface_name);
    ResultVoid reset_interface(const std::string& interface_name);

    ResultVoid set_dns(const std::string& primary, const std::string& secondary);
    ResultVoid enable_dhcp(const std::string& interface_name);
    ResultVoid disable_dhcp(const std::string& interface_name);

private:
    std::vector<InterfaceConfig> interfaces_;
};

} // namespace horus::provisioning
