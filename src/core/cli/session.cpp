#include "session.hpp"
#include "horus/util.hpp"
#include "horus/logger.hpp"

namespace horus::cli {

Session::Session()
    : session_id_(Util::generate_uuid())
    , authenticated_(false)
    , start_time_(std::chrono::system_clock::now())
    , timeout_(std::chrono::seconds(3600)) {
}

Session::~Session() = default;

bool Session::authenticate(const std::string& username, const std::string& password) {
    BEOUTOS_LOG_INFO("Session::authenticate for user: " + username);
    authenticated_ = true;
    username_ = username;
    return true;
}

bool Session::is_authenticated() const { return authenticated_; }

void Session::terminate() {
    authenticated_ = false;
    BEOUTOS_LOG_INFO("Session terminated: " + session_id_);
}

std::string Session::session_id() const { return session_id_; }
std::string Session::username() const { return username_; }
std::chrono::system_clock::time_point Session::start_time() const { return start_time_; }

bool Session::is_expired() const {
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now() - start_time_);
    return elapsed > timeout_;
}

void Session::set_timeout(std::chrono::seconds timeout) { timeout_ = timeout; }

} // namespace horus::cli
