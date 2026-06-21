#pragma once

#include <string>
#include <vector>
#include <optional>
#include "horus/types.hpp"

namespace horus::cli {

struct ParseResult {
    std::string command;
    std::vector<std::string> arguments;
    std::vector<std::pair<std::string, std::optional<std::string>>> options;
    bool valid;
    std::string error_message;
};

class Parser {
public:
    Parser();
    ~Parser();

    ParseResult parse(int argc, char* argv[]);
    ParseResult parse(const std::string& input);

    static std::vector<std::string> tokenize(const std::string& input);
};

} // namespace horus::cli
