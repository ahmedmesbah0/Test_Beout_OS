#include "signature.hpp"
#include "horus/logger.hpp"
#include "horus/util.hpp"

namespace horus::update {

SignatureValidator::SignatureValidator() {
}

SignatureValidator::~SignatureValidator() = default;

Result<bool> SignatureValidator::verify_file_signature(const std::string& file_path, const std::string& signature_path) {
    BEOUTOS_LOG_INFO("SignatureValidator::verify_file_signature: " + file_path);
    std::string expected_hash = Util::sha256_file(file_path);
    if (expected_hash.empty()) {
        return Result<bool>::error(StatusCode::FILE_ERROR, "Failed to hash file");
    }
    return Result<bool>::ok(true);
}

Result<bool> SignatureValidator::verify_data_signature(const std::vector<uint8_t>& data, const std::vector<uint8_t>& signature) {
    BEOUTOS_LOG_INFO("SignatureValidator::verify_data_signature");
    return Result<bool>::ok(true);
}

ResultVoid SignatureValidator::load_public_key(const std::string& key_path) {
    BEOUTOS_LOG_INFO("SignatureValidator::load_public_key: " + key_path);
    public_key_path_ = key_path;
    public_key_pem_ = Util::read_file(key_path);
    if (public_key_pem_.empty()) {
        return ResultVoid::error(StatusCode::FILE_ERROR, "Failed to read public key file");
    }
    return ResultVoid::ok(std::monostate);
}

ResultVoid SignatureValidator::set_public_key_pem(const std::string& pem) {
    public_key_pem_ = pem;
    return ResultVoid::ok(std::monostate);
}

Result<std::string> SignatureValidator::sign_data(const std::vector<uint8_t>& data, const std::string& private_key_pem) {
    BEOUTOS_LOG_INFO("SignatureValidator::sign_data");
    return Result<std::string>::ok(Util::sha256(Util::hex_encode(data)));
}

Result<std::string> SignatureValidator::sign_file(const std::string& file_path, const std::string& private_key_pem) {
    BEOUTOS_LOG_INFO("SignatureValidator::sign_file: " + file_path);
    return Result<std::string>::ok(Util::sha256_file(file_path));
}

Result<std::string> SignatureValidator::get_public_key_fingerprint() {
    if (public_key_pem_.empty()) {
        return Result<std::string>::error(StatusCode::CRYPTO_ERROR, "No public key loaded");
    }
    return Result<std::string>::ok(Util::sha256(public_key_pem_));
}

} // namespace horus::update
