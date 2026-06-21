#pragma once

#include <string>
#include <vector>
#include <optional>
#include <memory>
#include "horus/types.hpp"
#include "horus/db.hpp"

namespace horus::configdb {

class ConfigDBStore {
public:
    explicit ConfigDBStore(const std::string& db_path);
    ~ConfigDBStore();

    bool initialize();
    ResultVoid load_schema();

    Result<std::string> get_setting(const std::string& section, const std::string& key);
    ResultVoid set_setting(const std::string& section, const std::string& key, const std::string& value);
    ResultVoid delete_setting(const std::string& section, const std::string& key);
    Result<std::vector<std::pair<std::string, std::string>>> list_settings(const std::string& section);

    ResultVoid begin_transaction();
    ResultVoid commit_transaction();
    ResultVoid rollback_transaction();

private:
    Database db_;
    std::unique_ptr<Transaction> current_transaction_;
};

} // namespace horus::configdb
