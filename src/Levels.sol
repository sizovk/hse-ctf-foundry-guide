// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Адреса фабрик уровней на Sepolia (индекс == номер уровня).
library Levels {
    function addresses() internal pure returns (address[8] memory a) {
        a[0] = 0x6eeF64Ac1C4E468250A6b5a50b24eB1469546350;
        a[1] = 0x8036A15695736649fC408DE22189dc146F755f67;
        a[2] = 0x4B5a713bE21d95f1cdbC1175E04888996D766832;
        a[3] = 0x318cDdb9122818fd3cb7ea8256aE8176664ce368;
        a[4] = 0x7365D5e9287832415751ea6d26b27152184CC6b8;
        a[5] = 0x6EFE7EF8EDcaBc41077EAa118384a75B1a811A62;
        a[6] = 0x8dA64940124B012d167ba59C1824975793794A2b;
        a[7] = 0x799e180a8909F4A74608918CC556Cb90FA3bE979;
    }

    function names() internal pure returns (string[8] memory n) {
        n[0] = "Hello";
        n[1] = "Setter";
        n[2] = "ScamVault";
        n[3] = "QuickLoan";
        n[4] = "Arbitrage";
        n[5] = "Liquidate";
        n[6] = "SimpleDex";
        n[7] = "Manipulending";
    }
}
