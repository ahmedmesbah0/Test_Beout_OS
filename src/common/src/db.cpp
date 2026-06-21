#include "horus/db.hpp"
#include "horus/logger.hpp"
#include <sqlite3.h>
#include <cstring>

namespace horus {

PreparedStatement::PreparedStatement(sqlite3* db, const std::string& sql)
    : stmt_(nullptr)
    , db_(db)
    , has_row_(false) {
    int rc = sqlite3_prepare_v2(db_, sql.c_str(), static_cast<int>(sql.size()), &stmt_, nullptr);
    if (rc != SQLITE_OK) {
        throw DatabaseError(std::string("Failed to prepare statement: ") + sqlite3_errmsg(db_));
    }
}

PreparedStatement::~PreparedStatement() {
    if (stmt_) {
        sqlite3_finalize(stmt_);
    }
}

void PreparedStatement::bind_int(int index, int32_t value) {
    sqlite3_bind_int(stmt_, index, value);
}

void PreparedStatement::bind_int64(int index, int64_t value) {
    sqlite3_bind_int64(stmt_, index, value);
}

void PreparedStatement::bind_double(int index, double value) {
    sqlite3_bind_double(stmt_, index, value);
}

void PreparedStatement::bind_text(int index, const std::string& value) {
    sqlite3_bind_text(stmt_, index, value.c_str(), static_cast<int>(value.size()), SQLITE_TRANSIENT);
}

void PreparedStatement::bind_blob(int index, const std::vector<uint8_t>& value) {
    sqlite3_bind_blob(stmt_, index, value.data(), static_cast<int>(value.size()), SQLITE_TRANSIENT);
}

void PreparedStatement::bind_null(int index) {
    sqlite3_bind_null(stmt_, index);
}

bool PreparedStatement::step() {
    int rc = sqlite3_step(stmt_);
    if (rc == SQLITE_ROW) {
        has_row_ = true;
        return true;
    }
    if (rc == SQLITE_DONE) {
        has_row_ = false;
        return false;
    }
    throw DatabaseError(std::string("Step failed: ") + sqlite3_errmsg(db_));
}

void PreparedStatement::reset() {
    sqlite3_reset(stmt_);
    has_row_ = false;
}

void PreparedStatement::clear_bindings() {
    sqlite3_clear_bindings(stmt_);
}

int32_t PreparedStatement::get_int(int column) const {
    return sqlite3_column_int(stmt_, column);
}

int64_t PreparedStatement::get_int64(int column) const {
    return sqlite3_column_int64(stmt_, column);
}

double PreparedStatement::get_double(int column) const {
    return sqlite3_column_double(stmt_, column);
}

std::string PreparedStatement::get_text(int column) const {
    const char* text = reinterpret_cast<const char*>(sqlite3_column_text(stmt_, column));
    return text ? std::string(text) : std::string();
}

std::vector<uint8_t> PreparedStatement::get_blob(int column) const {
    const void* blob = sqlite3_column_blob(stmt_, column);
    int size = sqlite3_column_bytes(stmt_, column);
    if (!blob || size == 0) return {};
    const uint8_t* data = static_cast<const uint8_t*>(blob);
    return std::vector<uint8_t>(data, data + size);
}

bool PreparedStatement::is_null(int column) const {
    return sqlite3_column_type(stmt_, column) == SQLITE_NULL;
}

int PreparedStatement::column_count() const {
    return sqlite3_column_count(stmt_);
}

std::string PreparedStatement::column_name(int column) const {
    return sqlite3_column_name(stmt_, column);
}

Transaction::Transaction(sqlite3* db)
    : db_(db)
    , active_(true) {
    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, "BEGIN IMMEDIATE TRANSACTION;", nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        active_ = false;
        std::string error = err_msg ? err_msg : "unknown error";
        sqlite3_free(err_msg);
        throw DatabaseError(std::string("Failed to begin transaction: ") + error);
    }
}

Transaction::~Transaction() {
    if (active_) {
        try {
            rollback();
        } catch (...) {
        }
    }
}

