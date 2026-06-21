#include "parser.hpp"
#include "horus/util.hpp"

namespace horus::cli {

Parser::Parser() = default;
Parser::~Parser() = default;

ParseResult Parser::parse(int argc, char* argv[]) {
    ParseResult result;
    result.valid = true;
    if (argc < 2) {
        result.valid = false;
        result.error_message = "No command specified";
        return result;
    }
    result.command = argv[1];
    for (int i = 2; i < argc; ++i) {
        result.arguments.push_back(argv[i]);
    }
    return result;
}

ParseResult Parser::parse(const std::string& input) {
    ParseResult result;
    result.valid = true;
    auto tokens = tokenize(input);
    if (tokens.empty()) {
        result.valid = false;
        result.error_message = "Empty input";
        return result;
    }
    result.command = tokens[0];
    for (size_t i = 1; i < tokens.size(); ++i) {
        result.arguments.push_back(tokens[i]);
    }
    return result;
}

std::vector<std::string> Parser::tokenize(const std::string& input) {
    return Util::split(Util::trim(input), ' ');
}

} // namespace horus::cli
