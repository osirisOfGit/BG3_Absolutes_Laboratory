---@class MutationsConfig
ConfigurationStructure.config.mutations = {}

---@class MutationSettings
ConfigurationStructure.config.mutations.settings = {
	defaultProfile = nil,
	---@class StatBrowserSettings
	statBrowser = {
		onlyIcons = true,
		sort = {
			---@type "displayName"|"spellName"
			name = "displayName",
			direction = "Descending"
		},
		showAllSpellLevels = false
	},
	mutationDesigner = {
		---@type "Sidebar"|"Infinite"
		mutatorStyle = "Sidebar"
	},
	mutationPresets = {
		---@type {[string]: Mutator[]}
		mutators = {},
		---@type {[string]: SelectorQuery[]}
		selectors = {}
	},
	actionResourceDistributionPresets = {
		["Default"] = {
			[1] = 1
		}
	},
	---@type {[string]: number[]}
	abilitiesDistributionPresets = {
		["Default"] = {
			[1] = 0
		}
	},
	classesAndSubclassesDefaultVariants = {
		---@type {[string] : string}
		nameGuidMap = {
			["AbjurationSchool"] = "e6a0eb75-7a01-4f40-8563-24ba2615e99b",
			["Alchemist"] = "17fbaf2f-5b9a-46f4-806f-06b62a8ce24f",
			["Ancients"] = "b36d247e-d39f-4ae9-9476-3ec315c55789",
			["ArcaneArcher"] = "1be5aa5a-e221-4f0e-a1bf-be25f5d23224",
			["ArcaneTrickster"] = "ede4778e-7602-440f-9075-b4bc8dc31cea",
			["Archfey"] = "733ddf8c-9ec4-4c5a-85e3-c70fd3df3c24",
			["Armorer"] = "18fbaf2f-5b9a-46f4-806f-06b62a8ce24f",
			["Artificer"] = "03f972eb-de3c-4cdb-9050-e8e3fa0526eb",
			["Artillerist"] = "19fbaf2f-5b9a-46f4-806f-06b62a8ce24f",
			["Assassin"] = "b53a8061-f31d-4985-adfe-d4d691a918d9",
			["Banneret5e"] = "38ea7fea-c486-40e3-973b-b9bc633d4aaa",
			["Barbarian"] = "d8cadb42-0ff9-4049-afaf-e5d78d06a399",
			["Bard"] = "92cd50b6-eb1b-4824-8adb-853e90c34c90",
			["BattleMaster"] = "e668c6f1-5149-4b10-ab7e-3637ed444066",
			["BattleSmith"] = "16fbaf2f-5b9a-46f4-806f-06b62a8ce24f",
			["BeastMaster"] = "6fd9547d-cc28-400e-bfa9-3a85baa70f24",
			["BerserkerPath"] = "32eee7d8-1b2f-4de5-b9ee-78fbd286c6ef",
			["BladesingingSchool"] = "8047cf29-2c79-4f12-a4bf-d965a023be63",
			["Brute5e"] = "3449e88a-b378-40c2-b505-f8fe43d26c2d",
			["Cavalier5e"] = "b3c39e0a-aa51-416f-b2a2-c848d56f4890",
			["Champion"] = "0a01dc6b-ab1a-4c0e-8a5e-4787fe1f2caf",
			["CircleOfStars"] = "fe416267-36f0-4346-90fc-4aeb7f25ec07",
			["CircleOfTheDreams"] = "6950ed9f-9c7c-4176-9f27-ecfc83b6f141",
			["CircleOfTheLand"] = "7458da78-34b7-4150-a42f-37197ab04510",
			["CircleOfTheMoon"] = "3eab0689-e51b-4634-a690-0375d3cb2716",
			["CircleOfTheShepherd"] = "6b456176-3291-43ba-9e37-70c44d7118c4",
			["CircleOfTheSpores"] = "4b61af6c-4a44-436e-aa0a-0d11a2d6b8ee",
			["CircleOfWildfire"] = "847f3805-a507-49ec-98b2-624f18ffd094",
			["Cleric"] = "114e7aee-d1d4-4371-8d90-8a2080592faf",
			["ConjurationSchool"] = "7a3feb8d-dda7-46ec-9029-1f302f537432",
			["Crown"] = "eaad98ec-026b-429e-aa24-8274dfd1ecb7",
			["DeathDomain"] = "b927a22a-d64b-48d6-bc7c-38c5f7f6a061",
			["DeathKnight"] = "52296c38-fbb5-4e3a-a728-0420884ed152",
			["Devotion"] = "1c761ad0-6f5f-409e-ac1d-ddf6f85c1fc4",
			["DivinationSchool"] = "7577b0e1-a517-4f82-8f72-05a227dc5e88",
			["DraconicBloodline"] = "36286b0a-26f9-4b4e-9311-fd1404301d20",
			["Druid"] = "457d0a6e-9da8-4f95-a225-18382f0e94b5",
			["DrunkenMaster"] = "d8d9e1e3-cbd6-4240-ab1e-bd3626cb5532",
			["EldritchKnight"] = "b722614a-303f-411a-bb19-a1882ad1f4cc",
			["EnchantmentSchool"] = "46d31950-6917-444e-ac87-706702825215",
			["EvocationSchool"] = "c059dca1-c17d-4dce-8260-83ede5070eac",
			["Fiend"] = "8866db28-7dda-4fd6-93ed-20eca16314f0",
			["Fighter"] = "721dfac3-92d4-41f5-b773-b7072a86232f",
			["FourElements"] = "22894c32-54cf-49ea-b366-44bfcf01bb2a",
			["GiantPath"] = "07234f31-c239-4a57-aeb4-868f3e1a318e",
			["GlamourCollege"] = "a06241d2-c432-472c-8c7d-84228d530cfa",
			["GloomStalker"] = "d5f10e55-84e3-409b-aa64-2098c9550319",
			["GreatOldOne"] = "e1e4a21f-9405-46ec-81a0-ccc8d58d9736",
			["Hexblade"] = "8fb57960-eb92-48f5-b99d-ab36519e4d4f",
			["Hunter"] = "0aa1cff9-c45f-4d00-a95b-99a7aa96dd06",
			["IllusionSchool"] = "436c9e1a-3a39-48dd-b753-7cee1bd19c00",
			["KnowledgeDomain"] = "ebe18794-b5e1-41c4-befa-4b9d6922b0ec",
			["LifeDomain"] = "4b5da2f5-b999-4623-8bff-a63df5560fb3",
			["LightDomain"] = "c54d7591-b305-4f22-b2a7-1bf5c4a3470a",
			["LoreCollege"] = "d21368ac-c776-465c-9dcf-6123dd52734f",
			["Monk"] = "c4598bdb-fc07-40dd-a62c-90cc138bd76f",
			["NatureDomain"] = "6dec76d0-df22-411c-8a78-3d6fb843ae50",
			["NecromancySchool"] = "fbb8347b-20e3-4846-ba91-0552cd12fc5f",
			["Oathbreaker"] = "6fb3831e-45d8-4b30-9714-6fe73988921b",
			["OathofConquest"] = "0b7ad348-c9b6-4a3c-8519-fd9a509e72df",
			["OpenHand"] = "2a5e3097-384c-4d29-8d6e-054fdfd26b80",
			["Paladin"] = "ff4d9497-023c-434a-bd14-82fc367e991c",
			["PsiWarrior5e"] = "d30f652e-a5ed-4d78-bc18-25290ceec524",
			["Ranger"] = "36be18ba-23db-4dff-bfa6-ae105ce43144",
			["Rogue"] = "e8b1eab0-ef11-40a2-8a0b-cee8d062bf2a",
			["RuneKnight5e"] = "2f5a4183-8885-49dc-a211-fa1c53bc1606",
			["Samurai5e"] = "7f93e89c-fe4d-49a8-ad45-666071bd962f",
			["Shadow"] = "bf46d73f-d406-4cb8-9a1d-e6e758ca02c7",
			["ShadowMagic"] = "b443a7fa-b36a-4cbc-9e4b-f3167de34d1b",
			["Sharpshooter5e"] = "59091945-177c-419d-a847-46901a8a8687",
			["Sorcerer"] = "784001e2-c96d-4153-beb6-2adbef5abc92",
			["SorcererDivineSoul"] = "3dbfa754-2ead-40f8-83f4-4ad3079585dd",
			["StormSorcery"] = "d379fdae-b401-4731-8d50-277c73919ae3",
			["Swarmkeeper"] = "29dc22b5-5e22-46d8-99f9-02e348f0b0b2",
			["Swashbuckler"] = "f87d7b0e-bc56-4f22-b347-9ef63bfa5220",
			["SwordsCollege"] = "c4bd5252-d68a-4330-9431-5e8ab24c5f29",
			["TempestDomain"] = "89bacf1b-8f15-4972-ada7-bf59c7c78441",
			["Thief"] = "32c7b8df-a6ec-4848-a9db-c0dce781beb9",
			["TotemWarriorPath"] = "2e585948-d775-451d-b58b-15b75321d11e",
			["TransmutationSchool"] = "a12f2924-30b4-4185-9db9-2c5b383ff449",
			["TrickeryDomain"] = "f013d01b-3310-43f7-81bf-a51130442b5e",
			["ValorCollege"] = "2b46330d-0ada-4eb5-a131-3d250a41ca6a",
			["Vengeance"] = "3cc3d397-c47d-4966-87ae-88827f73f645",
			["WarDomain"] = "b9ccf90e-b35b-4b73-b896-8ed2d32ae8c6",
			["Warlock"] = "b4225a4b-4bbe-4d97-9e3c-4719dbd1487c",
			["WildMagic"] = "14374d37-a70e-41a8-9dc5-85a23f8b5dd2",
			["WildMagicPath"] = "d6bf00fc-3518-4d63-ba8b-03532c1abc4d",
			["Wizard"] = "a865965f-501b-46e9-9eaa-7748e8c04d09"
		},
		---@type {[Guid] : Guid}
		vanillaToVariants = {
			["03f972eb-de3c-4cdb-9050-e8e3fa0526eb"] = "fbe05228-1926-4aaa-ee8d-f600f8db20ef",
			["07234f31-c239-4a57-aeb4-868f3e1a318e"] = "3dc1eb7f-e32b-4c8e-06b0-fe8d99bb6b4e",
			["0a01dc6b-ab1a-4c0e-8a5e-4787fe1f2caf"] = "af749025-b392-401c-0e81-f26bd9146ae9",
			["0aa1cff9-c45f-4d00-a95b-99a7aa96dd06"] = "f96a5477-8261-455b-a88e-9a5b647776d7",
			["0b7ad348-c9b6-4a3c-8519-fd9a509e72df"] = "f29c6cc7-8fec-4689-1eba-20c586459b68",
			["114e7aee-d1d4-4371-8d90-8a2080592faf"] = "b6c10501-5860-4d60-f3a0-46566692f491",
			["14374d37-a70e-41a8-9dc5-85a23f8b5dd2"] = "2914ed9f-818e-4a58-9fa2-5f2402eb0570",
			["16fbaf2f-5b9a-46f4-806f-06b62a8ce24f"] = "70c94344-62c2-4d6b-3c8c-0d3a3832ba2b",
			["17fbaf2f-5b9a-46f4-806f-06b62a8ce24f"] = "3bcac3f5-ef3d-4530-a698-8d0c574f273a",
			["18fbaf2f-5b9a-46f4-806f-06b62a8ce24f"] = "49b807dc-53f1-41ef-f89b-16dbca057763",
			["19fbaf2f-5b9a-46f4-806f-06b62a8ce24f"] = "bb33bf32-4da6-46cc-cb82-4653f148e58e",
			["1be5aa5a-e221-4f0e-a1bf-be25f5d23224"] = "76c5ca89-1075-4db0-569d-c0c734b92348",
			["1c761ad0-6f5f-409e-ac1d-ddf6f85c1fc4"] = "b252c50f-2072-4fcb-6e9f-030bb4d65e9a",
			["22894c32-54cf-49ea-b366-44bfcf01bb2a"] = "2f657c0f-0c1a-43d7-6a99-b90e089c595d",
			["29dc22b5-5e22-46d8-99f9-02e348f0b0b2"] = "a2427bd6-8249-4795-b784-ebbef1ec4cdd",
			["2a5e3097-384c-4d29-8d6e-054fdfd26b80"] = "e628ffb2-5073-4f10-4c80-0ac316273b34",
			["2b46330d-0ada-4eb5-a131-3d250a41ca6a"] = "ad53d3ab-f8c5-4715-a7bf-3a08a288193e",
			["2e585948-d775-451d-b58b-15b75321d11e"] = "a19158bf-12d4-4cde-1eb5-efd9a1a54110",
			["2f5a4183-8885-49dc-a211-fa1c53bc1606"] = "367ef074-57d9-4936-b58e-b37d64bfd7a3",
			["32c7b8df-a6ec-4848-a9db-c0dce781beb9"] = "1ac37b9e-4e7f-4575-5faa-5e97c258731e",
			["32eee7d8-1b2f-4de5-b9ee-78fbd286c6ef"] = "02aa9e4e-3e9a-468d-629e-0d1b73181c08",
			["3449e88a-b378-40c2-b505-f8fe43d26c2d"] = "c2cf33f7-070d-4555-8293-579adbfdf4c8",
			["36286b0a-26f9-4b4e-9311-fd1404301d20"] = "c548ed15-73f6-4054-6488-f5bac8b475ea",
			["36be18ba-23db-4dff-bfa6-ae105ce43144"] = "ccf56842-c1b3-4a2b-e683-e8a65ebf535c",
			["38ea7fea-c486-40e3-973b-b9bc633d4aaa"] = "152f1916-37a6-42df-f690-0caf504f378e",
			["3cc3d397-c47d-4966-87ae-88827f73f645"] = "cea84458-3e73-4627-adbe-4707c35ae8c7",
			["3dbfa754-2ead-40f8-83f4-4ad3079585dd"] = "1b8a1304-23b5-4b51-c0a5-7d52ca17542f",
			["3eab0689-e51b-4634-a690-0375d3cb2716"] = "4be92f8c-c0f8-43b5-c498-4af42fefc329",
			["436c9e1a-3a39-48dd-b753-7cee1bd19c00"] = "34852be1-7936-4625-6eb9-66eefec980c9",
			["457d0a6e-9da8-4f95-a225-18382f0e94b5"] = "796e956d-5b33-4c04-eca8-73818645fc2c",
			["46d31950-6917-444e-ac87-706702825215"] = "194464b4-4cb6-4dbe-b892-f0049c6c96f2",
			["4b5da2f5-b999-4623-8bff-a63df5560fb3"] = "ea89b106-f9b2-4fe1-4ea5-d0b9a82867e9",
			["4b61af6c-4a44-436e-aa0a-0d11a2d6b8ee"] = "808d6ca2-6ffa-4089-728c-a863aa08c924",
			["52296c38-fbb5-4e3a-a728-0420884ed152"] = "35ce3ab2-90a1-4477-61a1-a516cc0dd279",
			["59091945-177c-419d-a847-46901a8a8687"] = "f8be4497-3315-4d83-4ba1-1b0ea3565938",
			["6950ed9f-9c7c-4176-9f27-ecfc83b6f141"] = "74e0e5be-26a3-4f87-a890-3597a2d58a95",
			["6b456176-3291-43ba-9e37-70c44d7118c4"] = "b8430c74-2532-4bfa-e59b-d52891d72471",
			["6dec76d0-df22-411c-8a78-3d6fb843ae50"] = "a26ad793-4e52-48de-6eb1-93427a69dd97",
			["6fb3831e-45d8-4b30-9714-6fe73988921b"] = "6dc514d3-4543-4758-0d86-2307017ee589",
			["6fd9547d-cc28-400e-bfa9-3a85baa70f24"] = "cfb39b4d-ac17-4448-11bf-49df8c0f6c61",
			["721dfac3-92d4-41f5-b773-b7072a86232f"] = "fe5af7bf-fc68-4436-e6b2-baadf64cb66d",
			["733ddf8c-9ec4-4c5a-85e3-c70fd3df3c24"] = "b05d05cd-765b-4827-22b9-b3691eeb6c02",
			["7458da78-34b7-4150-a42f-37197ab04510"] = "f5cbe921-4414-4b24-9289-a093adfe4012",
			["7577b0e1-a517-4f82-8f72-05a227dc5e88"] = "8e7b5b15-cb23-41fe-1bb3-bc239d3a991c",
			["784001e2-c96d-4153-beb6-2adbef5abc92"] = "c47cf251-ed0d-4599-a2a3-79dada2976d5",
			["7a3feb8d-dda7-46ec-9029-1f302f537432"] = "a7668c21-bd60-4133-c2b7-69099f8f451c",
			["7f93e89c-fe4d-49a8-ad45-666071bd962f"] = "33a47d67-b21d-4e55-889f-72ac0f64891b",
			["8047cf29-2c79-4f12-a4bf-d965a023be63"] = "36dc4a9e-6b78-42f2-e484-e6b805009bdd",
			["847f3805-a507-49ec-98b2-624f18ffd094"] = "aa2f781c-e933-4d04-faac-f55f69603d56",
			["8866db28-7dda-4fd6-93ed-20eca16314f0"] = "f33affef-651c-4aae-ae86-b344cbfb4fa6",
			["89bacf1b-8f15-4972-ada7-bf59c7c78441"] = "167f5a2e-5931-49a2-94a4-44df8c8e380d",
			["8fb57960-eb92-48f5-b99d-ab36519e4d4f"] = "44b6e44e-19da-4347-eeaa-27db25d995e2",
			["92cd50b6-eb1b-4824-8adb-853e90c34c90"] = "cb56dc8b-1a8f-4ace-6c82-56257ae25956",
			["a06241d2-c432-472c-8c7d-84228d530cfa"] = "686f664d-be25-4dc7-45b4-dd6d4266a5eb",
			["a12f2924-30b4-4185-9db9-2c5b383ff449"] = "66d621bc-fc6d-46bc-21b9-2f1dac0daebd",
			["a865965f-501b-46e9-9eaa-7748e8c04d09"] = "a6762005-fcbd-4e11-15ac-1a041048b964",
			["b36d247e-d39f-4ae9-9476-3ec315c55789"] = "b6044578-27c4-455d-ebbf-90f580272c3a",
			["b3c39e0a-aa51-416f-b2a2-c848d56f4890"] = "c8ac9ff5-e7fb-4eca-47b6-63d59659027c",
			["b4225a4b-4bbe-4d97-9e3c-4719dbd1487c"] = "c87bf5f1-d06b-4dfa-7998-2ee3c67dee92",
			["b443a7fa-b36a-4cbc-9e4b-f3167de34d1b"] = "d05bfbfa-041e-462b-b3b0-5ecbf542fb39",
			["b53a8061-f31d-4985-adfe-d4d691a918d9"] = "b3341143-2339-45dd-92b2-9663d0d94be6",
			["b722614a-303f-411a-bb19-a1882ad1f4cc"] = "7bf8a0da-4295-40bd-dca9-ba2893691d69",
			["b927a22a-d64b-48d6-bc7c-38c5f7f6a061"] = "47f91bde-08a5-41c7-6198-1a6f58dda2f7",
			["b9ccf90e-b35b-4b73-b896-8ed2d32ae8c6"] = "3448c90f-a879-48cd-ad9b-423ab2354fac",
			["bf46d73f-d406-4cb8-9a1d-e6e758ca02c7"] = "bc9fe3fa-db7a-4790-1099-5533a578e2c6",
			["c059dca1-c17d-4dce-8260-83ede5070eac"] = "cf3d5e59-045e-4db4-0ea2-20c544fa63c0",
			["c4598bdb-fc07-40dd-a62c-90cc138bd76f"] = "a634e602-3b91-48ed-21ae-1f87e099e7be",
			["c4bd5252-d68a-4330-9431-5e8ab24c5f29"] = "92daefd5-7a04-4930-acb5-f005f8bf42b7",
			["c54d7591-b305-4f22-b2a7-1bf5c4a3470a"] = "0b154309-97d5-4c95-a1bc-67e43192a048",
			["d21368ac-c776-465c-9dcf-6123dd52734f"] = "d7cb1ea6-89ea-43e7-3989-134dc47d85d5",
			["d30f652e-a5ed-4d78-bc18-25290ceec524"] = "e2c3380c-bc74-4911-8d88-919d2e4ab125",
			["d379fdae-b401-4731-8d50-277c73919ae3"] = "d7d25214-24f4-406e-e283-827ef69e1d48",
			["d5f10e55-84e3-409b-aa64-2098c9550319"] = "bb193ccc-8b74-4b31-e5ad-650084aaee79",
			["d6bf00fc-3518-4d63-ba8b-03532c1abc4d"] = "80c37bb8-a06c-458a-1c9e-38f191440648",
			["d8cadb42-0ff9-4049-afaf-e5d78d06a399"] = "4aa352b0-65db-4d33-b590-3a8b9986f72f",
			["d8d9e1e3-cbd6-4240-ab1e-bd3626cb5532"] = "9e0ebcd1-8800-4001-e69e-c597f03deb0c",
			["e1e4a21f-9405-46ec-81a0-ccc8d58d9736"] = "37675da6-d900-4b7c-50a1-c489ac2bf12c",
			["e668c6f1-5149-4b10-ab7e-3637ed444066"] = "0e1c959f-34b5-4824-f4ac-b32edb04099b",
			["e6a0eb75-7a01-4f40-8563-24ba2615e99b"] = "56977718-1fa5-4beb-9791-f8b41587b568",
			["e8b1eab0-ef11-40a2-8a0b-cee8d062bf2a"] = "d416ea2a-a0a0-4686-66ab-eb8185d85782",
			["eaad98ec-026b-429e-aa24-8274dfd1ecb7"] = "b2c26f23-234f-44a0-ad89-424c6c114f00",
			["ebe18794-b5e1-41c4-befa-4b9d6922b0ec"] = "6c500449-8ec6-4173-7cb1-2c33d9585b25",
			["ede4778e-7602-440f-9075-b4bc8dc31cea"] = "3009aedd-412d-4b0b-46a0-4207b0d1810b",
			["f013d01b-3310-43f7-81bf-a51130442b5e"] = "655c4427-43a1-4bd0-939e-d4ed8c8c2cf6",
			["f87d7b0e-bc56-4f22-b347-9ef63bfa5220"] = "a40f1567-887e-4a12-78a1-044bece367ac",
			["fbb8347b-20e3-4846-ba91-0552cd12fc5f"] = "f58f5135-cc55-4935-f49b-e7aa3916e25c",
			["fe416267-36f0-4346-90fc-4aeb7f25ec07"] = "b16ef645-7d25-4a9c-e89f-93aec66ee47f",
			["ff4d9497-023c-434a-bd14-82fc367e991c"] = "b265a75b-ba5f-424c-889f-d2a7387c5035"
		}
	}
}