void Transaction::commit() {
    if (!active_) return;
    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, "COMMIT;", nullptr, nullptr, &err_msg);
    active_ = false;
    if (rc != SQLITE_OK) {
        std::string error = err_msg ? err_msg : "unknown error";
        sqlite3_free(err_msg);
        throw DatabaseError(std::string("Failed to commit transaction: ") + error);
    }
}

void Transaction::rollback() {
    if (!active_) return;
    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, "ROLLBACK;", nullptr, nullptr, &err_msg);
    active_ = false;
    if (rc != SQLITE_OK) {
        std::string error = err_msg ? err_msg : "unknown error";
        sqlite3_free(err_msg);
        throw DatabaseError(std::string("Failed to rollback transaction: ") + error);
    }
}

Database::Database(const std::string& path)
    : db_path_(path)
    , db_(nullptr)
    , is_open_(false) {
}

Database::~Database() {
    if (is_open_) {
        close();
    }
}

bool Database::open() {
    if (is_open_) return true;

    int rc = sqlite3_open(db_path_.c_str(), &db_);
    if (rc != SQLITE_OK) {
        Logger::instance().error("Failed to open database {}: {}", db_path_, sqlite3_errmsg(db_));
        sqlite3_close(db_);
        db_ = nullptr;
        return false;
    }

    sqlite3_exec(db_, "PRAGMA journal_mode=WAL;", nullptr, nullptr, nullptr);
    sqlite3_exec(db_, "PRAGMA synchronous=NORMAL;", nullptr, nullptr, nullptr);
    sqlite3_exec(db_, "PRAGMA foreign_keys=ON;", nullptr, nullptr, nullptr);
    sqlite3_exec(db_, "PRAGMA busy_timeout=5000;", nullptr, nullptr, nullptr);

    is_open_ = true;
    Logger::instance().info("Database opened: {}", db_path_);
    return true;
}

bool Database::close() {
    if (!is_open_) return true;
    int rc = sqlite3_close(db_);
    db_ = nullptr;
    is_open_ = false;
    if (rc != SQLITE_OK) {
        Logger::instance().error("Failed to close database: {}", db_path_);
        return false;
    }
    Logger::instance().info("Database closed: {}", db_path_);
    return true;
}

bool Database::is_open() const {
    return is_open_;
}

ResultVoid Database::execute(const std::string& sql) {
    if (!is_open_) {
        return ResultVoid::error(StatusCode::DATABASE_ERROR, "Database not open");
    }

    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, sql.c_str(), nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        std::string error = err_msg ? err_msg : "unknown error";
        sqlite3_free(err_msg);
        Logger::instance().error("SQL error: {}", error);
        return ResultVoid::error(StatusCode::DATABASE_ERROR, error);
    }

    return ResultVoid::ok(std::monostate);
}

std::unique_ptr<PreparedStatement> Database::prepare(const std::string& sql) {
    if (!is_open_) {
        throw DatabaseError("Database not open");
    }
    return std::make_unique<PreparedStatement>(db_, sql);
}

Result<std::optional<std::string>> Database::query_single(const std::string& sql) {
    if (!is_open_) {
        return Result<std::optional<std::string>>::error(StatusCode::DATABASE_ERROR, "Database not open");
    }

    auto stmt = prepare(sql);
    if (stmt->step()) {
        return Result<std::optional<std::string>>::ok(stmt->get_text(0));
    }
    return Result<std::optional<std::string>>::ok(std::nullopt);
}

Result<std::vector<std::vector<std::string>>> Database::query(const std::string& sql) {
    if (!is_open_) {
        return Result<std::vector<std::vector<std::string>>>::error(StatusCode::DATABASE_ERROR, "Database not open");
    }

    std::vector<std::vector<std::string>> rows;
    auto stmt = prepare(sql);
    int cols = stmt->column_count();

    while (stmt->step()) {
        std::vector<std::string> row;
        for (int i = 0; i < cols; ++i) {
            row.push_back(stmt->get_text(i));
        }
        rows.push_back(row);
    }

    return Result<std::vector<std::vector<std::string>>::ok(rows);
}

