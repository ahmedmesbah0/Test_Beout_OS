#pragma once

#include <string>
#include <vector>
#include <optional>
#include "horus/types.hpp"

namespace horus::activation {

class LicenseValidator {
public:
    LicenseValidator();
    ~LicenseValidator();

    Result<LicenseKey> parse_key(const std::string& raw_key);
    Result<bool> validate(const LicenseKey& key);
    Result<bool> verify_signature(const LicenseKey& key);
    Result<bool> check_expiry(const LicenseKey& key);

    Result<LicenseKey> load_from_file(const std::string& path);
    ResultVoid save_to_file(const std::string& path, const LicenseKey& key);

private:
    std::string public_key_pem_;
};

} // namespace horus::activation
