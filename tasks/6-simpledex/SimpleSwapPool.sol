// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../helpers/LibsSimpleSwap/IERC20.sol";
import "../helpers/LibsSimpleSwap/SafeERC20.sol";
import "../helpers/LibsSimpleSwap/Math.sol";

library SimpleSwapLibrary {
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "SimpleSwapLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleSwapLibrary: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "SimpleSwapLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "SimpleSwapLibrary: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
}

contract ERC20 is IERC20 {
    string public constant name = "SimpleSwap";
    string public constant symbol = "SSW";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {}

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value;
        totalSupply = totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        }
        _transfer(from, to, value);
        return true;
    }
}

contract SimpleSwapPool is ERC20 {
    using SafeERC20 for IERC20;

    address public token;
    address public factory;
    bool isSetup;

    event Sync(uint256 reserve0, uint256 reserve1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "txn expired");
        _;
    }

    constructor() {}

    // for uniswap compatibility
    function token0() external pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function token1() external view returns (address) {
        return token;
    }

    function reserve0() external view returns (uint256) {
        return address(this).balance;
    }

    function reserve1() external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getReserves() external view returns (uint256, uint256, uint256) {
        return (address(this).balance, IERC20(token).balanceOf(address(this)), block.timestamp);
    }
    // end

    function setup(address _token) external {
        require(!isSetup, "Already Setup");
        isSetup = true;
        token = _token;
        factory = msg.sender;
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, "ETH transfer failed");
    }

    // Swap Functions ->
    function swapExactETHForTokens(uint256 _tokenAmountMin, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
        returns (uint256 _tokenAmount)
    {
        IERC20 _token_inter = IERC20(token);
        uint256 reserveEth = address(this).balance - msg.value;
        uint256 reserveToken = _token_inter.balanceOf(address(this));

        _tokenAmount = SimpleSwapLibrary.getAmountOut(msg.value, reserveEth, reserveToken);
        require(_tokenAmountMin <= _tokenAmount, "slippage issue");
        _token_inter.safeTransfer(to, _tokenAmount);

        emit Swap(msg.sender, msg.value, 0, 0, _tokenAmount, to);
        emit Sync(reserveEth + msg.value, reserveToken - _tokenAmount);
    }

    function swapETHForExactTokens(uint256 _tokenAmount, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
        returns (uint256 _ethAmount)
    {
        IERC20 _token_inter = IERC20(token);
        uint256 reserveEth = address(this).balance - msg.value;
        uint256 reserveToken = _token_inter.balanceOf(address(this));

        _ethAmount = SimpleSwapLibrary.getAmountIn(_tokenAmount, reserveEth, reserveToken);
        require(_ethAmount <= msg.value, "slippage issue");
        _token_inter.safeTransfer(to, _tokenAmount);

        if (msg.value > _ethAmount) {
            safeTransferETH(msg.sender, msg.value - _ethAmount);
        }

        emit Swap(msg.sender, _ethAmount, 0, 0, _tokenAmount, to);
        emit Sync(reserveEth + _ethAmount, reserveToken - _tokenAmount);
    }

    function swapExactTokensForETH(uint256 _tokenAmount, uint256 _ethAmountMin, address to, uint256 deadline)
        external
        ensure(deadline)
        returns (uint256 _ethAmount)
    {
        IERC20 _token_inter = IERC20(token);
        uint256 reserveEth = address(this).balance;
        uint256 reserveToken = _token_inter.balanceOf(address(this));

        _ethAmount = SimpleSwapLibrary.getAmountOut(_tokenAmount, reserveToken, reserveEth);
        require(_ethAmountMin <= _ethAmount, "slippage issue");
        _token_inter.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        safeTransferETH(to, _ethAmount);

        emit Swap(msg.sender, 0, _tokenAmount, _ethAmount, 0, to);
        emit Sync(reserveEth - _ethAmount, reserveToken + _tokenAmount);
    }

    function swapTokensForExactETH(uint256 _ethAmount, uint256 _tokenAmountMax, address to, uint256 deadline)
        external
        ensure(deadline)
        returns (uint256 _tokenAmount)
    {
        IERC20 _token_inter = IERC20(token);
        uint256 reserveEth = address(this).balance;
        uint256 reserveToken = _token_inter.balanceOf(address(this));

        _tokenAmount = SimpleSwapLibrary.getAmountIn(_ethAmount, reserveToken, reserveEth);
        require(_tokenAmount <= _tokenAmountMax, "slippage issue");
        _token_inter.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        safeTransferETH(to, _ethAmount);

        emit Swap(msg.sender, 0, _tokenAmount, _ethAmount, 0, to);
        emit Sync(reserveEth - _ethAmount, reserveToken + _tokenAmount);
    }

    // add Liquidity ->
    function _addLiquidityETHinternal(uint256 _tokenAmountMin, uint256 _tokenAmountMax, address from, address to)
        internal
        returns (uint256 liquidity)
    {
        require(msg.value > 0 && _tokenAmountMin > 0, "invalid amounts");
        uint256 _ethAmount = msg.value;
        IERC20 _token_inter = IERC20(token);

        uint256 reserveEth = address(this).balance - msg.value;
        uint256 reserveToken = _token_inter.balanceOf(address(this));
        uint256 _totalSupply = totalSupply;

        uint256 _tokenAmount;
        if (_totalSupply > 0) {
            _tokenAmount = msg.value * reserveToken / reserveEth;
            require(_tokenAmount >= _tokenAmountMin, "wrong token ratio");
            require(_tokenAmount <= _tokenAmountMax, "wrong token ratio");
        } else {
            _tokenAmount = _tokenAmountMin;
        }

        _token_inter.safeTransferFrom(from, address(this), _tokenAmount);

        require(
            reserveToken == _token_inter.balanceOf(address(this)) - _tokenAmount, "deflationary tokens not supported"
        );

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(_ethAmount * _tokenAmount) - 10 ** 3;
            _mint(address(0), 10 ** 3);
        } else {
            liquidity = Math.min(_ethAmount * _totalSupply / reserveEth, _tokenAmount * _totalSupply / reserveToken);
        }
        require(liquidity > 0, "liquidity mint issue");

        uint256 _fee = SimpleSwapFactory(factory).fee();
        if (_fee > 0) {
            uint256 _feeAmount = liquidity * _fee / 10 ** 5;
            _mint(SimpleSwapFactory(factory).protocolManager(), _feeAmount);
            liquidity = liquidity - _feeAmount;
        }

        _mint(to, liquidity);

        emit Mint(from, _ethAmount, _tokenAmount);
    }

    function addLiquidityETHonCreate(
        uint256 _tokenAmountMin,
        uint256 _tokenAmountMax,
        address from,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 liquidity) {
        require(msg.sender == factory, "dont be so smart");
        liquidity = _addLiquidityETHinternal(_tokenAmountMin, _tokenAmountMax, from, to);
    }

    function addLiquidityETH(uint256 _tokenAmountMin, uint256 _tokenAmountMax, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
        returns (uint256 liquidity)
    {
        liquidity = _addLiquidityETHinternal(_tokenAmountMin, _tokenAmountMax, msg.sender, to);
    }

    function removeLiquidity(uint256 liquidity, address to, uint256 deadline)
        external
        ensure(deadline)
        returns (uint256 _ethAmount, uint256 _tokenAmount)
    {
        require(liquidity > 0, "no liquidity");
        IERC20 _token_inter = IERC20(token);

        uint256 reserveEth = address(this).balance;
        uint256 reserveToken = _token_inter.balanceOf(address(this));

        uint256 _totalSupply = totalSupply;
        _ethAmount = liquidity * reserveEth / _totalSupply;
        _tokenAmount = liquidity * reserveToken / _totalSupply;
        require(_ethAmount > 0 && _tokenAmount > 0, "liquidity burn issue");

        _burn(msg.sender, liquidity);

        _token_inter.safeTransfer(to, _tokenAmount);
        safeTransferETH(to, _ethAmount);

        emit Burn(msg.sender, _ethAmount, _tokenAmount, to);
    }

    function rescueTokens(address _token, address to) external {
        require(msg.sender == factory, "dont be so smart");
        require(_token != token, "can't rescue base token");
        IERC20(_token).safeTransfer(to, IERC20(_token).balanceOf(address(this)));
    }

    function isSolved(address player) external view returns (bool) {
        uint256 newK = IERC20(token).balanceOf(address(this)) * address(this).balance;
        uint256 initialK = 100e18 * 0.1 ether;
        return newK < (initialK / 2) && IERC20(token).balanceOf(player) > 100e18 * 1.5;
    }
}

contract SimpleSwapFactory {
    uint256 public fee;
    address public pairCodeAddress;
    address public protocolManager;

    mapping(address => address) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token, address pair, uint256);
    event protocolManagerChanged(address indexed previousManager, address indexed newManager);
    event feeUpdated(uint256 previousFee, uint256 newFee);

    modifier onlyOwner() {
        require(protocolManager == msg.sender, "no access");
        _;
    }

    constructor() {
        protocolManager = msg.sender;
        SimpleSwapPool pairContract = new SimpleSwapPool();
        pairCodeAddress = address(pairContract);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address token) public returns (address pair) {
        require(token != address(0), "zero address");
        require(getPair[token] == address(0), "pair already created");

        address payable _proxyAddress;
        bytes20 targetBytes = bytes20(pairCodeAddress);
        bytes32 salt = keccak256(abi.encodePacked(token));

        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            _proxyAddress := create2(0, clone, 0x37, salt)
        }

        pair = address(_proxyAddress);
        SimpleSwapPool(pair).setup(token);

        getPair[token] = pair;
        allPairs.push(pair);
        emit PairCreated(token, pair, allPairs.length);
    }

    function createPairWithAddLiquidityETH(
        address token,
        uint256 _tokenAmountMin,
        uint256 _tokenAmountMax,
        address to,
        uint256 deadline
    ) external payable returns (address pair, uint256 liquidity) {
        pair = getPair[token];
        if (pair == address(0)) pair = createPair(token);
        liquidity = SimpleSwapPool(pair).addLiquidityETHonCreate{value: msg.value}(
            _tokenAmountMin, _tokenAmountMax, msg.sender, to, deadline
        );
    }

    function changeFee(uint256 _fee) external onlyOwner {
        require(_fee < 10000, "invalid fee");
        emit feeUpdated(fee, _fee);
        fee = _fee;
    }

    function changeProtocolManager(address _protocolManager) external onlyOwner {
        require(_protocolManager != address(0), "zero address");
        emit protocolManagerChanged(protocolManager, _protocolManager);
        protocolManager = _protocolManager;
    }

    function rescueTokens(address token, address to) external onlyOwner {
        require(token != address(0), "zero address");
        require(token != to, "to / token issue");
        require(IERC20(token).transfer(to, IERC20(token).balanceOf(address(this))), "can't process");
    }

    function rescueTokensFromPool(address pool, address token, address to) external onlyOwner {
        require(pool != address(0), "zero address");
        require(token != address(0), "zero address");
        require(token != to, "to / token issue");
        SimpleSwapPool(pool).rescueTokens(token, to);
    }
}
