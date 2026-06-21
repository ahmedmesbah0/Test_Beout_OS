#pragma once

#include <string>
#include <vector>
#include <memory>
#include <optional>
#include <functional>
#include <stdexcept>
#include "horus/types.hpp"

namespace horus {

class DatabaseError : public std::runtime_error {
public:
    explicit DatabaseError(const std::string& msg) : std::runtime_error(msg) {}
};

class PreparedStatement {
public:
    PreparedStatement(sqlite3* db, const std::string& sql);
    ~PreparedStatement();

    void bind_int(int index, int32_t value);
    void bind_int64(int index, int64_t value);
    void bind_double(int index, double value);
    void bind_text(int index, const std::string& value);
    void bind_blob(int index, const std::vector<uint8_t>& value);
    void bind_null(int index);

    bool step();
    void reset();
    void clear_bindings();

    int32_t get_int(int column) const;
    int64_t get_int64(int column) const;
    double get_double(int column) const;
    std::string get_text(int column) const;
    std::vector<uint8_t> get_blob(int column) const;
    bool is_null(int column) const;
    int column_count() const;
    std::string column_name(int column) const;

private:
    sqlite3_stmt* stmt_;
    sqlite3* db_;
    bool has_row_;
};

class Transaction {
public:
    explicit Transaction(sqlite3* db);
    ~Transaction();

    void commit();
    void rollback();

private:
    sqlite3* db_;
    bool active_;
};

class Database {
public:
    explicit Database(const std::string& path);
    ~Database();

    bool open();
    bool close();
    bool is_open() const;

    ResultVoid execute(const std::string& sql);
    std::unique_ptr<PreparedStatement> prepare(const std::string& sql);

    Result<std::optional<std::string>> query_single(const std::string& sql);
    Result<std::vector<std::vector<std::string>>> query(const std::string& sql);

    std::unique_ptr<Transaction> begin_transaction();

    int64_t last_insert_rowid() const;
    int changes() const;

    std::string error_message() const;
    int error_code() const;

    std::string path() const;

    void set_busy_timeout(int milliseconds);

    static bool initialize_schema(const std::string& db_path, const std::string& schema_sql);

private:
    std::string db_path_;
    sqlite3* db_;
    bool is_open_;
};

class ConfigStore {
public:
    explicit ConfigStore(const std::string& db_path);
    ~ConfigStore();

    bool initialize();

    Result<std::string> get(const std::string& key);
    ResultVoid set(const std::string& key, const std::string& value);
    ResultVoid delete_key(const std::string& key);
    Result<bool> has(const std::string& key);

    Result<std::vector<std::pair<std::string, std::string>>> list_keys(const std::string& prefix = "");

private:
    Database db_;
};

} // namespace horus
