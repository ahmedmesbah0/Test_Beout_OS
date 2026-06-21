#include "horus/logger.hpp"

int main(int argc, char* argv[]) {
    horus::Logger::instance().set_component("provisioning");
    horus::Logger::instance().set_log_level(horus::LogLevel::INFO);
    horus::Logger::instance().info("horus-provisioning starting v{}", BEOUTOS_VERSION);
    horus::Logger::instance().info("horus-provisioning initialized successfully");
    return 0;
}
