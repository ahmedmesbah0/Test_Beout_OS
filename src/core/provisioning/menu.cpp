#include "menu.hpp"
#include "horus/logger.hpp"

namespace horus::provisioning {

Menu::Menu(const std::string& title) : title_(title) {
}

Menu::~Menu() = default;

void Menu::add_entry(const MenuEntry& entry) {
    entries_.push_back(entry);
}

void Menu::display() {
    BEOUTOS_LOG_INFO("Menu::display - " + title_);
}

ResultVoid Menu::process_choice(int choice) {
    if (choice < 0 || choice >= static_cast<int>(entries_.size())) {
        return ResultVoid::error(StatusCode::INVALID_ARGUMENT, "Invalid menu choice");
    }
    return entries_[choice].action();
}

void Menu::set_header(const std::string& header) { header_ = header; }
void Menu::set_footer(const std::string& footer) { footer_ = footer; }

} // namespace horus::provisioning
