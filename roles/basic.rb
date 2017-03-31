name		"Basic"
description	"Basic role for all instances."

run_list	"recipe[apt]",
		"recipe[ntp]",
		"recipe[openssh]",
		"recipe[postfix]",
		"recipe[rkhunter",
		"recipe[user::data_bag]",
		"recipe[unattended-upgrades]",
		"recipe[vim]"
