#include "firewall_rule.hpp"
#include "horus/logger.hpp"

namespace horus::configdb {

std::string FirewallRule::to_string() const {
    return name + " " + std::to_string(rule_id);
}

FirewallRule FirewallRule::from_string(const std::string& str) {
    FirewallRule rule;
    rule.name = str;
    return rule;
}

FirewallManager::FirewallManager() {
}

FirewallManager::~FirewallManager() = default;

ResultVoid FirewallManager::add_rule(const FirewallRule& rule) {
    BEOUTOS_LOG_INFO("FirewallManager::add_rule: " + rule.name);
    return ResultVoid::ok(std::monostate);
}

ResultVoid FirewallManager::update_rule(uint32_t rule_id, const FirewallRule& rule) {
    BEOUTOS_LOG_INFO("FirewallManager::update_rule: " + std::to_string(rule_id));
    return ResultVoid::ok(std::monostate);
}

ResultVoid FirewallManager::delete_rule(uint32_t rule_id) {
    BEOUTOS_LOG_INFO("FirewallManager::delete_rule: " + std::to_string(rule_id));
    return ResultVoid::ok(std::monostate);
}

Result<FirewallRule> FirewallManager::get_rule(uint32_t rule_id) {
    return Result<FirewallRule>::error(StatusCode::NOT_FOUND, "Rule not found");
}

Result<std::vector<FirewallRule>> FirewallManager::list_rules() {
    return Result<std::vector<FirewallRule>>::ok({});
}

Result<std::vector<FirewallRule>> FirewallManager::list_enabled_rules() {
    return Result<std::vector<FirewallRule>>::ok({});
}

ResultVoid FirewallManager::enable_rule(uint32_t rule_id) {
    BEOUTOS_LOG_INFO("FirewallManager::enable_rule: " + std::to_string(rule_id));
    return ResultVoid::ok(std::monostate);
}

ResultVoid FirewallManager::disable_rule(uint32_t rule_id) {
    BEOUTOS_LOG_INFO("FirewallManager::disable_rule: " + std::to_string(rule_id));
    return ResultVoid::ok(std::monostate);
}

ResultVoid FirewallManager::apply_rules() {
    BEOUTOS_LOG_INFO("FirewallManager::apply_rules");
    return ResultVoid::ok(std::monostate);
}

ResultVoid FirewallManager::flush_rules() {
    BEOUTOS_LOG_INFO("FirewallManager::flush_rules");
    return ResultVoid::ok(std::monostate);
}

ResultVoid FirewallManager::set_default_policy(FirewallAction inbound_action, FirewallAction outbound_action) {
    BEOUTOS_LOG_INFO("FirewallManager::set_default_policy");
    return ResultVoid::ok(std::monostate);
}

} // namespace horus::configdb
