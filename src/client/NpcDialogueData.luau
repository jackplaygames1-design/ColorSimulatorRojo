local NpcDialogueData = {}

NpcDialogueData.DefaultNpcId = "Zork"

NpcDialogueData.Npcs = {
	Zork = {
		DisplayName = "Zork",
		Role = "Brush Merchant + Quest Keeper",
		AccentColor = Color3.fromRGB(76, 214, 224),
		SecondaryColor = Color3.fromRGB(255, 218, 74),
		StartNode = "start",
		StartNodeByColor = {
			Orange = "orange",
			Green = "orange",
		},
		Nodes = {
			start = {
				Lines = {
					"zzt... hey. I'm Zork. I tune brushes, track odd jobs, and occasionally remember where I put my tools.",
					"If you need better paint power, I sell brushes. If you need extra rewards, I keep daily quests warmed up.",
				},
				Options = {
					{ Text = "Show me brushes", Action = "OpenBrushShop", Condition = "BrushShopAvailable" },
					{ Text = "Daily quests", Action = "OpenDailyQuests" },
					{ Text = "How do quests work?", Next = "quests" },
					{ Text = "Who are you?", Next = "about" },
					{ Text = "Bye", Action = "Close" },
				},
			},
			orange = {
				Lines = {
					"zzt... you found the pipe route. Good. The air in here makes paint do weird things.",
					"My starter brush stock stays back in the first shop, but I can still open your daily quests from here.",
				},
				Options = {
					{ Text = "Daily quests", Action = "OpenDailyQuests" },
					{ Text = "What is this place?", Next = "pipes" },
					{ Text = "Bye", Action = "Close" },
				},
			},
			quests = {
				Lines = {
					"Daily quests are little jobs. Clean colors, hatch companions, buy a brush, that sort of thing.",
					"Finish them and you can claim extra rewards. Come back each day and I will have a fresh list.",
				},
				Options = {
					{ Text = "Open quests", Action = "OpenDailyQuests" },
					{ Text = "Back", Next = "start" },
				},
			},
			about = {
				Lines = {
					"I am a certified brush merchant, unofficial quest announcer, and full-time suspicious little genius.",
					"Bring me coins, I bring you better tools. Bring me progress, I bring you more chores with prizes.",
				},
				Options = {
					{ Text = "Show me brushes", Action = "OpenBrushShop", Condition = "BrushShopAvailable" },
					{ Text = "Daily quests", Action = "OpenDailyQuests" },
					{ Text = "Back", Next = "start" },
				},
			},
			pipes = {
				Lines = {
					"The pipes are where Orange Sector starts getting strange. Mutations, hidden routes, stronger colors.",
					"Explore, unlock the teleport, and try not to step on anything glowing unless it looks useful.",
				},
				Options = {
					{ Text = "Open quests", Action = "OpenDailyQuests" },
					{ Text = "Back", Next = "orange" },
				},
			},
		},
	},
}

function NpcDialogueData.GetNpc(npcId)
	return NpcDialogueData.Npcs[npcId] or NpcDialogueData.Npcs[NpcDialogueData.DefaultNpcId]
end

return NpcDialogueData
