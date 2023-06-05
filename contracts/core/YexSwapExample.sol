// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../libraries/ERC20.sol";
import "../libraries/AutomationCompatibleInterface.sol";
import "../libraries/Math.sol";
import "../interfaces/IYexSwapPool.sol";
import "../libraries/Console.sol";

contract ERC20WithFaucet is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    mapping(address => bool) public faucetedList;

    function faucet() public {
        require(!faucetedList[msg.sender], "fauceted");
        faucetedList[msg.sender] = true;
        _mint(msg.sender, 10 ** decimals());
    }
}

contract YexSwapPool is ERC20, IYexSwapPool {
    // Constant K value pool
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 reserveA;
    uint256 reserveB;

    /// @notice Possible remove status
    enum RmInstruction {
        RemoveBoth,
        RemoveTokenA,
        RemoveTokenB
    }

    constructor(
        string memory name,
        string memory symbol,
        address _tokenA,
        address _tokenB
    ) ERC20(name, symbol) {
        // feeTo = msg.sender;
        ERC20WithFaucet tokenA_ = ERC20WithFaucet(_tokenA);
        tokenA_.faucet();
        ERC20WithFaucet tokenB_ = ERC20WithFaucet(_tokenB);
        tokenB_.faucet();

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);

        _initLiquidity(
            tokenA.balanceOf(address(this)),
            tokenB.balanceOf(address(this))
        );
    }

    function mint(address to, uint256 amount) private {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) private {
        _burn(from, amount);
    }

    // Modifier to check token allowance
    modifier checkAllowance(uint256 amountA, uint256 amountB) {
        require(
            tokenA.allowance(msg.sender, address(this)) >= amountA,
            "Not allowance tokenA"
        );
        require(
            tokenB.allowance(msg.sender, address(this)) >= amountB,
            "Not allowance tokenB"
        );
        _;
    }

    function _initLiquidity(uint256 amountA, uint256 amountB) internal {
        require(
            amountA > 0 && amountB > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        uint256 lp_supply = totalSupply();
        require(lp_supply == 0, "pool has been initialized");
        reserveA = amountA;
        reserveB = amountB;
        console.log("pool %s init liquidity", name(), reserveA, reserveB);
        // mint to construtor
        mint(msg.sender, 10 ** 18);
    }

    // add liquidity, support add single side liquidity
    function addLiquidity(
        uint256 amountA,
        uint256 amountB
    ) external checkAllowance(amountA, amountB) {
        require(
            amountA > 0 || amountB > 0,
            "addLiquidity: INSUFFICIENT_INPUT_AMOUNT"
        );
        uint256 lp_supply = totalSupply();
        require(lp_supply > 0, "pool has not been initialized");

        uint256 amountLP = 0;

        if (amountA > 0) {
            uint256 _reserveA = reserveA;
            tokenA.transferFrom(msg.sender, address(this), amountA);
            amountLP +=
                (lp_supply * Math.sqrt((amountA + _reserveA) * _reserveA)) /
                _reserveA -
                lp_supply;
            lp_supply += amountLP;
            reserveA += amountA;
        }
        if (amountB > 0) {
            uint256 _reserveB = reserveB;
            tokenB.transferFrom(msg.sender, address(this), amountB);
            amountLP +=
                (lp_supply * Math.sqrt((amountB + _reserveB) * _reserveB)) /
                _reserveB -
                lp_supply;
            // lp_supply += amountLP; // do not used, can comment out
            reserveB += amountB;
        }
        console.log(
            "pool %s add liquidity current reserves %s %s",
            name(),
            reserveA,
            reserveB
        );
        mint(msg.sender, amountLP);
    }

    // Modifier to check token allowance
    modifier checkLPAllowance(uint256 amountLPB) {
        require(
            allowance(msg.sender, address(this)) >= amountLPB,
            "Not allowance LP token"
        );
        _;
    }

    // remove liquidity
    function removeLiquidity(
        uint256 amountLP,
        RmInstruction remove // checkLPAllowance(amountLP)
    ) external {
        require(amountLP > 0, "removeLiquidity: INSUFFICIENT_INPUT_AMOUNT");
        uint256 lp_supply = totalSupply();
        console.log(
            "remove liquidity,current lp %s remove lp %s ",
            lp_supply,
            amountLP
        );
        require(lp_supply > 0, "pool has not been initialized");
        //Validate: if this is correct meaning
        require(
            amountLP < lp_supply,
            "removeLiquidity: EXCEEDING_REMOVE_LIMIT"
        );
        burn(msg.sender, amountLP);
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;

        if (remove == RmInstruction.RemoveBoth) {
            tokenA.transfer(msg.sender, (amountLP * _reserveA) / lp_supply);
            tokenB.transfer(msg.sender, (amountLP * _reserveB) / lp_supply);
        } else if (remove == RmInstruction.RemoveTokenA) {
            uint256 amount = _reserveA -
                ((_reserveA *
                    ((lp_supply - amountLP) * (lp_supply - amountLP))) /
                    lp_supply /
                    lp_supply);
            tokenA.transfer(msg.sender, amount);
        } else if (remove == RmInstruction.RemoveTokenB) {
            uint256 amount = _reserveB -
                ((_reserveB *
                    ((lp_supply - amountLP) * (lp_supply - amountLP))) /
                    lp_supply /
                    lp_supply);
            tokenB.transfer(msg.sender, amount);
        }
    }

    function swap(
        uint256 amountA,
        uint256 amountB
    ) external override returns (uint256 amountAOut, uint256 amountBOut) {
        (amountAOut, amountBOut) = _swap(amountA, amountB);
    }

    function _swap(
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 amountAOut, uint256 amountBOut) {
        uint256 kValue = reserveA * reserveB;
        if (amountA > 0) {
            uint256 rb = reserveB;
            reserveA += amountA;
            reserveB = kValue / reserveA;

            amountBOut = rb - reserveB;
        } else {
            uint256 ra = reserveA;
            reserveB += amountB;
            reserveA = kValue / reserveB;

            amountAOut = ra - reserveA;
        }
    }

    /// @notice : maybe can do some gas savings
    function getReserves()
        public
        view
        override
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        _reserve0 = reserveA;
        _reserve1 = reserveB;
    }
}

