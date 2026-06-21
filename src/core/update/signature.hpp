#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::update {

class SignatureValidator {
public:
    SignatureValidator();
    ~SignatureValidator();

    Result<bool> verify_file_signature(const std::string& file_path, const std::string& signature_path);
    Result<bool> verify_data_signature(const std::vector<uint8_t>& data, const std::vector<uint8_t>& signature);

    ResultVoid load_public_key(const std::string& key_path);
    ResultVoid set_public_key_pem(const std::string& pem);

    Result<std::string> sign_data(const std::vector<uint8_t>& data, const std::string& private_key_pem);
    Result<std::string> sign_file(const std::string& file_path, const std::string& private_key_pem);

    Result<std::string> get_public_key_fingerprint();

private:
    std::string public_key_pem_;
    std::string public_key_path_;
};

} // namespace horus::update
