#include "provisioning.hpp"
#include "horus/logger.hpp"

namespace horus::provisioning {

ProvisioningEngine::ProvisioningEngine()
    : running_(false)
    , provisioned_(false) {
}

ProvisioningEngine::~ProvisioningEngine() = default;

ResultVoid ProvisioningEngine::start() {
    BEOUTOS_LOG_INFO("ProvisioningEngine::start");
    running_ = true;
    return ResultVoid::ok(std::monostate);
}

ResultVoid ProvisioningEngine::stop() {
    running_ = false;
    return ResultVoid::ok(std::monostate);
}

ResultVoid ProvisioningEngine::run_interactive() {
    BEOUTOS_LOG_INFO("ProvisioningEngine::run_interactive");
    return ResultVoid::ok(std::monostate);
}

ResultVoid ProvisioningEngine::configure_interface(const InterfaceConfig& config) {
    BEOUTOS_LOG_INFO("ProvisioningEngine::configure_interface: " + config.name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid ProvisioningEngine::apply_network_config() {
    BEOUTOS_LOG_INFO("ProvisioningEngine::apply_network_config");
    return ResultVoid::ok(std::monostate);
}

ResultVoid ProvisioningEngine::reset_to_defaults() {
    provisioned_ = false;
    return ResultVoid::ok(std::monostate);
}

bool ProvisioningEngine::is_provisioned() const { return provisioned_; }
std::string ProvisioningEngine::get_provisioning_status() const {
    return provisioned_ ? "provisioned" : "unprovisioned";
}

} // namespace horus::provisioning
