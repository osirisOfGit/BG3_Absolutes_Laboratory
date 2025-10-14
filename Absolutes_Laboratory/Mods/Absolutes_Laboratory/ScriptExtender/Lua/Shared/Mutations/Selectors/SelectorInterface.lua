---@class SelectorInterface
SelectorInterface = {
	name = "",
	---@type {[string]: SelectorInterface}
	registeredSelectors = {},
	topic = "Mutations",
	subTopic = "Selectors"
}

---@param name string
---@return SelectorInterface instance
function SelectorInterface:new(name)
	local instance = { name = name }

	setmetatable(instance, self)
	self.__index = self

	SelectorInterface.registeredSelectors[name] = instance

	return instance
end

---@param parent ExtuiTreeParent
---@param existingSelector Selector?
function SelectorInterface:renderSelector(parent, existingSelector) end

---@param export MutationsConfig
---@param selector Selector
---@param removeMissingDependencies boolean?
function SelectorInterface:handleDependencies(export, selector, removeMissingDependencies)
	self.registeredSelectors[selector.criteriaCategory]:handleDependencies(export, selector, removeMissingDependencies)
	if selector.subSelectors then
		for _, subSelector in pairs(selector.subSelectors) do
			if type(subSelector) == "table" then
				---@cast subSelector Selector
				self:handleDependencies(export, subSelector, removeMissingDependencies)
			end
		end
	end
end

---@class SelectorPredicate
SelectorPredicate = {
	---@type fun(entity: (EntityHandle|EntityRecord), entityVar: MutatorEntityVar?): boolean
	func = nil
}

---@param func fun(entity: EntityHandle|EntityRecord): boolean
---@return SelectorPredicate instance
function SelectorPredicate:new(func)
	local instance = { func = func }

	setmetatable(instance, self)
	self.__index = self

	return instance
end

---@param entity EntityHandle|EntityRecord
---@param entityVar MutatorEntityVar?
---@return boolean
function SelectorPredicate:Test(entity, entityVar)
	return self.func(entity, entityVar)
end

---@param f1 SelectorPredicate
---@param f2 SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate.And(f1, f2)
	return SelectorPredicate:new(function(entity, entityVar)
		return f1:Test(entity, entityVar) and f2:Test(entity, entityVar)
	end)
end

---@param f1 SelectorPredicate
---@param f2 SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate.Or(f1, f2)
	return SelectorPredicate:new(function(entity, entityVar)
		return f1:Test(entity, entityVar) or f2:Test(entity, entityVar)
	end)
end

---@param f SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate.Negate(f)
	return SelectorPredicate:new(function(entity, entityVar)
		return not f:Test(entity, entityVar)
	end)
end

---@param selector Selector
---@return fun(entity: (EntityHandle|EntityRecord)): boolean
function SelectorInterface:predicate(selector) end

---@param selectorQuery SelectorQuery
---@return SelectorPredicate
function SelectorInterface:createComposedPredicate(selectorQuery)
	---@type SelectorPredicate
	local predicate

	---@type SelectorPredicate
	local predicateGroup

	local currentOperation = "AND"
	for _, selector in ipairs(selectorQuery) do
		if type(selector) == "string" then
			if not predicate then
				predicate = predicateGroup
			elseif currentOperation == "AND" then
				predicate = predicate:And(predicateGroup)
			else
				predicate = predicate:Or(predicateGroup)
			end

			predicateGroup = nil
			currentOperation = selector
		else
			---@type SelectorInterface
			local selectorImpl = self.registeredSelectors[selector.criteriaCategory]
			---@type SelectorPredicate
			local selectorPred = SelectorPredicate:new(selectorImpl:predicate(selector))

			if next(selector.subSelectors) then
				selectorPred = selectorPred:And(self:createComposedPredicate(selector.subSelectors))
			end

			if not selector.inclusive then
				selectorPred = selectorPred:Negate()
			end

			if not predicateGroup then
				predicateGroup = selectorPred
			elseif currentOperation == "AND" then
				predicateGroup = predicateGroup:And(selectorPred)
			else
				predicateGroup = predicateGroup:Or(selectorPred)
			end
		end
	end

	if predicateGroup then
		if not predicate then
			predicate = predicateGroup
		elseif currentOperation == "AND" then
			predicate = predicate:And(predicateGroup)
		else
			predicate = predicate:Or(predicateGroup)
		end
	end

	return predicate
