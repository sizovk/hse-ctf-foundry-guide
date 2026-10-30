// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IOracle {
    function getPrice() external view returns (uint256);
}

contract CollateralToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Collateral Token", "COLLAT") {
        _mint(msg.sender, initialSupply);
    }
}

contract DebtToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Debt Token", "DEBT") {
        _mint(msg.sender, initialSupply);
    }
}

contract Lending {
    IERC20  public immutable collateralToken;
    IERC20  public immutable debtToken;
    IOracle public immutable oracle;

    uint256 public constant LIQUIDATION_THRESHOLD  = 0.8e18;
    uint256 public constant LIQUIDATION_BONUS      = 0.05e18;
    uint256 public constant PRECISION              = 1e18;

    mapping(address => uint256) public collateralDeposited;
    mapping(address => uint256) public debtBorrowed;

    constructor(address _collateralToken, address _debtToken, address _oracle) {
        collateralToken = IERC20(_collateralToken);
        debtToken       = IERC20(_debtToken);
        oracle          = IOracle(_oracle);
    }


    function deposit(uint256 amount) external {
        require(amount > 0, "amount = 0");
        collateralDeposited[msg.sender] += amount;
        collateralToken.transferFrom(msg.sender, address(this), amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "amount = 0");
        uint256 newDebt = debtBorrowed[msg.sender] + amount;
        debtBorrowed[msg.sender] = newDebt;

        require(
            _isHealthy(newDebt, collateralDeposited[msg.sender]),
            "undercollateralized"
        );

        debtToken.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "amount = 0");
        uint256 currentDebt = debtBorrowed[msg.sender];
        require(amount <= currentDebt, "repay > debt");

        debtBorrowed[msg.sender] = currentDebt - amount;
        debtToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "amount = 0");
        uint256 newCollateral = collateralDeposited[msg.sender] - amount;

        require(
            debtBorrowed[msg.sender] == 0 ||
            _isHealthy(debtBorrowed[msg.sender], newCollateral),
            "undercollateralized"
        );

        collateralDeposited[msg.sender] = newCollateral;
        collateralToken.transfer(msg.sender, amount);
    }

    function liquidate(address user, uint256 debtAmount) external {
        require(debtAmount > 0, "debtAmount = 0");
        require(user != msg.sender, "self-liquidation");

        uint256 userDebt   = debtBorrowed[user];
        uint256 userCollat = collateralDeposited[user];
        require(userDebt > 0, "no debt");
        require(debtAmount <= userDebt, "debtAmount > debt");

        uint256 price = oracle.getPrice();

        require(
            userCollat * price * LIQUIDATION_THRESHOLD / PRECISION < userDebt * PRECISION,
            "position healthy"
        );

        uint256 seizeCollateral = debtAmount * (PRECISION + LIQUIDATION_BONUS) / price;
        if (seizeCollateral > userCollat) {
            seizeCollateral = userCollat;
        }

        debtBorrowed[user]        = userDebt - debtAmount;
        collateralDeposited[user] = userCollat - seizeCollateral;

        debtToken.transferFrom(msg.sender, address(this), debtAmount);
        collateralToken.transfer(msg.sender, seizeCollateral);
    }

    function _isHealthy(uint256 debt, uint256 collat) private view returns (bool) {
        if (debt == 0) return true;
        uint256 price = oracle.getPrice();
        return (collat * price * LIQUIDATION_THRESHOLD / PRECISION) >= (debt * PRECISION);
    }
}