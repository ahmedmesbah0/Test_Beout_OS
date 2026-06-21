#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <optional>
#include <filesystem>

namespace horus {

class Util {
public:
    static std::string trim(const std::string& str);
    static std::string trim_left(const std::string& str);
    static std::string trim_right(const std::string& str);

    static std::vector<std::string> split(const std::string& str, char delimiter);
    static std::string join(const std::vector<std::string>& parts, const std::string& delimiter);

    static std::string to_upper(const std::string& str);
    static std::string to_lower(const std::string& str);
    static std::string replace_all(const std::string& str, const std::string& from, const std::string& to);

    static bool starts_with(const std::string& str, const std::string& prefix);
    static bool ends_with(const std::string& str, const std::string& suffix);
    static bool contains(const std::string& str, const std::string& substring);

    static std::string hex_encode(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> hex_decode(const std::string& hex);

    static std::string base64_encode(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> base64_decode(const std::string& encoded);

    static bool file_exists(const std::string& path);
    static bool directory_exists(const std::string& path);
    static bool create_directory(const std::string& path);
    static bool delete_file(const std::string& path);
    static std::string read_file(const std::string& path);
    static bool write_file(const std::string& path, const std::string& content);
    static std::vector<std::string> list_directory(const std::string& path);

    static std::string generate_machine_id();
    static std::string get_machine_id();

    static std::string sha256(const std::string& input);
    static std::string sha256_file(const std::string& path);
    static std::vector<uint8_t> sha256_raw(const std::string& input);
    static std::vector<uint8_t> sha256_file_raw(const std::string& path);

    static std::string generate_uuid();
    static std::string generate_random_hex(size_t length);

    static std::string timestamp_now();
    static std::string timestamp_iso8601();

    static uint32_t crc32(const std::vector<uint8_t>& data);
};

} // namespace horus