---@class PrepMarkerCategory
---@field name string
---@field description string?
---@field modId Guid?

---@type {[Guid]: PrepMarkerCategory}
ConfigurationStructure.config.mutations.prepPhaseMarkers = {
}

ConfigurationStructure.DynamicClassDefinitions.prepPhaseMarkers = {
	["a7e8e508-ee23-484d-ac49-67dfa78d2020"] = {
		name = "Boss",
		description = "Entities that are considered to be bosses (irrespective of their XPReward)",
	},
	["7bec1b31-0b70-445f-ae42-62ca8ac18ddc"] = {
		name = "MiniBoss",
		description = "Entities that are considered to be minibosses (irrespective of their XPReward)",
	},
	["0d0fea0e-6a01-42c2-bb76-efa6b41b9af8"] = { name = "Barbarian" },
	["bb06bab9-5b7d-4ec8-bc55-e4dd64afe74b"] = { name = "Bard" },
	["71efbd0c-10a6-41b8-9add-598eed11afc3"] = { name = "Cleric" },
	["6c3f19f2-6209-41ea-90d5-09978964378a"] = { name = "Druid" },
	["b0876cb8-ad50-42b8-affd-22c11349875e"] = { name = "Fighter" },
	["0f25fd8a-15c8-4a1a-b0f1-c435b9f78689"] = { name = "Monk" },
	["2910a1a8-ded1-4ead-a4fb-57c4f4918046"] = { name = "Paladin" },
	["f076b8a3-68b3-47e5-af20-ba93ecd1c1ad"] = { name = "Ranger" },
	["7293f1dc-b0a6-455d-975f-96b1e020fdb0"] = { name = "Rogue" },
	["94945836-3898-486b-95e1-2a62a07234a1"] = { name = "Sorcerer" },
	["f9d9b432-3671-4cfe-9187-92504bf2fbad"] = { name = "Wizard" },
	["fb2c85dd-12a4-43c1-9aae-5fe4f5230592"] = { name = "Warlock" },
}

