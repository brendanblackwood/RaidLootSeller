# <RLS> RaidLootSeller

Heavily borrowed from [RaidLootRoller](https://www.curseforge.com/wow/addons/raidlootroller)

Addon for managing auctioning off items in a raid. I wrote this to help my guild with sale runs where buyers have the option to buy loot that drops for gulid members.

## Usage
Type `/rls` to see configuration options. Once you are ready to sell, just have your raid or party member **whisper you** the word "sell" then the item they want to put up for acution. For example:

    sell [Sunfury Bow of the Phoenix]

The item will be put up for auction for 20 seconds (configurable).
Buyers can then whisper the amount they want to bid. If the bid is higher than the current bid, it will be accepted and become the new bid. Bids may come in either long or short form: `40000`, `40k`, `4m`

## Features
- Ability to queue up multiple items for sale.
- Notify loot owner who won the item via whisper and in party/raid chat.
- Ability to set a starting price by item type.
- Ability to set minimum bidding increments.

## Optional Features
- Ability for group leaders/assistants to monitor party/raid/instance chat for "sell [item]" messages.
- Ability for group leaders/assistants to have instructions automatically posted in chat after the end of each encounter.