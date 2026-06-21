#include "api_server.hpp"
#include <json.hpp>
#include <iostream>
#include <random>

using json = nlohmann::json;

namespace beout_os {
namespace api {

ApiServer::ApiServer(const std::string& cert_path, const std::string& private_key_path, std::shared_ptr<database::DatabaseManager> db)
    : db_(std::move(db)) {
    server_ = std::make_unique<httplib::SSLServer>(cert_path.c_str(), private_key_path.c_str());
    setup_routes();
}

ApiServer::~ApiServer() {
    stop();
}

void ApiServer::start(const std::string& host, int port) {
    if (!server_->is_valid()) {
        std::cerr << "SSL Server has an error." << std::endl;
        return;
    }
    std::cout << "Starting API Server on https://" << host << ":" << port << std::endl;
    server_->listen(host.c_str(), port);
}

void ApiServer::stop() {
    if (server_ && server_->is_running()) {
        server_->stop();
    }
}

void ApiServer::setup_routes() {
    // Serve static files from the React app
    server_->set_mount_point("/", "../dashboard/dist");
    
    // CORS Preflight
    server_->Options(R"(.*)", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        res.set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization");
        res.status = 204;
    });

    // Helper to check authentication
    auto check_auth = [&](const httplib::Request& req, httplib::Response& res) -> bool {
        if (!req.has_header("Authorization")) {
            res.status = 401;
            res.set_content(json{{"error", "Unauthorized"}}.dump(), "application/json");
            return false;
        }
        std::string auth_header = req.get_header_value("Authorization");
        std::lock_guard<std::mutex> lock(session_mutex_);
        if (auth_header != "Bearer " + current_session_token_ || current_session_token_.empty()) {
            res.status = 401;
            res.set_content(json{{"error", "Invalid Session"}}.dump(), "application/json");
            return false;
        }
        return true;
    };

    // Health API
    server_->Get("/api/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        json response = {{"status", "ok"}, {"version", "1.0.0"}};
        res.set_content(response.dump(), "application/json");
    });

    // Login API
    server_->Post("/api/auth/login", [&](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        try {
            auto body = json::parse(req.body);
            std::string username = body.value("username", "");
            std::string password = body.value("password", "");

            // For demo purposes, hardcode admin:admin
            if (username == "admin" && password == "admin") {
                // Generate a simple token
                std::lock_guard<std::mutex> lock(session_mutex_);
                current_session_token_ = "DEMO-SESSION-TOKEN-XYZ123";
                res.set_content(json{{"token", current_session_token_}}.dump(), "application/json");
            } else {
                res.status = 401;
                res.set_content(json{{"error", "Invalid credentials"}}.dump(), "application/json");
            }
        } catch (const json::parse_error&) {
            res.status = 400;
            res.set_content(json{{"error", "Invalid JSON"}}.dump(), "application/json");
        }
    });

    // Configuration API
    server_->Get("/api/config", [&](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        if (!check_auth(req, res)) return;

        json response = {
            {"wan_ip", db_->get_config("network_WAN_ip").value_or("")},
            {"lan_ip", db_->get_config("network_LAN_ip").value_or("")},
            {"mgmt_ip", db_->get_config("network_MGMT_ip").value_or("")}
        };
        res.set_content(response.dump(), "application/json");
    });

    // Configuration POST API
    server_->Post("/api/config", [&](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        if (!check_auth(req, res)) return;

        try {
            auto body = json::parse(req.body);
            if (body.contains("wan_ip")) db_->set_config("network_WAN_ip", body["wan_ip"]);
            if (body.contains("lan_ip")) db_->set_config("network_LAN_ip", body["lan_ip"]);
            if (body.contains("mgmt_ip")) db_->set_config("network_MGMT_ip", body["mgmt_ip"]);
            
            res.set_content(json{{"status", "success"}}.dump(), "application/json");
        } catch (const json::parse_error&) {
            res.status = 400;
            res.set_content(json{{"error", "Invalid JSON"}}.dump(), "application/json");
        }
    });

    // License Status API
    server_->Get("/api/license", [&](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        if (!check_auth(req, res)) return;

        std::string status = db_->get_config("activation_status").value_or("INACTIVE");
        json response = {{"status", status}};
        res.set_content(response.dump(), "application/json");
    });
}

} // namespace api
} // namespace beout_os
