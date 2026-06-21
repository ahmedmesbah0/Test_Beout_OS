#include "activation.hpp"
#include "horus/logger.hpp"

namespace horus::activation {

ActivationEngine::ActivationEngine()
    : current_status_(ActivationStatus::INACTIVE) {
}

ActivationEngine::~ActivationEngine() = default;

Result<ActivationResponse> ActivationEngine::activate(const ActivationRequest& request) {
    BEOUTOS_LOG_INFO("ActivationEngine::activate - key: " + request.license_key);
    ActivationResponse response;
    response.status = ActivationStatus::PENDING;
    return Result<ActivationResponse>::ok(response);
}

Result<ActivationStatus> ActivationEngine::check_status() {
    return Result<ActivationStatus>::ok(current_status_);
}

ResultVoid ActivationEngine::deactivate() {
    current_status_ = ActivationStatus::INACTIVE;
    activation_token_.clear();
    return ResultVoid::ok(std::monostate);
}

Result<ActivationResponse> ActivationEngine::reactivate(const std::string& license_key) {
    BEOUTOS_LOG_INFO("ActivationEngine::reactivate");
    ActivationResponse response;
    response.status = ActivationStatus::PENDING;
    return Result<ActivationResponse>::ok(response);
}

Result<ActivationStatus> ActivationEngine::validate_token(const std::string& token) {
    BEOUTOS_LOG_INFO("ActivationEngine::validate_token");
    return Result<ActivationStatus>::ok(ActivationStatus::ACTIVE);
}

Result<bool> ActivationEngine::is_activated() {
    return Result<bool>::ok(current_status_ == ActivationStatus::ACTIVE);
}

} // namespace horus::activation
