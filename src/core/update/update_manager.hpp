#pragma once

#include <string>
#include <vector>
#include <optional>
#include "horus/types.hpp"
#include "signature.hpp"
#include "ab_partition.hpp"

namespace horus::update {

enum class UpdateState {
    IDLE,
    CHECKING,
    DOWNLOADING,
    VERIFYING,
    INSTALLING,
    FINALIZING,
    COMPLETED,
    FAILED
};

struct UpdateInfo {
    std::string version;
    std::string description;
    std::string download_url;
    std::string sha256_hash;
    uint64_t size;
    std::string release_date;
    bool mandatory;
};

class UpdateManager {
public:
    UpdateManager();
    ~UpdateManager();

    ResultVoid initialize();
    ResultVoid start();
    ResultVoid stop();

    Result<std::optional<UpdateInfo>> check_for_updates();
    ResultVoid download_update(const UpdateInfo& info);
    ResultVoid verify_update(const std::string& update_file);
    ResultVoid install_update(const std::string& update_file);
    ResultVoid rollback_update();

    UpdateState current_state() const;
    std::string current_version() const;

    ResultVoid set_update_server(const std::string& url);
    ResultVoid set_auto_update(bool enabled);

private:
    UpdateState state_;
    ABPartitionManager partition_mgr_;
    SignatureValidator sig_validator_;
    std::string update_server_url_;
    bool auto_update_enabled_;
};

} // namespace horus::update
