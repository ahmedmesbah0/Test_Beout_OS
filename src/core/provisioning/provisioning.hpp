#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::provisioning {

class ProvisioningEngine {
public:
    ProvisioningEngine();
    ~ProvisioningEngine();

    ResultVoid start();
    ResultVoid stop();
    ResultVoid run_interactive();

    ResultVoid configure_interface(const InterfaceConfig& config);
    ResultVoid apply_network_config();
    ResultVoid reset_to_defaults();

    bool is_provisioned() const;
    std::string get_provisioning_status() const;

private:
    bool running_;
    bool provisioned_;
};

} // namespace horus::provisioning
