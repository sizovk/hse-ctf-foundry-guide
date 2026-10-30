# CTF на Sepolia через Foundry

Проходим задания CTF из консоли, без сайта. Нужен только [Foundry](https://getfoundry.sh):
утилиты `forge` и `cast` ([документация](https://book.getfoundry.sh),
[справочник cast](https://book.getfoundry.sh/reference/cast/)).

## Что происходит

Весь CTF это один контракт Ethernaut на Sepolia:

```
0x3c4D236Bf5A4cb000D386cf6d223Beb77fCcc8a1
```

Он хранит регистрации игроков, прогресс и очки. У каждого уровня есть своя фабрика
(отдельный контракт), которая создаёт вам персональный инстанс уровня и проверяет решение.

Сайт Ethernaut это просто веб-обёртка над этим контрактом: кнопки подписывают транзакции
в вашем кошельке. Напрямую вы шлёте те же самые транзакции через `cast`/`forge`. Для
контракта разницы нет, прогресс и очки одни и те же.

Любой уровень проходится тремя вызовами:

1. `register(nick)`, один раз на весь CTF.
2. `createLevelInstance(factory)`, создаёт ваш инстанс.
3. `submitLevelInstance(instance)`, фабрика проверяет решение и начисляет очки.

Между шагами 2 и 3 вы решаете инстанс, это и есть само задание.

## Настройка

```bash
forge install
cp .env.example .env # впишите SEPOLIA_RPC_URL и PRIVATE_KEY
forge build
```

Нужен кошелёк с небольшим балансом Sepolia ETH на газ.

## Действия

Регистрация:

```bash
cast send $ETHERNAUT "register(string)" "my_nick" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Создать инстанс уровня (адрес фабрики из таблицы ниже):

```bash
cast send $ETHERNAUT "createLevelInstance(address)" <factory> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Адрес вашего инстанса лежит в логе от контракта Ethernaut, в поле `data` (хвост после нулей):

```
"address":"0x3c4d236...", "data":"0x000000000000000000000000491e548d5f7e2720076e825e152e93810126a098"
                                    инстанс: 0x491e548d5f7e2720076e825e152e93810126a098
```

Удобнее открыть транзакцию на `sepolia.etherscan.io`, вкладка Logs.

Решить и засабмитить. Пример для Hello в [`script/HelloSolution.s.sol`](script/HelloSolution.s.sol),
копируйте его под свой уровень:

```bash
LEVEL=<factory> INSTANCE=<ваш инстанс> \
  forge script script/HelloSolution.s.sol:HelloSolution --rpc-url $SEPOLIA_RPC_URL --broadcast -vvv
```

Что попроще решается и вручную, вызовами `cast send` по инстансу, затем сабмит:

```bash
cast send $ETHERNAUT "submitLevelInstance(address)" <instance> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Очки и таблица лидеров:

```bash
forge script script/Scoreboard.s.sol:Scoreboard --rpc-url $SEPOLIA_RPC_URL -vvv
```

## Уровни

Условие и код каждого уровня лежат в `tasks/`. Адреса фабрик (они же в [`src/Levels.sol`](src/Levels.sol)):

| # | Уровень | Неделя | Баллы | Фабрика | Условие |
|---|---------|--------|-------|---------|---------|
| 0 | Hello         | 1 | 250 → 125  | `0x6eeF64Ac1C4E468250A6b5a50b24eB1469546350` | [tasks/0-hello](tasks/0-hello) |
| 1 | Setter        | 1 | 300 → 150  | `0x8036A15695736649fC408DE22189dc146F755f67` | [tasks/1-setter](tasks/1-setter) |
| 2 | ScamVault     | 2 | 500 → 250  | `0x4B5a713bE21d95f1cdbC1175E04888996D766832` | [tasks/2-scamvault](tasks/2-scamvault) |
| 3 | QuickLoan     | 2 | 500 → 250  | `0x318cDdb9122818fd3cb7ea8256aE8176664ce368` | [tasks/3-quickloan](tasks/3-quickloan) |
| 4 | Arbitrage     | 3 | 1000 → 500 | `0x7365D5e9287832415751ea6d26b27152184CC6b8` | [tasks/4-arbitrage](tasks/4-arbitrage) |
| 5 | Liquidate     | 3 | 1000 → 500 | `0x6EFE7EF8EDcaBc41077EAa118384a75B1a811A62` | [tasks/5-liquidate](tasks/5-liquidate) |
| 6 | SimpleDex     | 4 | 1500 → 750 | `0x8dA64940124B012d167ba59C1824975793794A2b` | [tasks/6-simpledex](tasks/6-simpledex) |
| 7 | Manipulending | 4 | 1500 → 750 | `0x799e180a8909F4A74608918CC556Cb90FA3bE979` | [tasks/7-manipulending](tasks/7-manipulending) |

SimpleDex при создании инстанса требует `--value 0.1ether`.