---@alias ModDependencies {Guid : ModDependency}?

---@class ModDependency
ConfigurationStructure.DynamicClassDefinitions.modDependency = {
	---@type Guid
	modId = "",
	---@type integer[]
	modVersion = {},
	---@type string
	modAuthor = "",
	---@type string
	modName = "",
	---@type {string: string}
	packagedItems = {}
}

--#region Selectors
---@class Selector
ConfigurationStructure.DynamicClassDefinitions.selector = {
	inclusive = true,
	---@type string
	criteriaCategory = nil,
	criteriaValue = nil,
	---@type SelectorQuery
	subSelectors = {},
	---@type ModDependencies
	modDependencies = nil
}

---@alias SelectorGrouper "AND"|"OR"

---@alias SelectorQuery (SelectorGrouper|Selector)[]

--#endregion

--#region Mutators

---@class MutationModifier
ConfigurationStructure.DynamicClassDefinitions.modifier = {
	value = "",
	extraData = {}
}

---@class Mutator
ConfigurationStructure.DynamicClassDefinitions.mutator = {
	targetProperty = "",
	values = nil,
	---@type {[string]: MutationModifier}?
	modifiers = nil,
	---@type ModDependencies
	modDependencies = nil,
}

--#endregion

---@class Mutation
ConfigurationStructure.DynamicClassDefinitions.mutations = {
	name = "",
	description = "",
	---@type SelectorQuery
	selectors = {},
	---@type Mutator[]
	mutators = {},
	prepPhase = false,
	---@type string?
	modId = nil,
}

