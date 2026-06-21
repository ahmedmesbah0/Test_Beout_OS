#include "horus/logger.hpp"
#include "horus/types.hpp"
#include <cstring>
#include <ctime>
#include <iomanip>
#include <iostream>

namespace horus {

Logger& Logger::instance() {
    static Logger logger;
    return logger;
}

Logger::Logger()
    : min_level_(LogLevel::INFO)
    , component_("horus")
    , log_file_path_("/var/log/horus/horus.log") {
    openlog("horus", LOG_PID | LOG_NDELAY, LOG_DAEMON);
}

Logger::~Logger() {
    flush();
    if (log_file_.is_open()) {
        log_file_.close();
    }
    closelog();
}

void Logger::set_log_file(const std::string& path) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (log_file_.is_open()) {
        log_file_.flush();
        log_file_.close();
    }
    log_file_path_ = path;
    if (!path.empty()) {
        log_file_.open(path, std::ios::out | std::ios::app);
        if (!log_file_.is_open()) {
            std::cerr << "BeoutOS: Failed to open log file: " << path << std::endl;
        }
    }
}

void Logger::set_log_level(LogLevel level) {
    std::lock_guard<std::mutex> lock(mutex_);
    min_level_ = level;
}

void Logger::set_component(const std::string& component) {
    std::lock_guard<std::mutex> lock(mutex_);
    component_ = component;
}

void Logger::log(LogLevel level, const std::string& message) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (static_cast<int>(level) > static_cast<int>(min_level_)) {
        return;
    }
    std::string formatted = format_message(level, message);
    write_to_syslog(level, formatted);
    write_to_file(formatted);
    if (level >= LogLevel::ERROR) {
        std::cerr << formatted << std::endl;
    }
}

void Logger::log(LogLevel level, const char* format, ...) {
    va_list args;
    va_start(args, format);
    char buffer[4096];
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    log(level, std::string(buffer));
}

void Logger::log_va(LogLevel level, const char* format, va_list args) {
    char buffer[4096];
    vsnprintf(buffer, sizeof(buffer), format, args);
    log(level, std::string(buffer));
}

void Logger::debug(const std::string& message) { log(LogLevel::DEBUG, message); }
void Logger::info(const std::string& message) { log(LogLevel::INFO, message); }
void Logger::warning(const std::string& message) { log(LogLevel::WARNING, message); }
void Logger::error(const std::string& message) { log(LogLevel::ERROR, message); }
void Logger::critical(const std::string& message) { log(LogLevel::CRITICAL, message); }

void Logger::debug(const char* format, ...) {
    va_list args;
    va_start(args, format);
    log_va(LogLevel::DEBUG, format, args);
    va_end(args);
}

void Logger::info(const char* format, ...) {
    va_list args;
    va_start(args, format);
    log_va(LogLevel::INFO, format, args);
    va_end(args);
}

void Logger::warning(const char* format, ...) {
    va_list args;
    va_start(args, format);
    log_va(LogLevel::WARNING, format, args);
    va_end(args);
}

void Logger::error(const char* format, ...) {
    va_list args;
    va_start(args, format);
    log_va(LogLevel::ERROR, format, args);
    va_end(args);
}

void Logger::critical(const char* format, ...) {
    va_list args;
    va_start(args, format);
    log_va(LogLevel::CRITICAL, format, args);
    va_end(args);
}

void Logger::flush() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (log_file_.is_open()) {
        log_file_.flush();
    }
}

std::string Logger::format_message(LogLevel level, const std::string& message) {
    auto now = std::chrono::system_clock::now();
    auto time_t_now = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;

    struct tm tm_buf;
    localtime_r(&time_t_now, &tm_buf);

    std::ostringstream oss;
    oss << std::put_time(&tm_buf, "%Y-%m-%d %H:%M:%S")
        << '.' << std::setfill('0') << std::setw(3) << ms.count()
        << " [" << level_to_string(level) << "] "
        << "[" << component_ << "] "
        << message;

    return oss.str();
}

std::string Logger::level_to_string(LogLevel level) {
    switch (level) {
        case LogLevel::DEBUG:    return "DEBUG";
        case LogLevel::INFO:     return "INFO";
        case LogLevel::WARNING:  return "WARNING";
        case LogLevel::ERROR:    return "ERROR";
        case LogLevel::CRITICAL: return "CRITICAL";
        default:                 return "UNKNOWN";
    }
}

void Logger::write_to_syslog(LogLevel level, const std::string& message) {
    syslog(static_cast<int>(level), "%s", message.c_str());
}

void Logger::write_to_file(const std::string& formatted) {
    if (log_file_.is_open()) {
        log_file_ << formatted << std::endl;
    }
}

} // namespace horus
