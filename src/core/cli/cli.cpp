#include "cli.hpp"
#include "horus/logger.hpp"

namespace horus::cli {

CliEngine::CliEngine() {
    BEOUTOS_LOG_INFO("CliEngine initialized");
}

CliEngine::~CliEngine() = default;

Result<int> CliEngine::run(int argc, char* argv[]) {
    BEOUTOS_LOG_INFO("CliEngine::run called");
    return Result<int>::ok(0);
}

Result<int> CliEngine::execute_command(const std::string& name, const std::vector<std::string>& args) {
    BEOUTOS_LOG_INFO("CliEngine::execute_command: " + name);
    return Result<int>::ok(0);
}

void CliEngine::register_command(std::unique_ptr<Command> cmd) {
    commands_.push_back(std::move(cmd));
}

void CliEngine::show_help() {
}

void CliEngine::show_version() {
}

} // namespace horus::cli
