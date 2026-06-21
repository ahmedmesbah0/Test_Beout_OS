#pragma once

#include <string>
#include <variant>
#include <optional>
#include <vector>
#include <cstdint>
#include <array>

namespace horus {

struct Version {
    uint32_t major;
    uint32_t minor;
    uint32_t patch;

    std::string to_string() const;
    bool operator==(const Version& other) const;
    bool operator<(const Version& other) const;
    bool operator<=(const Version& other) const;
    static Version from_string(const std::string& str);
};

enum class InterfaceType {
    WAN,
    LAN,
    MANAGEMENT
};

enum class InterfaceState {
    UP,
    DOWN,
    UNKNOWN
};

struct InterfaceConfig {
    InterfaceType type;
    std::string name;
    std::string mac_address;
    std::string ipv4_address;
    std::string ipv4_netmask;
    std::string ipv4_gateway;
    std::string ipv6_address;
    std::string dns_primary;
    std::string dns_secondary;
    bool dhcp_enabled;
    InterfaceState state;

    std::string to_string() const;
    static InterfaceConfig from_string(const std::string& str);
};

struct LicenseKey {
    std::string key;
    std::string product_id;
    std::string customer_id;
    std::string issue_date;
    std::string expiry_date;
    std::string signature;

    bool is_valid() const;
    bool is_expired() const;
};

enum class ActivationStatus {
    INACTIVE,
    PENDING,
    ACTIVE,
    EXPIRED,
    REVOKED,
    ERROR
};

enum class StatusCode {
    OK                    = 0,
    GENERIC_ERROR         = 1,
    INVALID_ARGUMENT      = 2,
    NOT_FOUND             = 3,
    ALREADY_EXISTS        = 4,
    PERMISSION_DENIED     = 5,
    NETWORK_ERROR         = 6,
    DATABASE_ERROR        = 7,
    AUTHENTICATION_ERROR  = 8,
    LICENSE_ERROR         = 9,
    ACTIVATION_ERROR      = 10,
    CONFIGURATION_ERROR   = 11,
    UPDATE_ERROR          = 12,
    CRYPTO_ERROR          = 13,
    SYSTEM_ERROR          = 14,
    TIMEOUT               = 15,
    OUT_OF_MEMORY         = 16,
    FILE_ERROR            = 17,
    IO_ERROR              = 18
};

template<typename T>
class Result {
public:
    Result(T value) : data_(std::move(value)) {}
    Result(StatusCode code, const std::string& msg = "")
        : data_(ErrorInfo{code, msg}) {}

    bool is_ok() const { return std::holds_alternative<T>(data_); }
    bool is_error() const { return std::holds_alternative<ErrorInfo>(data_); }

    const T& value() const { return std::get<T>(data_); }
    T& value() { return std::get<T>(data_); }

    StatusCode error_code() const {
        return is_error() ? std::get<ErrorInfo>(data_).code : StatusCode::OK;
    }

    const std::string& error_message() const {
        return is_error() ? std::get<ErrorInfo>(data_).message : empty_;
    }

    static Result<T> ok(T value) { return Result(std::move(value)); }
    static Result<T> error(StatusCode code, const std::string& msg = "") {
        return Result(code, msg);
    }

private:
    struct ErrorInfo {
        StatusCode code;
        std::string message;
    };

    std::variant<T, ErrorInfo> data_;
    static const std::string empty_;
};

template<typename T>
const std::string Result<T>::empty_;

using ResultVoid = Result<std::monostate>;

} // namespace horus
