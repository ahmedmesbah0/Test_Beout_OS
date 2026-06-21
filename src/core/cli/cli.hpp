#pragma once

#include <string>
#include <vector>
#include <memory>
#include "horus/types.hpp"
#include "command.hpp"

namespace horus::cli {

class CliEngine {
public:
    CliEngine();
    ~CliEngine();

    Result<int> run(int argc, char* argv[]);
    Result<int> execute_command(const std::string& name, const std::vector<std::string>& args);

    void register_command(std::unique_ptr<Command> cmd);
    void show_help();
    void show_version();

private:
    std::vector<std::unique_ptr<Command>> commands_;
};

} // namespace horus::cli
