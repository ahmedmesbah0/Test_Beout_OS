#include "database_manager.hpp"
#include <sqlite3.h>
#include <iostream>

namespace beout_os {
namespace database {

DatabaseManager::DatabaseManager(const std::string& db_path) : db_path_(db_path) {}

DatabaseManager::~DatabaseManager() {
    if (db_) {
        sqlite3_close(db_);
    }
}

bool DatabaseManager::initialize() {
    if (sqlite3_open(db_path_.c_str(), &db_) != SQLITE_OK) {
        std::cerr << "Cannot open database: " << sqlite3_errmsg(db_) << std::endl;
        return false;
    }

    const char* create_table_query = R"(
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    )";

    return execute_query(create_table_query);
}

bool DatabaseManager::execute_query(const std::string& query) const {
    char* err_msg = nullptr;
    if (sqlite3_exec(db_, query.c_str(), nullptr, nullptr, &err_msg) != SQLITE_OK) {
        std::cerr << "SQL error: " << err_msg << std::endl;
        sqlite3_free(err_msg);
        return false;
    }
    return true;
}

bool DatabaseManager::set_config(const std::string& key, const std::string& value) {
    std::string query = "INSERT INTO config (key, value) VALUES ('" + key + "', '" + value + "') "
                        "ON CONFLICT(key) DO UPDATE SET value=excluded.value;";
    return execute_query(query);
}

std::optional<std::string> DatabaseManager::get_config(const std::string& key) const {
    std::string query = "SELECT value FROM config WHERE key = '" + key + "';";
    sqlite3_stmt* stmt;
    
    if (sqlite3_prepare_v2(db_, query.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        return std::nullopt;
    }

    std::optional<std::string> result = std::nullopt;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        const unsigned char* text = sqlite3_column_text(stmt, 0);
        if (text) {
            result = std::string(reinterpret_cast<const char*>(text));
        }
    }

    sqlite3_finalize(stmt);
    return result;
}

} // namespace database
} // namespace beout_os
