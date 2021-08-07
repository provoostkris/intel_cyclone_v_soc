set_global_assignment -entity "hdmi_pll" -library "lib_hdmi_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "hdmi_pll" -library "lib_hdmi_pll" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "hdmi_pll" -library "lib_hdmi_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_hdmi_pll" -name SPD_FILE [file join $::quartus(sip_path) "hdmi_pll.spd"]

set_global_assignment -library "lib_hdmi_pll" -name MISC_FILE [file join $::quartus(sip_path) "hdmi_pll_sim/hdmi_pll.vho"]
