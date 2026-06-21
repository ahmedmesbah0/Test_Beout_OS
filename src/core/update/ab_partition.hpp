#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::update {

enum class PartitionSlot {
    A,
    B
};

struct PartitionInfo {
    PartitionSlot slot;
    std::string device_path;
    std::string mount_path;
    std::string current_version;
    bool active;
    bool bootable;
    bool healthy;
};

class ABPartitionManager {
public:
    ABPartitionManager();
    ~ABPartitionManager();

    ResultVoid initialize();
    Result<PartitionInfo> get_active_partition();
    Result<PartitionInfo> get_inactive_partition();
    Result<PartitionSlot> get_active_slot();

    ResultVoid swap_active();
    ResultVoid mark_bootable(PartitionSlot slot);
    ResultVoid mark_unbootable(PartitionSlot slot);

    ResultVoid write_to_inactive(const std::string& image_path);
    ResultVoid verify_inactive();

    ResultVoid commit_active();
    ResultVoid rollback();

    Result<std::vector<PartitionInfo>> get_partition_info();
    Result<bool> is_healthy(PartitionSlot slot);

private:
    PartitionInfo partition_a_;
    PartitionInfo partition_b_;
    PartitionSlot active_slot_;
};

} // namespace horus::update
