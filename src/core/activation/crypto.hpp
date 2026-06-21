#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::activation {

class CryptoEngine {
public:
    CryptoEngine();
    ~CryptoEngine();

    Result<std::vector<uint8_t>> encrypt(const std::vector<uint8_t>& data, const std::string& key);
    Result<std::vector<uint8_t>> decrypt(const std::vector<uint8_t>& data, const std::string& key);

    Result<std::string> sign(const std::string& data, const std::string& private_key_pem);
    Result<bool> verify(const std::string& data, const std::string& signature, const std::string& public_key_pem);

    Result<std::string> generate_token(const std::string& payload);
    Result<bool> validate_token(const std::string& token);

    Result<std::string> generate_challenge();
    Result<std::string> solve_challenge(const std::string& challenge, const std::string& secret);

private:
    std::string aes_key_;
};

} // namespace horus::activation
