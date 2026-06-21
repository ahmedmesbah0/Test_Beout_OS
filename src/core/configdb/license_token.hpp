#pragma once

#include <string>
#include <vector>
#include <chrono>
#include "horus/types.hpp"

namespace horus::configdb {

struct LicenseToken {
    std::string token_id;
    std::string license_key;
    std::string machine_id;
    std::string product_id;
    std::string customer_id;
    std::chrono::system_clock::time_point issue_date;
    std::chrono::system_clock::time_point expiry_date;
    ActivationStatus status;
    std::string signature;

    bool is_valid() const;
    bool is_expired() const;
    std::string to_string() const;
};

class LicenseTokenManager {
public:
    LicenseTokenManager();
    ~LicenseTokenManager();

    ResultVoid store_token(const LicenseToken& token);
    Result<LicenseToken> load_token();
    ResultVoid delete_token();
    Result<bool> has_token();

    Result<ActivationStatus> validate_token(const LicenseToken& token);
    ResultVoid refresh_token(const LicenseToken& token);

    Result<std::string> get_feature_level();
    Result<std::vector<std::string>> get_enabled_features();
};

} // namespace horus::configdb
