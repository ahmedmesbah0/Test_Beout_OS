#pragma once

#include <string>
#include <vector>
#include <functional>
#include "horus/types.hpp"

namespace horus::provisioning {

struct MenuEntry {
    std::string label;
    std::string description;
    std::function<ResultVoid()> action;
};

class Menu {
public:
    Menu(const std::string& title);
    ~Menu();

    void add_entry(const MenuEntry& entry);
    void display();
    ResultVoid process_choice(int choice);

    void set_header(const std::string& header);
    void set_footer(const std::string& footer);

private:
    std::string title_;
    std::string header_;
    std::string footer_;
    std::vector<MenuEntry> entries_;
};

} // namespace horus::provisioning
