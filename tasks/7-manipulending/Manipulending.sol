// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transferOwner(address recipient) external;

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract ERC20 is IERC20 {
    
    uint public override totalSupply;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    address private owner;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    function transferOwner(address recipient) public override {
        require(msg.sender == owner || owner == address(0));
        owner = recipient;
    }

    function transfer(address recipient, uint amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(address account, uint amount) external virtual {
        require(msg.sender == owner);
        _mint(account, amount);
    }

    function _mint(address account, uint amount) internal {
        balanceOf[account] += amount;
        totalSupply += amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint amount) external virtual {
        require(msg.sender == owner);
        _burn(account, amount);
    }

    function _burn(address account, uint amount) internal {
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}


contract Manipulending {

    ERC20  public collateralToken;
    ERC20 public borrowToken;
    Pair public pair;

    mapping(address => uint256) public usersCollateral;
    mapping(address => uint256) public usersUsedCollateral;
    mapping(address => uint256) public usersBorrowed;

    constructor(Pair _pair, ERC20 _collateralToken, ERC20 _borrowToken) {
        collateralToken = _collateralToken;
        pair = _pair;
        borrowToken = _borrowToken;
    }

    function addCollateral(uint256 amount) external {
        collateralToken.transferFrom(msg.sender, address(this), amount);
        usersCollateral[msg.sender] += amount;
    }

    function removeCollateral(uint256 amount) external {
        require(usersBorrowed[msg.sender] == 0, "You have debt");
        require(usersCollateral[msg.sender] >= amount, "Not enough collateral");
        collateralToken.transfer(msg.sender, amount);
        usersCollateral[msg.sender] -= amount;
    }


    function borrow(uint256 _amount) external {
        uint256 needCollateral = _amount * getExchangeRate() * 4;

        require(needCollateral <= usersCollateral[msg.sender], "You don't have enough collateral");

        borrowToken.transfer(msg.sender, _amount);
        usersUsedCollateral[msg.sender] += needCollateral;
        usersCollateral[msg.sender] -= needCollateral;
        usersBorrowed[msg.sender] += _amount;

    }

    function repay(uint256 _amount) external {
        uint256 collateral = (usersUsedCollateral[msg.sender] * _amount) / usersBorrowed[msg.sender];

        borrowToken.transferFrom(msg.sender, address(this), _amount);

        usersUsedCollateral[msg.sender] -= collateral;
        usersCollateral[msg.sender] += collateral;
        usersBorrowed[msg.sender] -= _amount; 
    }

    function getExchangeRate() public view returns (uint256) {
        return pair.getSpotPrice();
    }

    function isSolved() external view returns (bool) {
        return borrowToken.balanceOf(address(this)) == 0;
    }
}

contract Pair is ERC20 {

    using Math for uint256;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    bool private locked;

    modifier lock() {
        require(!locked, "Locked!");
        locked = true;
        _;
        locked = false;
    }


    function getReserves()
        public
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1
        )
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function getSpotPrice() external view returns (uint256) {
        return reserve1 / reserve0;
    }

    constructor() ERC20("ST", "ST") {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) public {
        require(msg.sender == factory, "FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function _update(
        uint balance0,
        uint balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "OVERFLOW"
        );

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function mint(address to) external lock returns(uint liquidity) {
        require(msg.sender == factory, "FORBIDDEN");
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        _update(balance0, balance1, uint112(balance0), uint112(balance1));
    }


    function swap(
        uint amountIn,
        uint amountOutMin,
        bool isZeroToOne,
        address to
    ) external {

        uint amountOut = getAmountOut(amountIn, isZeroToOne);
        require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");

        address inputToken = isZeroToOne ? token0 : token1;
        ERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);

        if (isZeroToOne) {
            _swap(0, amountOut, to);
        } else {
            _swap(amountOut, 0, to);
        }

    }

    function _swap(
        uint amount0Out,
        uint amount1Out,
        address to
    ) private lock {
        require(
            amount0Out > 0 || amount1Out > 0,
            "INSUFFICIENT_OUTPUT_AMOUNT"
        );
        (uint112 _reserve0, uint112 _reserve1) = getReserves(); // gas savings
        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "INSUFFICIENT_LIQUIDITY"
        );

        uint balance0;
        uint balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out
            ? balance1 - (_reserve1 - amount1Out)
            : 0;
        require(
            amount0In > 0 || amount1In > 0,
            "INSUFFICIENT_INPUT_AMOUNT"
        );
        
        _reserve0 = uint112(balance0);
        _reserve1 = uint112(balance1);
        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function getAmountOut(uint amountIn, bool isZeroToOne) public returns (uint256 amountOut) {

        uint reserveIn;
        uint reserveOut;

        if (isZeroToOne) {
            (reserveIn, reserveOut) = getReserves();
        } else {
            (reserveOut, reserveIn) = getReserves();
        }

        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        uint numerator = amountIn * reserveOut;
        uint denominator = reserveIn + amountIn;

        amountOut = numerator.ceilDiv(denominator);
    }
 

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FAILED"
        );
    }


}