#pragma once

#include <string>
#include <vector>
#include <optional>
#include "horus/types.hpp"

namespace horus::activation {

struct HttpResponse {
    int status_code;
    std::string body;
    std::vector<std::pair<std::string, std::string>> headers;
};

class NetworkClient {
public:
    NetworkClient();
    ~NetworkClient();

    Result<HttpResponse> get(const std::string& url, const std::vector<std::pair<std::string, std::string>>& headers = {});
    Result<HttpResponse> post(const std::string& url, const std::string& body, const std::vector<std::pair<std::string, std::string>>& headers = {});

    void set_timeout(int seconds);
    void set_proxy(const std::string& proxy_url);
    void set_ca_bundle(const std::string& ca_path);

    Result<bool> ping_server(const std::string& host, int port);

private:
    int timeout_seconds_;
    std::string proxy_url_;
    std::string ca_bundle_path_;

    Result<HttpResponse> raw_socket_request(const std::string& host, int port, const std::string& path, const std::string& method);
};

} // namespace horus::activation
