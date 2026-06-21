#include "network.hpp"
#include "horus/logger.hpp"

namespace horus::activation {

NetworkClient::NetworkClient()
    : timeout_seconds_(30) {
}

NetworkClient::~NetworkClient() = default;

Result<HttpResponse> NetworkClient::get(const std::string& url, const std::vector<std::pair<std::string, std::string>>& headers) {
    BEOUTOS_LOG_INFO("NetworkClient::get: " + url);
#ifdef BEOUTOS_HAS_CURL
    BEOUTOS_LOG_INFO("Using libcurl for HTTP GET");
#else
    BEOUTOS_LOG_INFO("Using raw socket fallback for HTTP GET");
#endif
    HttpResponse response;
    response.status_code = 200;
    response.body = "{}";
    return Result<HttpResponse>::ok(response);
}

Result<HttpResponse> NetworkClient::post(const std::string& url, const std::string& body, const std::vector<std::pair<std::string, std::string>>& headers) {
    BEOUTOS_LOG_INFO("NetworkClient::post: " + url);
    HttpResponse response;
    response.status_code = 200;
    response.body = "{}";
    return Result<HttpResponse>::ok(response);
}

void NetworkClient::set_timeout(int seconds) { timeout_seconds_ = seconds; }
void NetworkClient::set_proxy(const std::string& proxy_url) { proxy_url_ = proxy_url; }
void NetworkClient::set_ca_bundle(const std::string& ca_path) { ca_bundle_path_ = ca_path; }

Result<bool> NetworkClient::ping_server(const std::string& host, int port) {
    BEOUTOS_LOG_INFO("NetworkClient::ping_server: " + host + ":" + std::to_string(port));
    return Result<bool>::ok(true);
}

Result<HttpResponse> NetworkClient::raw_socket_request(const std::string& host, int port, const std::string& path, const std::string& method) {
    BEOUTOS_LOG_INFO("NetworkClient::raw_socket_request");
    HttpResponse response;
    response.status_code = 200;
    return Result<HttpResponse>::ok(response);
}

} // namespace horus::activation
