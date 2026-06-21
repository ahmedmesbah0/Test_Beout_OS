#include "config_store.hpp"
#include "horus/logger.hpp"

namespace horus::configdb {

ConfigDBStore::ConfigDBStore(const std::string& db_path)
    : db_(db_path) {
}

ConfigDBStore::~ConfigDBStore() = default;

bool ConfigDBStore::initialize() {
    if (!db_.open()) return false;

    auto result = db_.execute(
        "CREATE TABLE IF NOT EXISTS settings ("
        "  section TEXT NOT NULL,"
        "  key TEXT NOT NULL,"
        "  value TEXT NOT NULL,"
        "  updated_at TEXT NOT NULL DEFAULT (datetime('now')),"
        "  PRIMARY KEY (section, key)"
        ");"
        "CREATE INDEX IF NOT EXISTS idx_settings_section ON settings(section);"
    );

    return result.is_ok();
}

ResultVoid ConfigDBStore::load_schema() {
    BEOUTOS_LOG_INFO("ConfigDBStore::load_schema");
    return ResultVoid::ok(std::monostate);
}

Result<std::string> ConfigDBStore::get_setting(const std::string& section, const std::string& key) {
    auto stmt = db_.prepare("SELECT value FROM settings WHERE section = ? AND key = ?");
    stmt->bind_text(1, section);
    stmt->bind_text(2, key);
    if (stmt->step()) {
        return Result<std::string>::ok(stmt->get_text(0));
    }
    return Result<std::string>::error(StatusCode::NOT_FOUND, "Setting not found");
}

ResultVoid ConfigDBStore::set_setting(const std::string& section, const std::string& key, const std::string& value) {
    auto stmt = db_.prepare(
        "INSERT OR REPLACE INTO settings (section, key, value, updated_at) "
        "VALUES (?, ?, ?, datetime('now'))"
    );
    stmt->bind_text(1, section);
    stmt->bind_text(2, key);
    stmt->bind_text(3, value);
    stmt->step();
    return ResultVoid::ok(std::monostate);
}

ResultVoid ConfigDBStore::delete_setting(const std::string& section, const std::string& key) {
    auto stmt = db_.prepare("DELETE FROM settings WHERE section = ? AND key = ?");
    stmt->bind_text(1, section);
    stmt->bind_text(2, key);
    stmt->step();
    return ResultVoid::ok(std::monostate);
}

Result<std::vector<std::pair<std::string, std::string>>> ConfigDBStore::list_settings(const std::string& section) {
    auto stmt = db_.prepare("SELECT key, value FROM settings WHERE section = ? ORDER BY key");
    stmt->bind_text(1, section);
    std::vector<std::pair<std::string, std::string>> entries;
    while (stmt->step()) {
        entries.emplace_back(stmt->get_text(0), stmt->get_text(1));
    }
    return Result<std::vector<std::pair<std::string, std::string>>>::ok(entries);
}

ResultVoid ConfigDBStore::begin_transaction() {
    current_transaction_ = db_.begin_transaction();
    return ResultVoid::ok(std::monostate);
}

ResultVoid ConfigDBStore::commit_transaction() {
    if (current_transaction_) {
        current_transaction_->commit();
        current_transaction_.reset();
    }
    return ResultVoid::ok(std::monostate);
}

ResultVoid ConfigDBStore::rollback_transaction() {
    if (current_transaction_) {
        current_transaction_->rollback();
        current_transaction_.reset();
    }
    return ResultVoid::ok(std::monostate);
}

} // namespace horus::configdb
