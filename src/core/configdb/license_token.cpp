#include "license_token.hpp"
#include "horus/logger.hpp"

namespace horus::configdb {

bool LicenseToken::is_valid() const {
    return !token_id.empty() && !license_key.empty();
}

bool LicenseToken::is_expired() const {
    return std::chrono::system_clock::now() > expiry_date;
}

std::string LicenseToken::to_string() const {
    return "LicenseToken(" + token_id + ")";
}

LicenseTokenManager::LicenseTokenManager() {
}

LicenseTokenManager::~LicenseTokenManager() = default;

ResultVoid LicenseTokenManager::store_token(const LicenseToken& token) {
    BEOUTOS_LOG_INFO("LicenseTokenManager::store_token: " + token.token_id);
    return ResultVoid::ok(std::monostate);
}

Result<LicenseToken> LicenseTokenManager::load_token() {
    BEOUTOS_LOG_INFO("LicenseTokenManager::load_token");
    return Result<LicenseToken>::error(StatusCode::NOT_FOUND, "No license token stored");
}

ResultVoid LicenseTokenManager::delete_token() {
    BEOUTOS_LOG_INFO("LicenseTokenManager::delete_token");
    return ResultVoid::ok(std::monostate);
}

Result<bool> LicenseTokenManager::has_token() {
    return Result<bool>::ok(false);
}

Result<ActivationStatus> LicenseTokenManager::validate_token(const LicenseToken& token) {
    BEOUTOS_LOG_INFO("LicenseTokenManager::validate_token");
    return Result<ActivationStatus>::ok(ActivationStatus::ACTIVE);
}

ResultVoid LicenseTokenManager::refresh_token(const LicenseToken& token) {
    BEOUTOS_LOG_INFO("LicenseTokenManager::refresh_token");
    return ResultVoid::ok(std::monostate);
}

Result<std::string> LicenseTokenManager::get_feature_level() {
    BEOUTOS_LOG_INFO("LicenseTokenManager::get_feature_level");
    return Result<std::string>::ok("standard");
}

Result<std::vector<std::string>> LicenseTokenManager::get_enabled_features() {
    BEOUTOS_LOG_INFO("LicenseTokenManager::get_enabled_features");
    return Result<std::vector<std::string>>::ok({});
}

} // namespace horus::configdb