---@class MutationFolder
ConfigurationStructure.DynamicClassDefinitions.folders = {
	name = "",
	description = "",
	---@type {[Guid]: Mutation}
	mutations = {},
	---@type Guid?
	modId = nil
}

---@type {[Guid] : MutationFolder}
ConfigurationStructure.config.mutations.folders = {}

--#region Profiles

---@class MutationProfile
ConfigurationStructure.DynamicClassDefinitions.profile = {
	name = "",
	description = "",
	---@type MutationProfileRule[]
	mutationRules = {},
	---@type MutationProfileRule[]
	prepPhaseMutations = {},
	---@type Guid?
	modId = nil
}

---@class MutationProfileRule
ConfigurationStructure.DynamicClassDefinitions.profileMutationRule = {
	---@type Guid
	mutationFolderId = "",
	---@type Guid
	mutationId = "",
	---@type boolean
	additive = false,
	---@type ModDependency
	sourceMod = nil
}

---@type {[Guid]: MutationProfile}
ConfigurationStructure.config.mutations.profiles = {}
--#endregion

--#region Lists
---@class CustomListsSettings
ConfigurationStructure.config.mutations.settings.customLists = {
	subListColours = {
		guaranteed = { 0, 138, 172, 0.92 },
		randomized = { 124, 14, 43, 0 },
		startOfCombatOnly = { 217, 118, 6, 0.8 },
		onLoadOnly = { 217, 179, 6, 0.8 },
		blackListed = { 0.99, 0.96, 0.96, 0.80 },
		onDeathOnly = { 0.51, 0.24, 0.75, 1.0 },
	},
	autoCollapseFoldersSection = false,
	---@type "Icon"|"Text"
	iconOrText = "Icon",
	showSeperatorsInMain = true,
	defaultPool = {
		spellLists = "randomized",
		passiveLists = "guaranteed",
		statusLists = "guaranteed"
	},
	savedSpellListSpreads = {
		spellLists   = {
			["Default"] = {
				[1] = 2,
				[3] = 0,
				[5] = 1,
				[7] = 0,
				[10] = 1
			}
		},
		passiveLists = {
			["Default"] = {
				[1] = 1
			}
		},
		statusLists  = {
			["Default"] = {
				[1] = 1
			}
		}
	}
}

