#include "horus/logger.hpp"

int main(int argc, char* argv[]) {
    horus::Logger::instance().set_component("configdb");
    horus::Logger::instance().set_log_level(horus::LogLevel::INFO);
    horus::Logger::instance().info("horus-configdb starting v{}", BEOUTOS_VERSION);
    horus::Logger::instance().info("horus-configdb initialized successfully");
    return 0;
}