contract YexSwapExample is YexSwapPool, AutomationCompatibleInterface {
    IYexSwapPool public pool1;
    IYexSwapPool public pool2;
    // record batch auction
    uint256 public batchid;
    mapping(uint256 => mapping(address => uint256)) tokenA_deposit;
    mapping(uint256 => address[]) tokenA_deposit_address;
    mapping(uint256 => mapping(address => uint256)) tokenB_deposit;
    mapping(uint256 => address[]) tokenB_deposit_address;

    // record every transaction volume for each batch of token A
    mapping(uint256 => uint256) public batch_tokenA;
    mapping(uint256 => uint256) public batch_tokenB;

    mapping(uint256 => uint256) batch_start_time;

    constructor(
        address _tokenA,
        address _tokenB
    ) YexSwapPool("Pool1", "P1", _tokenA, _tokenB) {
        // create inner pool to simulate a dex
        YexSwapPool pool2_ = new YexSwapPool("Pool2", "P2", _tokenA, _tokenB);

        pool1 = IYexSwapPool(address(this));
        pool2 = IYexSwapPool(address(pool2_));

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function deposit(
        uint256 amountA,
        uint256 amountB
    ) external checkAllowance(amountA, amountB) {
        require(
            amountA > 0 || amountB > 0,
            "deposit: INSUFFICIENT_INPUT_AMOUNT"
        );

        // setup new batch start time
        if (batch_start_time[batchid] == 0) {
            batch_start_time[batchid] = block.timestamp;
        }

        if (amountA > 0) {
            tokenA.transferFrom(msg.sender, address(this), amountA);

            // first deposit, add into deposit array
            if (tokenA_deposit[batchid][msg.sender] == 0) {
                tokenA_deposit_address[batchid].push(address(msg.sender));
            }

            tokenA_deposit[batchid][msg.sender] =
                tokenA_deposit[batchid][msg.sender] +
                amountA;

            batch_tokenA[batchid] = batch_tokenA[batchid] + amountA;
        }
        if (amountB > 0) {
            tokenB.transferFrom(msg.sender, address(this), amountB);

            // first deposit, add into deposit array
            if (tokenB_deposit[batchid][msg.sender] == 0) {
                tokenB_deposit_address[batchid].push(address(msg.sender));
            }

            tokenB_deposit[batchid][msg.sender] =
                tokenB_deposit[batchid][msg.sender] +
                amountB;

            batch_tokenB[batchid] = batch_tokenB[batchid] + amountB;
        }
        // emit Deposit(msg.sender, batchid, amountA, amountB);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded =
            (block.timestamp - batch_start_time[batchid]) > 10 &&
            (batch_tokenA[batchid] > 0 || batch_tokenB[batchid] > 0);
        performData = "";
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        require(
            (block.timestamp - batch_start_time[batchid]) > 10 &&
                (batch_tokenA[batchid] > 0 || batch_tokenB[batchid] > 0),
            "not need to perform"
        );
        // setup a new batch
        uint256 currentBatch = batchid;
        batchid += 1;
        // batch_start_time[batchid] = block.timestamp;
        //this is the same look up we are having with require statement. why do we need to duplicate?
        uint256 balanceA = batch_tokenA[currentBatch];
        uint256 balanceB = batch_tokenB[currentBatch];
        uint256 balanceA_ = balanceA;
        uint256 balanceB_ = balanceB;

        console.log(
            "before auction, balanceA:%s balanceB:%s",
            balanceA_,
            balanceB_
        );

        (
            uint256 min_reserveA,
            uint256 min_reserveB,
            IYexSwapPool min_pool,
            uint256 max_reserveA,
            uint256 max_reserveB,
            IYexSwapPool max_pool
        ) = _getCompareReserves();

        // 1. auction price is greater than maximum price
        if (((balanceB * max_reserveA)) > (max_reserveB * balanceA)) {
            uint256 delta;
            unchecked {
                delta = (balanceB - (balanceA * min_reserveB) / min_reserveA);
            }
            balanceB_ -= delta;
            // swap using the pool with the minimum price
            if (address(min_pool) == address(this)) {
                (delta, ) = _swap(0, delta);
            } else {
                (delta, ) = min_pool.swap(0, delta);
            }
            balanceA_ += delta;
        } else if (((balanceB * min_reserveA)) < (min_reserveB * balanceA)) {
            //2. auction price is less than minimum price
            uint256 delta;
            unchecked {
                delta = (balanceA - (balanceB * max_reserveA) / max_reserveB);
            }
            balanceA_ -= delta;
            // swap using the pool with the maximum price
            if (address(max_pool) == address(this)) {
                (, delta) = _swap(delta, 0);
            } else {
                (, delta) = max_pool.swap(delta, 0);
            }
            balanceB_ += delta;
        }

        console.log(
            "after auction, balanceA:%s balanceB:%s",
            balanceA_,
            balanceB_
        );

        // transfer tokenA to user who deposit tokenB
        for (
            uint256 i = 0;
            i < tokenB_deposit_address[currentBatch].length;
            i++
        ) {
            address user_addr = tokenB_deposit_address[currentBatch][i];
            uint256 deposit_amount = tokenB_deposit[currentBatch][user_addr];
            uint256 withdraw_amount = (deposit_amount * balanceA_) / balanceB;
            console.log(
                "transfer tokenA %s to user who deposit tokenB",
                withdraw_amount
            );
            tokenA.transfer(user_addr, withdraw_amount);
        }

        // transfer tokenB to user who deposit tokenA
        for (
            uint256 i = 0;
            i < tokenA_deposit_address[currentBatch].length;
            i++
        ) {
            address user_addr = tokenA_deposit_address[currentBatch][i];
            uint256 deposit_amount = tokenA_deposit[currentBatch][user_addr];
            uint256 withdraw_amount = (deposit_amount * balanceB_) / balanceA;
            console.log(
                "transfer tokenB %s to user who deposit tokenA",
                withdraw_amount
            );
            tokenB.transfer(user_addr, withdraw_amount);
        }
    }

    /// @notice need support more pools
    function _getCompareReserves()
        internal
        view
        returns (
            uint256 _min_reserveA,
            uint256 _min_reserveB,
            IYexSwapPool _min_pool,
            uint256 _max_reserveA,
            uint256 _max_reserveB,
            IYexSwapPool _max_pool
        )
    {
        // pool reserve
        (uint256 pool1_reserveA, uint256 pool1_reserveB) = getReserves();
        (uint256 pool2_reserveA, uint256 pool2_reserveB) = pool2.getReserves();

        // compare B/A
        if (
            (pool2_reserveA * pool1_reserveB) / pool1_reserveA > pool2_reserveB
        ) {
            _min_reserveA = pool2_reserveA;
            _min_reserveB = pool2_reserveB;
            _max_reserveA = pool1_reserveA;
            _max_reserveB = pool1_reserveB;
            _min_pool = pool2;
            _max_pool = pool1;
        } else {
            _min_reserveA = pool1_reserveA;
            _min_reserveB = pool1_reserveB;
            _max_reserveA = pool2_reserveA;
            _max_reserveB = pool2_reserveB;
            _min_pool = pool1;
            _max_pool = pool2;
        }
    }

    function getExpectedAmountOut(
        address token,
        uint256 amountIn
    ) external view returns (uint256) {
        uint256 balanceA = batch_tokenA[batchid];
        uint256 balanceB = batch_tokenB[batchid];
        uint256 balanceB_before_swap;
        uint256 balanceA_before_swap;
        if (token == address(tokenA)) {
            balanceA_before_swap = balanceA + amountIn;
            balanceB_before_swap = balanceB;
        } else {
            balanceB_before_swap = balanceB + amountIn;
            balanceA_before_swap = balanceA;
        }
        uint256 balanceA_ = balanceA_before_swap;
        uint256 balanceB_ = balanceB_before_swap;

        console.log(
            "before swap, balanceA:%s balanceB:%s",
            balanceA_before_swap,
            balanceB_before_swap
        );
        (
            uint256 min_reserveA,
            uint256 min_reserveB,
            ,
            uint256 max_reserveA,
            uint256 max_reserveB,

        ) = _getCompareReserves();

        if (
            ((balanceB_before_swap * max_reserveA)) >
            (max_reserveB * balanceA_before_swap)
        ) {
            uint256 delta;
            unchecked {
                delta = (balanceB_before_swap -
                    (balanceA_before_swap * min_reserveB) /
                    min_reserveA);
            }
            balanceB_ -= delta;
            (delta, ) = getOptionalAmountOut(
                0,
                delta,
                min_reserveA,
                min_reserveB
            );
            balanceA_ += delta;
        } else if (
            ((balanceB_before_swap * min_reserveA)) <
            (min_reserveB * balanceA_before_swap)
        ) {
            uint256 delta;
            unchecked {
                delta = (balanceA_before_swap -
                    (balanceB_before_swap * max_reserveA) /
                    max_reserveB);
            }
            balanceA_ -= delta;
            (, delta) = getOptionalAmountOut(
                delta,
                0,
                max_reserveA,
                max_reserveB
            );
            balanceB_ += delta;
        }

        console.log(
            "expected auction, balanceA:%s balanceB:%s",
            balanceA_,
            balanceB_
        );
        if (token == address(tokenA)) {
            return (amountIn * balanceB_) / balanceA_before_swap;
        } else {
            return (amountIn * balanceA_) / balanceB_before_swap;
        }
    }

    function getOptionalAmountOut(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountAOut, uint256 amountBOut) {
        uint256 kValue = reserveA * reserveB;
        if (amountA > 0) {
            uint256 rb = reserveB;
            reserveA += amountA;
            reserveB = kValue / reserveA;
            amountBOut = rb - reserveB;
        } else {
            uint256 ra = reserveA;
            reserveB += amountB;
            reserveA = kValue / reserveB;
            amountAOut = ra - reserveA;
        }
    }
}
