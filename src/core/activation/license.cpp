#include "license.hpp"
#include "horus/logger.hpp"

namespace horus::activation {

LicenseValidator::LicenseValidator() {
}

LicenseValidator::~LicenseValidator() = default;

Result<LicenseKey> LicenseValidator::parse_key(const std::string& raw_key) {
    BEOUTOS_LOG_INFO("LicenseValidator::parse_key");
    LicenseKey key;
    key.key = raw_key;
    return Result<LicenseKey>::ok(key);
}

Result<bool> LicenseValidator::validate(const LicenseKey& key) {
    BEOUTOS_LOG_INFO("LicenseValidator::validate");
    return Result<bool>::ok(key.is_valid());
}

Result<bool> LicenseValidator::verify_signature(const LicenseKey& key) {
    BEOUTOS_LOG_INFO("LicenseValidator::verify_signature");
    return Result<bool>::ok(true);
}

Result<bool> LicenseValidator::check_expiry(const LicenseKey& key) {
    BEOUTOS_LOG_INFO("LicenseValidator::check_expiry");
    return Result<bool>::ok(!key.is_expired());
}

Result<LicenseKey> LicenseValidator::load_from_file(const std::string& path) {
    BEOUTOS_LOG_INFO("LicenseValidator::load_from_file: " + path);
    return Result<LicenseKey>::error(StatusCode::NOT_FOUND, "License file not found");
}

ResultVoid LicenseValidator::save_to_file(const std::string& path, const LicenseKey& key) {
    BEOUTOS_LOG_INFO("LicenseValidator::save_to_file: " + path);
    return ResultVoid::ok(std::monostate);
}

} // namespace horus::activation
