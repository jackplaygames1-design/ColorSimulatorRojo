local GroupRewardsConfig = {}

-- Official Color Simulator! Roblox community.
-- Change this one value if the group/community id changes later.
GroupRewardsConfig.GROUP_ID = 1063378529

GroupRewardsConfig.GroupName = "Color Simulator!"
GroupRewardsConfig.GroupUrl = "https://www.roblox.com/communities/1063378529/Color-Simulator#!/about"

GroupRewardsConfig.LuckMultiplier = 1.05
GroupRewardsConfig.CoinMultiplier = 1.05
GroupRewardsConfig.DailyGemReward = 100

GroupRewardsConfig.Testing = {
	-- Studio/dev helper: set player attribute ForceGroupMember = true to test membership.
	ForceMembershipAttribute = "ForceGroupMember",
	ResetDailyAttribute = "ResetGroupDaily",
}

return GroupRewardsConfig
