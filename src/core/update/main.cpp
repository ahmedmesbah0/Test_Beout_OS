#include "horus/logger.hpp"

int main(int argc, char* argv[]) {
    horus::Logger::instance().set_component("update");
    horus::Logger::instance().set_log_level(horus::LogLevel::INFO);
    horus::Logger::instance().info("horus-update starting v{}", BEOUTOS_VERSION);
    horus::Logger::instance().info("horus-update initialized successfully");
    return 0;
}
