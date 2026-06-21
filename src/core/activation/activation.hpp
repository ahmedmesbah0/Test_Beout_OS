#pragma once

#include <string>
#include <optional>
#include "horus/types.hpp"
#include "license.hpp"

namespace horus::activation {

struct ActivationRequest {
    std::string license_key;
    std::string machine_id;
    std::string product_id;
};

struct ActivationResponse {
    ActivationStatus status;
    std::string token;
    std::string expiry_date;
    std::string error_message;
};

class ActivationEngine {
public:
    ActivationEngine();
    ~ActivationEngine();

    Result<ActivationResponse> activate(const ActivationRequest& request);
    Result<ActivationStatus> check_status();
    ResultVoid deactivate();
    Result<ActivationResponse> reactivate(const std::string& license_key);

    Result<ActivationStatus> validate_token(const std::string& token);
    Result<bool> is_activated();

private:
    LicenseValidator license_validator_;
    ActivationStatus current_status_;
    std::string activation_token_;
};

} // namespace horus::activation
