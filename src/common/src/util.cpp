#include "horus/util.hpp"
#include "horus/logger.hpp"

#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <zlib.h>

#include <fstream>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <random>
#include <filesystem>
#include <cstring>
#include <cstdlib>

namespace horus {

std::string Util::trim(const std::string& str) {
    return trim_right(trim_left(str));
}

std::string Util::trim_left(const std::string& str) {
    auto it = std::find_if(str.begin(), str.end(), [](unsigned char ch) {
        return !std::isspace(ch);
    });
    return std::string(it, str.end());
}

std::string Util::trim_right(const std::string& str) {
    auto it = std::find_if(str.rbegin(), str.rend(), [](unsigned char ch) {
        return !std::isspace(ch);
    });
    return std::string(str.begin(), it.base());
}

std::vector<std::string> Util::split(const std::string& str, char delimiter) {
    std::vector<std::string> tokens;
    std::istringstream stream(str);
    std::string token;
    while (std::getline(stream, token, delimiter)) {
        if (!token.empty()) {
            tokens.push_back(token);
        }
    }
    return tokens;
}

std::string Util::join(const std::vector<std::string>& parts, const std::string& delimiter) {
    std::ostringstream oss;
    for (size_t i = 0; i < parts.size(); ++i) {
        if (i > 0) oss << delimiter;
        oss << parts[i];
    }
    return oss.str();
}

std::string Util::to_upper(const std::string& str) {
    std::string result = str;
    std::transform(result.begin(), result.end(), result.begin(), [](unsigned char c) {
        return std::toupper(c);
    });
    return result;
}

std::string Util::to_lower(const std::string& str) {
    std::string result = str;
    std::transform(result.begin(), result.end(), result.begin(), [](unsigned char c) {
        return std::tolower(c);
    });
    return result;
}

std::string Util::replace_all(const std::string& str, const std::string& from, const std::string& to) {
    std::string result = str;
    if (from.empty()) return result;
    size_t pos = 0;
    while ((pos = result.find(from, pos)) != std::string::npos) {
        result.replace(pos, from.length(), to);
        pos += to.length();
    }
    return result;
}

bool Util::starts_with(const std::string& str, const std::string& prefix) {
    if (prefix.size() > str.size()) return false;
    return str.compare(0, prefix.size(), prefix) == 0;
}

bool Util::ends_with(const std::string& str, const std::string& suffix) {
    if (suffix.size() > str.size()) return false;
    return str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

bool Util::contains(const std::string& str, const std::string& substring) {
    return str.find(substring) != std::string::npos;
}

std::string Util::hex_encode(const std::vector<uint8_t>& data) {
    std::ostringstream oss;
    for (uint8_t byte : data) {
        oss << std::setfill('0') << std::setw(2) << std::hex << static_cast<int>(byte);
    }
    return oss.str();
}

std::vector<uint8_t> Util::hex_decode(const std::string& hex) {
    std::vector<uint8_t> result;
    if (hex.length() % 2 != 0) return result;
    for (size_t i = 0; i < hex.length(); i += 2) {
        uint8_t byte = static_cast<uint8_t>(std::stoul(hex.substr(i, 2), nullptr, 16));
        result.push_back(byte);
    }
    return result;
}

static const char base64_chars[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string Util::base64_encode(const std::vector<uint8_t>& data) {
    std::string result;
    size_t i = 0;
    size_t len = data.size();

    while (i < len) {
        uint32_t octet_a = i < len ? data[i++] : 0;
        uint32_t octet_b = i < len ? data[i++] : 0;
        uint32_t octet_c = i < len ? data[i++] : 0;

        uint32_t triple = (octet_a << 16) | (octet_b << 8) | octet_c;

        result += base64_chars[(triple >> 18) & 0x3F];
        result += base64_chars[(triple >> 12) & 0x3F];
        result += (i > len + 1) ? '=' : base64_chars[(triple >> 6) & 0x3F];
        result += (i > len) ? '=' : base64_chars[triple & 0x3F];
    }

    return result;
}

std::vector<uint8_t> Util::base64_decode(const std::string& encoded) {
    std::vector<uint8_t> result;
    std::vector<int> decoding_table(256, -1);

    for (int i = 0; i < 64; i++) {
        decoding_table[static_cast<uint8_t>(base64_chars[i])] = i;
    }

    if (encoded.size() % 4 != 0) return result;

    for (size_t i = 0; i < encoded.size(); i += 4) {
        int a = decoding_table[static_cast<uint8_t>(encoded[i])];
        int b = decoding_table[static_cast<uint8_t>(encoded[i + 1])];
        int c = decoding_table[static_cast<uint8_t>(encoded[i + 2])];
        int d = decoding_table[static_cast<uint8_t>(encoded[i + 3])];

        if (a == -1 || b == -1) return result;

        uint32_t triple = (a << 18) | (b << 12) | ((c == -1 ? 0 : c) << 6) | (d == -1 ? 0 : d);

        if (c != -1) result.push_back(static_cast<uint8_t>((triple >> 16) & 0xFF));
        if (d != -1 || c != -1) result.push_back(static_cast<uint8_t>((triple >> 8) & 0xFF));
        if (d != -1) result.push_back(static_cast<uint8_t>(triple & 0xFF));
    }

    return result;
}

bool Util::file_exists(const std::string& path) {
    return std::filesystem::exists(path);
}

bool Util::directory_exists(const std::string& path) {
    return std::filesystem::exists(path) && std::filesystem::is_directory(path);
}

bool Util::create_directory(const std::string& path) {
    try {
        return std::filesystem::create_directories(path);
    } catch (const std::filesystem::filesystem_error&) {
        return false;
    }
}

bool Util::delete_file(const std::string& path) {
    try {
        return std::filesystem::remove(path);
    } catch (const std::filesystem::filesystem_error&) {
        return false;
    }
}

std::string Util::read_file(const std::string& path) {
    std::ifstream file(path, std::ios::in | std::ios::binary);
    if (!file.is_open()) return "";
    std::ostringstream oss;
    oss << file.rdbuf();
    return oss.str();
}

bool Util::write_file(const std::string& path, const std::string& content) {
    std::ofstream file(path, std::ios::out | std::ios::binary);
    if (!file.is_open()) return false;
    file << content;
    file.flush();
    return true;
}

std::vector<std::string> Util::list_directory(const std::string& path) {
    std::vector<std::string> entries;
    try {
        for (const auto& entry : std::filesystem::directory_iterator(path)) {
            entries.push_back(entry.path().string());
        }
    } catch (const std::filesystem::filesystem_error&) {
    }
    return entries;
}

std::string Util::generate_machine_id() {
    std::string id_file = "/etc/machine-id";
    std::string content = read_file(id_file);
    content = trim(content);

    if (!content.empty()) {
        return content;
    }

    std::string dmi_file = "/sys/class/dmi/id/product_uuid";
    content = read_file(dmi_file);
    content = trim(content);

    if (!content.empty()) {
        return sha256(content);
    }

    return generate_uuid();
}

std::string Util::get_machine_id() {
    return generate_machine_id();
}

std::string Util::sha256(const std::string& input) {
    auto hash = sha256_raw(input);
    return hex_encode(hash);
}

std::vector<uint8_t> Util::sha256_raw(const std::string& input) {
    std::vector<uint8_t> hash(SHA256_DIGEST_LENGTH);
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr);
    EVP_DigestUpdate(ctx, input.data(), input.size());
    unsigned int len = 0;
    EVP_DigestFinal_ex(ctx, hash.data(), &len);
    EVP_MD_CTX_free(ctx);
    hash.resize(len);
    return hash;
}

std::string Util::sha256_file(const std::string& path) {
    auto hash = sha256_file_raw(path);
    return hex_encode(hash);
}

std::vector<uint8_t> Util::sha256_file_raw(const std::string& path) {
    std::ifstream file(path, std::ios::in | std::ios::binary);
    if (!file.is_open()) return {};

    std::vector<uint8_t> hash(SHA256_DIGEST_LENGTH);
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr);

    char buffer[8192];
    while (file.read(buffer, sizeof(buffer))) {
        EVP_DigestUpdate(ctx, buffer, file.gcount());
    }
    if (file.gcount() > 0) {
        EVP_DigestUpdate(ctx, buffer, file.gcount());
    }

    unsigned int len = 0;
    EVP_DigestFinal_ex(ctx, hash.data(), &len);
    EVP_MD_CTX_free(ctx);
    hash.resize(len);
    return hash;
}

std::string Util::generate_uuid() {
    std::vector<uint8_t> bytes(16);
    if (RAND_bytes(bytes.data(), bytes.size()) != 1) {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<uint8_t> dist(0, 255);
        for (auto& b : bytes) b = dist(gen);
    }

    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    std::ostringstream oss;
    oss << std::hex << std::setfill('0');
    oss << std::setw(2) << static_cast<int>(bytes[0])
        << std::setw(2) << static_cast<int>(bytes[1])
        << std::setw(2) << static_cast<int>(bytes[2])
        << std::setw(2) << static_cast<int>(bytes[3])
        << "-"
        << std::setw(2) << static_cast<int>(bytes[4])
        << std::setw(2) << static_cast<int>(bytes[5])
        << "-"
        << std::setw(2) << static_cast<int>(bytes[6])
        << std::setw(2) << static_cast<int>(bytes[7])
        << "-"
        << std::setw(2) << static_cast<int>(bytes[8])
        << std::setw(2) << static_cast<int>(bytes[9])
        << "-"
        << std::setw(2) << static_cast<int>(bytes[10])
        << std::setw(2) << static_cast<int>(bytes[11])
        << std::setw(2) << static_cast<int>(bytes[12])
        << std::setw(2) << static_cast<int>(bytes[13])
        << std::setw(2) << static_cast<int>(bytes[14])
        << std::setw(2) << static_cast<int>(bytes[15]);

    return oss.str();
}

std::string Util::generate_random_hex(size_t length) {
    std::vector<uint8_t> bytes(length);
    if (RAND_bytes(bytes.data(), bytes.size()) != 1) {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<uint8_t> dist(0, 255);
        for (auto& b : bytes) b = dist(gen);
    }
    return hex_encode(bytes);
}

std::string Util::timestamp_now() {
    auto now = std::chrono::system_clock::now();
    auto time_t_now = std::chrono::system_clock::to_time_t(now);
    struct tm tm_buf;
    localtime_r(&time_t_now, &tm_buf);
    std::ostringstream oss;
    oss << std::put_time(&tm_buf, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

std::string Util::timestamp_iso8601() {
    auto now = std::chrono::system_clock::now();
    auto time_t_now = std::chrono::system_clock::to_time_t(now);
    struct tm tm_buf;
    gmtime_r(&time_t_now, &tm_buf);
    std::ostringstream oss;
    oss << std::put_time(&tm_buf, "%Y-%m-%dT%H:%M:%SZ");
    return oss.str();
}

uint32_t Util::crc32(const std::vector<uint8_t>& data) {
    return ::crc32(0L, data.data(), static_cast<uInt>(data.size()));
}

} // namespace horus
