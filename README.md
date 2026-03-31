# Economy Dashboard

A modern, high-performance administrative dashboard for FiveM built with Vue 3, Chart.js, and `ox_lib`. This script provides server owners and admins with deep insights into the server's financial health, alongside powerful management tools.

## Features

  * **Multi-Framework Support**: Seamlessly integrates with QBCore, Qbox, and ESX out of the box.
  * **Economy Analytics**: Automatically logs and tracks total server wealth (Cash, Bank, Dirty Money) over time. Displays data on interactive 1D, 7D, and 30D charts.
  * **Advanced Character Database**: View a complete list of all characters sorted by total wealth. Search instantly by character name or identifiers (Discord, FiveM, Steam, License).
  * **Live Wealth Management**: Edit balances or completely wipe a character's cash, bank, and dirty money directly from the UI.
  * **Mugshot Integration**: Automatically captures player mugshots upon load (via `MugShotBase64`) and displays them in the dashboard.
  * **Dynamic Theming**: Change the UI accents and chart colors directly through `config.lua`—no need to rebuild the Vue NUI!
  * **Responsive Design**: The UI is built using viewport width (`vw`) units strictly scaled to a 2560x1440 baseline, ensuring perfect proportions on any resolution.

## Dependencies

  * [ox_lib](https://github.com/communityox/ox_lib)
  * [oxmysql](https://github.com/communityox/oxmysql)
  * [MugShotBase64](https://github.com/BaziForYou/MugShotBase64) (Optional, but highly recommended for UI avatars)

## Installation

1.  Ensure your server has the required dependencies installed and running.
2.  Place the resource folder (e.g., `perc-economy`) into your `resources` directory.
3.  Configure your permissions, update intervals, and colors in `config.lua`.
4.  Add `ensure perc-economy` to your `server.cfg`.

## Configuration

The dashboard is highly customizable via the `config.lua` file:

  * **Update Interval**: `update` defines how often (in minutes) the server calculates the global economy and logs a new data point to the history chart.
  * **Commands**: Change the default commands to open the panel (`epanel`) or force-refresh a player's mugshot (`erefresh`).
  * **Permissions**: Uses native FiveM ACE permissions. Define the groups (e.g., `group.admin`, `group.owner`) allowed to access the dashboard and use its commands.
  * **Colors**: Define RGB color strings to instantly re-theme the primary accents and chart datasets without editing CSS.

## Technical Details

#### Auto-Database Setup
You do not need to import any `.sql` files. Upon server start, the script will automatically create the `economy_history` table. It will also seamlessly inject `discord`, `fivem`, `steam`, and `mugshot` columns into your framework's `players` or `users` table if they do not already exist.

#### Performant Event Handling
The script entirely offloads permission checks to `ox_lib`'s server-side command registry (`lib.addCommand`). NUI actions utilize `lib.callback` to ensure secure, exploiter-proof money editing that doesn't rely on messy client-to-server event ping-ponging.

#### Identifier Tracking
To make searching the database easier for admins, the script natively extracts and updates player identifiers (Discord, FiveM, Steam) to the database every time a player loads into the server.

## Preview

A clean, responsive dashboard granting total control and oversight of your server's economy.
![External image](https://r2.fivemanage.com/vTtICY7I82AzRhxsoOZXb/perc-economy.png)