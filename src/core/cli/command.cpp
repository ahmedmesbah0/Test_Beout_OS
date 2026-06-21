#include "command.hpp"

namespace horus::cli {

Command::Command(const std::string& name, const std::string& description)
    : name_(name)
    , description_(description) {
}

Command::~Command() = default;

std::string Command::help() const {
    return name_ + " - " + description_;
}

const std::string& Command::name() const { return name_; }
const std::string& Command::description() const { return description_; }

} // namespace horus::cli
