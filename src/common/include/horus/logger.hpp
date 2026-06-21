#pragma once

#include <string>
#include <mutex>
#include <memory>
#include <fstream>
#include <sstream>
#include <chrono>
#include <cstdarg>
#include <syslog.h>

namespace horus {

enum class LogLevel {
    DEBUG    = LOG_DEBUG,
    INFO     = LOG_INFO,
    WARNING  = LOG_WARNING,
    ERROR    = LOG_ERR,
    CRITICAL = LOG_CRIT
};

class Logger {
public:
    static Logger& instance();

    void set_log_file(const std::string& path);
    void set_log_level(LogLevel level);
    void set_component(const std::string& component);

    void log(LogLevel level, const std::string& message);
    void log(LogLevel level, const char* format, ...);
    void log_va(LogLevel level, const char* format, va_list args);

    void debug(const std::string& message);
    void info(const std::string& message);
    void warning(const std::string& message);
    void error(const std::string& message);
    void critical(const std::string& message);

    void debug(const char* format, ...);
    void info(const char* format, ...);
    void warning(const char* format, ...);
    void error(const char* format, ...);
    void critical(const char* format, ...);

    void flush();

    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

private:
    Logger();
    ~Logger();

    std::string format_message(LogLevel level, const std::string& message);
    std::string level_to_string(LogLevel level);
    void write_to_syslog(LogLevel level, const std::string& message);
    void write_to_file(const std::string& formatted);

    LogLevel min_level_;
    std::string component_;
    std::string log_file_path_;
    std::ofstream log_file_;
    std::mutex mutex_;
};

#define BEOUTOS_LOG_DEBUG(msg)    horus::Logger::instance().debug(msg)
#define BEOUTOS_LOG_INFO(msg)     horus::Logger::instance().info(msg)
#define BEOUTOS_LOG_WARNING(msg)  horus::Logger::instance().warning(msg)
#define BEOUTOS_LOG_ERROR(msg)    horus::Logger::instance().error(msg)
#define BEOUTOS_LOG_CRITICAL(msg) horus::Logger::instance().critical(msg)

} // namespace horus
