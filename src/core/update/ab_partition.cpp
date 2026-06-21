#include "ab_partition.hpp"
#include "horus/logger.hpp"
#include "horus/util.hpp"

namespace horus::update {

ABPartitionManager::ABPartitionManager()
    : active_slot_(PartitionSlot::A) {
    partition_a_.slot = PartitionSlot::A;
    partition_a_.device_path = "/dev/mmcblk0p2";
    partition_a_.mount_path = "/mnt/partition_a";
    partition_a_.active = true;
    partition_a_.bootable = true;
    partition_a_.healthy = true;

    partition_b_.slot = PartitionSlot::B;
    partition_b_.device_path = "/dev/mmcblk0p3";
    partition_b_.mount_path = "/mnt/partition_b";
    partition_b_.active = false;
    partition_b_.bootable = false;
    partition_b_.healthy = true;
}

ABPartitionManager::~ABPartitionManager() = default;

ResultVoid ABPartitionManager::initialize() {
    BEOUTOS_LOG_INFO("ABPartitionManager::initialize");
    return ResultVoid::ok(std::monostate);
}

Result<PartitionInfo> ABPartitionManager::get_active_partition() {
    if (active_slot_ == PartitionSlot::A) {
        return Result<PartitionInfo>::ok(partition_a_);
    }
    return Result<PartitionInfo>::ok(partition_b_);
}

Result<PartitionInfo> ABPartitionManager::get_inactive_partition() {
    if (active_slot_ == PartitionSlot::A) {
        return Result<PartitionInfo>::ok(partition_b_);
    }
    return Result<PartitionInfo>::ok(partition_a_);
}

Result<PartitionSlot> ABPartitionManager::get_active_slot() {
    return Result<PartitionSlot>::ok(active_slot_);
}

ResultVoid ABPartitionManager::swap_active() {
    BEOUTOS_LOG_INFO("ABPartitionManager::swap_active");
    if (active_slot_ == PartitionSlot::A) {
        active_slot_ = PartitionSlot::B;
        partition_a_.active = false;
        partition_b_.active = true;
    } else {
        active_slot_ = PartitionSlot::A;
        partition_b_.active = false;
        partition_a_.active = true;
    }
    return ResultVoid::ok(std::monostate);
}

ResultVoid ABPartitionManager::mark_bootable(PartitionSlot slot) {
    BEOUTOS_LOG_INFO("ABPartitionManager::mark_bootable");
    if (slot == PartitionSlot::A) {
        partition_a_.bootable = true;
    } else {
        partition_b_.bootable = true;
    }
    return ResultVoid::ok(std::monostate);
}

ResultVoid ABPartitionManager::mark_unbootable(PartitionSlot slot) {
    BEOUTOS_LOG_INFO("ABPartitionManager::mark_unbootable");
    if (slot == PartitionSlot::A) {
        partition_a_.bootable = false;
    } else {
        partition_b_.bootable = false;
    }
    return ResultVoid::ok(std::monostate);
}

ResultVoid ABPartitionManager::write_to_inactive(const std::string& image_path) {
    BEOUTOS_LOG_INFO("ABPartitionManager::write_to_inactive: " + image_path);
    return ResultVoid::ok(std::monostate);
}

ResultVoid ABPartitionManager::verify_inactive() {
    BEOUTOS_LOG_INFO("ABPartitionManager::verify_inactive");
    return ResultVoid::ok(std::monostate);
}

ResultVoid ABPartitionManager::commit_active() {
    BEOUTOS_LOG_INFO("ABPartitionManager::commit_active");
    return ResultVoid::ok(std::monostate);
}

ResultVoid ABPartitionManager::rollback() {
    BEOUTOS_LOG_INFO("ABPartitionManager::rollback");
    return swap_active();
}

Result<std::vector<PartitionInfo>> ABPartitionManager::get_partition_info() {
    return Result<std::vector<PartitionInfo>>::ok({partition_a_, partition_b_});
}

Result<bool> ABPartitionManager::is_healthy(PartitionSlot slot) {
    if (slot == PartitionSlot::A) {
        return Result<bool>::ok(partition_a_.healthy);
    }
    return Result<bool>::ok(partition_b_.healthy);
}

} // namespace horus::update
