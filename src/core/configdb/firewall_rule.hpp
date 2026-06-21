#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include "horus/types.hpp"

namespace horus::configdb {

enum class FirewallAction {
    ACCEPT,
    DROP,
    REJECT
};

enum class FirewallDirection {
    INBOUND,
    OUTBOUND,
    BOTH
};

struct FirewallRule {
    uint32_t rule_id;
    std::string name;
    FirewallDirection direction;
    FirewallAction action;
    std::string source_address;
    std::string destination_address;
    std::string protocol;
    uint16_t source_port;
    uint16_t destination_port;
    std::string comment;
    bool enabled;

    std::string to_string() const;
    static FirewallRule from_string(const std::string& str);
};

class FirewallManager {
public:
    FirewallManager();
    ~FirewallManager();

    ResultVoid add_rule(const FirewallRule& rule);
    ResultVoid update_rule(uint32_t rule_id, const FirewallRule& rule);
    ResultVoid delete_rule(uint32_t rule_id);
    Result<FirewallRule> get_rule(uint32_t rule_id);
    Result<std::vector<FirewallRule>> list_rules();
    Result<std::vector<FirewallRule>> list_enabled_rules();

    ResultVoid enable_rule(uint32_t rule_id);
    ResultVoid disable_rule(uint32_t rule_id);
    ResultVoid apply_rules();
    ResultVoid flush_rules();

    ResultVoid set_default_policy(FirewallAction inbound_action, FirewallAction outbound_action);
};

} // namespace horus::configdb