std::unique_ptr<Transaction> Database::begin_transaction() {
    if (!is_open_) {
        throw DatabaseError("Database not open");
    }
    return std::make_unique<Transaction>(db_);
}

int64_t Database::last_insert_rowid() const {
    return sqlite3_last_insert_rowid(db_);
}

int Database::changes() const {
    return sqlite3_changes(db_);
}

std::string Database::error_message() const {
    return db_ ? sqlite3_errmsg(db_) : "database not open";
}

int Database::error_code() const {
    return db_ ? sqlite3_errcode(db_) : SQLITE_ERROR;
}

std::string Database::path() const {
    return db_path_;
}

void Database::set_busy_timeout(int milliseconds) {
    if (db_) {
        sqlite3_busy_timeout(db_, milliseconds);
    }
}

bool Database::initialize_schema(const std::string& db_path, const std::string& schema_sql) {
    Database db(db_path);
    if (!db.open()) return false;
    auto result = db.execute(schema_sql);
    return result.is_ok();
}

ConfigStore::ConfigStore(const std::string& db_path)
    : db_(db_path) {
}

ConfigStore::~ConfigStore() {
}

bool ConfigStore::initialize() {
    if (!db_.open()) return false;

    auto result = db_.execute(
        "CREATE TABLE IF NOT EXISTS config_store ("
        "  key TEXT PRIMARY KEY,"
        "  value TEXT NOT NULL,"
        "  updated_at TEXT NOT NULL DEFAULT (datetime('now'))"
        ");"
        "CREATE INDEX IF NOT EXISTS idx_config_key ON config_store(key);"
    );

    if (!result.is_ok()) {
        Logger::instance().error("Failed to initialize config store: {}", result.error_message());
        return false;
    }

    Logger::instance().info("Config store initialized");
    return true;
}

Result<std::string> ConfigStore::get(const std::string& key) {
    auto stmt = db_.prepare("SELECT value FROM config_store WHERE key = ?");
    stmt->bind_text(1, key);

    if (stmt->step()) {
        return Result<std::string>::ok(stmt->get_text(0));
    }

    return Result<std::string>::error(StatusCode::NOT_FOUND, "Key not found: " + key);
}

ResultVoid ConfigStore::set(const std::string& key, const std::string& value) {
    auto stmt = db_.prepare(
        "INSERT OR REPLACE INTO config_store (key, value, updated_at) "
        "VALUES (?, ?, datetime('now'))"
    );
    stmt->bind_text(1, key);
    stmt->bind_text(2, value);

    if (!stmt->step()) {
        return ResultVoid::error(StatusCode::DATABASE_ERROR, "Failed to set config key");
    }

    return ResultVoid::ok(std::monostate);
}

ResultVoid ConfigStore::delete_key(const std::string& key) {
    auto stmt = db_.prepare("DELETE FROM config_store WHERE key = ?");
    stmt->bind_text(1, key);

    if (!stmt->step()) {
        return ResultVoid::error(StatusCode::NOT_FOUND, "Key not found: " + key);
    }

    return ResultVoid::ok(std::monostate);
}

Result<bool> ConfigStore::has(const std::string& key) {
    auto stmt = db_.prepare("SELECT COUNT(*) FROM config_store WHERE key = ?");
    stmt->bind_text(1, key);

    if (stmt->step()) {
        return Result<bool>::ok(stmt->get_int(0) > 0);
    }

    return Result<bool>::ok(false);
}

Result<std::vector<std::pair<std::string, std::string>>> ConfigStore::list_keys(const std::string& prefix) {
    std::string sql = "SELECT key, value FROM config_store ORDER BY key";
    if (!prefix.empty()) {
        sql = "SELECT key, value FROM config_store WHERE key LIKE ? ORDER BY key";
    }

    auto stmt = db_.prepare(sql);
    if (!prefix.empty()) {
        stmt->bind_text(1, prefix + "%");
    }

    std::vector<std::pair<std::string, std::string>> entries;
    while (stmt->step()) {
        entries.emplace_back(stmt->get_text(0), stmt->get_text(1));
    }

    return Result<std::vector<std::pair<std::string, std::string>>>::ok(entries);
}

} // namespace horus