end

Ext.Require("Shared/Mutations/Selectors/EntitySelector.lua")
Ext.Require("Shared/Mutations/Selectors/FactionSelector.lua")
Ext.Require("Shared/Mutations/Selectors/GameLevelSelector.lua")
Ext.Require("Shared/Mutations/Selectors/PassiveSelector.lua")
Ext.Require("Shared/Mutations/Selectors/PrepMarkerSelector.lua")
Ext.Require("Shared/Mutations/Selectors/RaceSelector.lua")
Ext.Require("Shared/Mutations/Selectors/StatSelector.lua")
Ext.Require("Shared/Mutations/Selectors/SizeSelector.lua")
Ext.Require("Shared/Mutations/Selectors/TagSelector.lua")
Ext.Require("Shared/Mutations/Selectors/TemplateSelector.lua")
Ext.Require("Shared/Mutations/Selectors/XPRewardSelector.lua")

---@param existingSlides MazzleDocsSlide[]?
---@return MazzleDocsSlide[]?
function SelectorInterface:generateDocs(existingSlides)
	if not existingSlides then
		return
	end

	table.insert(existingSlides, {
		Topic = self.topic,
		SubTopic = self.subTopic,
		content = {
			{
				type = "Heading",
				text = "Selectors"
			},
			{
				type = "CallOut",
				prefix = "Preconditions:",
				text =
				"You MUST run the Scan tool in the Inspector for the Dry Run to work. This needs to be re-run when adding/updating/removing new encounter mods or a new recorder property is added. You should do this on a brand new campaign to avoid any complications from teleporting to all levels on existing ones"
			},
			{
				type = "CallOut",
				prefix = "General Rules:",
				prefix_color = "Yellow",
				text = [[
- If a selector option has multiple checkboxes, like Race, and none of those checkboxes are selected, Lab will check if the entity is that parent value or is a child of that parent (for example, setting a Humanoid Race Selector will find all Humanoids and all subraces of Humanoid)
- Selectors are processed in the order defined - groups are formed at each AND/OR Boundary]]
			} --[[@as MazzleDocsCallOut]],
			{
				type = "Content",
				text = [[
The Dry Run button will preview the results of your selectors based on what was indexed by the Entity Scanner in the Inspector.

Let's start with the below:]]
			},
			{
				type = "Image",
				image_index = 6
			} --[[@as MazzleDocsImage]],
			{
				type = "Content",
				text = "This shows using a Nested Query - in DB Query Terms, this might look like:"
			},
			{
				type = "Code",
				text = [[
SELECT *
FROM ENTITIES
WHERE
(
	SIZE IS IN ('Tiny', 'Small')
	AND TEMPLATE IS IN ('BASE_Quadruped_Beast_Spider_Phase', 'FOR_PhaseSpider_Spawn', 'LOW_HouseOfGrief_Wildshape_Spider', ...)
	^^ Explanation of the additional templates below vv
)]]
			},
			{
				type = "Content",
				text = "if we were to uncheck the Inclusive checkbox from the Template selector (making it Exclusive), this would turn into:"
			},
			{
				type = "Code",
				text = [[
WHERE
(
	SIZE IS IN ('Tiny', 'Small')
	AND TEMPLATE IS NOT IN ('BASE_Quadruped_Beast_Spider_Phase', 'FOR_PhaseSpider_Spawn', 'LOW_HouseOfGrief_Wildshape_Spider', ...)
	^^ Explanation of the additional templates below vv
)]]
			},
			{
				type = "Image",
				image_index = 7
			} --[[@as MazzleDocsImage]],
			{
				type = "Content",
				text =
				"That checkbox you see next to the BASE Template is available for any resources that have children inheriting from them. Shift-click on the checkbox to see the hierarchy:"
			},
			{
				type = "Image",
				image_index = 8
			} --[[@as MazzleDocsImage]],
			{
				type = "Content",
				text =
				"For this Template, you can see there are quite a few child templates down to the great-grandchild level, so if the checkbox was unchecked those templates would be excluded from the query, turning it into:"
			},
			{
				type = "Code",
				text = [[
WHERE
(
	SIZE IS IN ('Tiny', 'Small')
	AND TEMPLATE IS IN ('BASE_Quadruped_Beast_Spider_Phase')
)]]
			},
			{
				type = "Content",
				text = "Finally, we can add another selector at the same level as the first:"
			},
			{
				type = "Image",
				image_index = 9
			} --[[@as MazzleDocsImage]],
			{
				type = "Content",
				text =
				"This adds an AND clause, specifying that entities much match the above criteria AND also be in level WLD_Main_A, turning the query into:"
			},
			{
				type = "Code",
				text = [[
SELECT *
FROM ENTITIES
WHERE
(
	(
		SIZE IS IN ('Tiny', 'Small')
		AND TEMPLATE IS IN ('BASE_Quadruped_Beast_Spider_Phase', 'FOR_PhaseSpider_Spawn', 'LOW_HouseOfGrief_Wildshape_Spider', ...)
	)
	AND
	(
		GAME_LEVEL IS IN ('WLD_Main_A')
	)
)]]
			},
			{
				type = "Content",
				text = "Choosing OR instead would have the expected effect - either the first or second 'clause' must match for the entity to be selected."
			}
		}
	} --[[@as MazzleDocsSlide]])

	table.insert(existingSlides, {
		Topic = self.topic,
		SubTopic = self.subTopic,
		content = {
			{
				type = "Heading",
				text = "Best Practices"
			},
			{
				type = "Note",
				text = "Due to the simplistic nature of Selectors, there likely won't be individual docs each one - instead, general good practices will be documented here"
			},
			{
				type = "SubHeading",
				text = "Build Your Mutations to be General -> Specific",
				size = "Large",
				color = "Orange"
			},
			{
				type = "Content",
				text = [[
Referring back to Profiles quickly, Mutations are ordered so that later mutators override earlier ones (with extra behavior for additive mutators), so it's generally best to start with wide-sweeping selectors in your top most mutations and end with hyper-specific ones at the end.

An example set of Selectors in separate Mutations would be:
1. All Spiders
2. All Small Spiders
3. All Large Spiders
4. All Phase Spiders
5. Spider Matriarch

This allows you to make general changes up top that cascade down, presuming different mutators are used (i.e. Level and Health Mutators in 1, Phase-specific Boost mutators in 4)
]]
			},
			{
				type = "SubHeading",
				text = "Use Nested Queries For Logical Grouping",
				size = "Large",
				color = "Orange"
			},
			{
				type = "Content",
				text = [[
Nested queries are a powerful tool (explained in the Selectors slide) that allow you (theoretically) infinite flexibility in how you structure you queries, ensuring they function correctly and cleanly in any use-case.

For example, say you wanted a mutation that targets all Cambions in TUT_Avernus_C. That's easy enough - a selector that just uses Race AND Game Level will do that.

But what if you wanted to target that same set OR all Fiends?
You could do that with a chain of AND/ORs:]]
			},
			{
				type = "Code",
				text = "Race: Cambions AND GameLevel: TUT_Avernus_C OR Race: Fiend"
			},
			{ type = "Content", text = "But that's pretty hard to read, right? Functionally it works because Lab forms a boundary every time the AND changes to OR (and vice-versa), so it's processed as:" },
			{ type = "Code",    text = "(Race: Cambions AND GameLevel: TUT_Avernus_C) OR (Race: Fiend)" },
			{ type = "Content", text = "However, this won't work if you wanted to find all Cambions that are in TUT_Avernus_C OR have the Miniboss XPReward category AND all Fiends that have the Boss XPReward, because that query now becomes:" },
			{ type = "Code",    text = "((Race: Cambions AND GameLevel: TUT_Avernus_C) OR XPReward: Miniboss OR Race: Fiend) AND (XPReward: Boss)" },
			{
				type = "Content",
				text = [[
Which means it'll pick up all Cambions in Avernus or all MiniBosses or all Fiends, all of which have to also have the Boss XPReward (only Raphael).

The way to clean it up and ensure boundaries are at the right places is to nest them:]]
			},
			{
				type = "Code",
				text = [[
- Race: Cambions
	|- GameLevel: TUT_Avernus_C
	OR
	|- XPReward: Miniboss
OR
- Race: Devils
	|- XPReward: Boss]]
			},
			{
				type = "Content",
				text = "Now this works because the query is:"
			},
			{
				type = "Code",
				text = "(Race: Cambions AND (GameLevel: TUT_Avernus_C OR XPReward: Miniboss)) OR (Race: Fiend AND XPReward: Boss)"
			},
			{
				type = "Content",
				text =
				"Now it's both correct and clean - this will scale as much as you need while remaining easy to read, and can easily be turned into Templates to reuse in other mutations (if it doesn't fit as a Prep Marker Selector)"
			},
			{
				type = "CallOut",
				prefix = "Ordering Selectors",
				prefix_color = "Green",
				text = [[
As somewhat illustrated above, how you order your Selectors within a single Mutation does matter when chaining selectors at the same level.

If you're not getting the results you want and know it's not a situation where you should be using Nested Queries, walk through your Selector chain the same way I did above, and if necessary, use the Orange up and/or down arrows underneath the Delete button next to each Selector to reorder them (this will preserve any nested children)]]
			} --[[@as MazzleDocsCallOut]],
		}
	} --[[@as MazzleDocsSlide]])

	for _, selector in TableUtils:OrderedPairs(self.registeredSelectors) do
		local docs = selector:generateDocs()
		if docs then
			for _, slide in ipairs(docs) do
				table.insert(existingSlides, slide)
			end
		end
	end

	local currentVer = ""
	for i, ver in ipairs(Ext.Mod.GetMod(ModuleUUID).Info.PublishVersion) do
		if i < 4 then
			currentVer = currentVer .. tostring(ver)
			if i < 3 then
				currentVer = currentVer .. "."
			end
		end
	end

	table.insert(existingSlides, {
		Topic = self.topic,
		SubTopic = self.subTopic,
		content = {
			{
				type = "Heading",
				text = "Changelog"
			}
		}
	} --[[@as MazzleDocsSlide]])

	for version, changelog in TableUtils:OrderedPairs(self:generateChangelog(), function(key, value)
		-- To Sort Descending Order
		local M, m, p = key:match("^(%d+)%.(%d+)%.(%d+)$")
		M, m, p = tonumber(M), tonumber(m), tonumber(p)
		return -1 * (M + m + p)
	end) do
		if version == currentVer then
			version = version .. " (Current)"
		end
		table.insert(existingSlides[#existingSlides].content, {
			type = "SubHeading",
			text = version
		} --[[@as MazzleDocsContentItem]])

		table.insert(existingSlides[#existingSlides].content, changelog)
	end

	return existingSlides
end

---@return {[string]: MazzleDocsContentItem}
function SelectorInterface:generateChangelog()
	return {
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Fixes a bug when deleting the first selector in a chain"
			}
		} --[[@as MazzleDocsContentItem]],
		["1.6.0"] = {
			type = "Bullet",
			text = {
				"Add static sizes to sidebar searches in selectors",
				"Add Size Selector (new Recorder Property)",
				"Fix Race selector when races have invalid parent guids",
				"Fixes Entities in the Selector with the same names causing IMGUI conflicts",
				"Doesn't search by entity id unless there are 36 characters",
				"Adds Up/Down Arrows to allow resorting",
				"Fix all selectors that use a search box so already selected items will render with a highlight",
				"Fix a bug that would break the selector list if you clicked on \"Add a Selector\", didn't choose anything, then clicked it again",
			}
		} --[[@as MazzleDocsContentItem]]
	}
end
