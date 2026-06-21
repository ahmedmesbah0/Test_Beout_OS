#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::configdb {

class InterfaceManager {
public:
    InterfaceManager();
    ~InterfaceManager();

    ResultVoid add_interface(const InterfaceConfig& config);
    ResultVoid update_interface(const std::string& name, const InterfaceConfig& config);
    ResultVoid delete_interface(const std::string& name);
    Result<InterfaceConfig> get_interface(const std::string& name);
    Result<std::vector<InterfaceConfig>> list_interfaces();
    Result<std::vector<InterfaceConfig>> list_by_type(InterfaceType type);

    ResultVoid apply_all();
    ResultVoid apply_interface(const std::string& name);
};

} // namespace horus::configdb