---@class AbilityPriorities
---@field primaryStat AbilityId
---@field secondaryStat AbilityId
---@field tertiaryStat AbilityId
---@field quaternary AbilityId
---@field quinary AbilityId
---@field senary AbilityId

---@class SpellList : CustomList
---@field abilityPriorities AbilityPriorities

---@alias EntryName string

---@class CustomSubList
ConfigurationStructure.DynamicClassDefinitions.customSubList = {
	---@type EntryName[]?
	guaranteed = nil,
	---@type EntryName[]?
	randomized = nil,
	---@type EntryName[]?
	startOfCombatOnly = nil,
	---@type EntryName[]?
	onLoadOnly = nil,
	---@type EntryName[]?
	blackListed = nil,
	---@type EntryName[]?
	onDeathOnly = nil
}

---@class LeveledSubList
---@field linkedProgressions {[Guid]: CustomSubList}?
---@field manuallySelectedEntries CustomSubList

---@class CustomList
ConfigurationStructure.DynamicClassDefinitions.customLeveledList = {
	name = "",
	description = "",
	---@type Guid?
	modId = nil,
	---@type (LeveledSubList[]|{[GameLevel] : LeveledSubList})?
	levels = nil,
	---@type Guid[]
	linkedProgressionTableIds = {},
	---@type Guid[]
	linkedLists = {},
	---@type Guid[]?
	spellListDependencies = nil,
	---@type ModDependencies
	modDependencies = nil,
	useGameLevel = false,
	---@type string?
	defaultPool = nil,
	blacklistSameEntriesInHigherProgressionLevels = true
}

---@class MutationLists
ConfigurationStructure.config.mutations.lists = {
	---@class EntryReplacerDictionary
	entryReplacerDictionary = {
		---@type {[string]: string[]}
		spellLists = {},
		---@type {[string]: string[]}
		passiveLists = {},
		---@type {[string]: string[]}
		statusLists = {},
		---@type ModDependencies
		modDependencies = nil,
	},
	---@type {[Guid]: SpellList}
	spellLists = {},
	---@type {[Guid]: CustomList}
	passiveLists = {},
	---@type {[Guid]: CustomList}
	statusLists = {}
}

--#endregion
