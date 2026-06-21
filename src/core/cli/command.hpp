#pragma once

#include <string>
#include <vector>
#include "horus/types.hpp"

namespace horus::cli {

class Command {
public:
    Command(const std::string& name, const std::string& description);
    virtual ~Command();

    virtual Result<int> execute(const std::vector<std::string>& args) = 0;
    virtual std::string help() const;

    const std::string& name() const;
    const std::string& description() const;

private:
    std::string name_;
    std::string description_;
};

} // namespace horus::cli
