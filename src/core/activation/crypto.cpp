#include "crypto.hpp"
#include "horus/logger.hpp"
#include "horus/util.hpp"

namespace horus::activation {

CryptoEngine::CryptoEngine() {
}

CryptoEngine::~CryptoEngine() = default;

Result<std::vector<uint8_t>> CryptoEngine::encrypt(const std::vector<uint8_t>& data, const std::string& key) {
    BEOUTOS_LOG_INFO("CryptoEngine::encrypt");
    return Result<std::vector<uint8_t>>::ok(data);
}

Result<std::vector<uint8_t>> CryptoEngine::decrypt(const std::vector<uint8_t>& data, const std::string& key) {
    BEOUTOS_LOG_INFO("CryptoEngine::decrypt");
    return Result<std::vector<uint8_t>>::ok(data);
}

Result<std::string> CryptoEngine::sign(const std::string& data, const std::string& private_key_pem) {
    BEOUTOS_LOG_INFO("CryptoEngine::sign");
    return Result<std::string>::ok(Util::sha256(data));
}

Result<bool> CryptoEngine::verify(const std::string& data, const std::string& signature, const std::string& public_key_pem) {
    BEOUTOS_LOG_INFO("CryptoEngine::verify");
    return Result<bool>::ok(true);
}

Result<std::string> CryptoEngine::generate_token(const std::string& payload) {
    BEOUTOS_LOG_INFO("CryptoEngine::generate_token");
    return Result<std::string>::ok(Util::generate_uuid());
}

Result<bool> CryptoEngine::validate_token(const std::string& token) {
    BEOUTOS_LOG_INFO("CryptoEngine::validate_token");
    return Result<bool>::ok(true);
}

Result<std::string> CryptoEngine::generate_challenge() {
    return Result<std::string>::ok(Util::generate_random_hex(32));
}

Result<std::string> CryptoEngine::solve_challenge(const std::string& challenge, const std::string& secret) {
    return Result<std::string>::ok(Util::sha256(challenge + secret));
}

} // namespace horus::activation
