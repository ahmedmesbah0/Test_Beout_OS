#pragma once

#include <string>
#include <chrono>
#include <optional>
#include "horus/types.hpp"

namespace horus::cli {

class Session {
public:
    Session();
    ~Session();

    bool authenticate(const std::string& username, const std::string& password);
    bool is_authenticated() const;
    void terminate();

    std::string session_id() const;
    std::string username() const;
    std::chrono::system_clock::time_point start_time() const;

    bool is_expired() const;
    void set_timeout(std::chrono::seconds timeout);

private:
    std::string session_id_;
    std::string username_;
    bool authenticated_;
    std::chrono::system_clock::time_point start_time_;
    std::chrono::seconds timeout_;
};

} // namespace horus::cli
