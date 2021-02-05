// File: @openzeppelin/contracts/math/SafeMath.sol



pragma solidity ^0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts/GSN/Context.sol



pragma solidity ^0.6.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol



pragma solidity ^0.6.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: @uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol

pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

// File: @uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// File: @uniswap/v2-periphery/contracts/interfaces/IWETH.sol

pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol



pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: contracts/Interfaces.sol

/* solium-disable */
pragma solidity >= 0.6.0 < 0.7.0;

 /* solium-disable-next-line */
interface ICycleToken is IERC20 {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function isBlacklisted(address account) view external returns (bool);
    function setAuction(address account) external;
    function setCYCLEWETHAddress(address CYCLEWETH) external;
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

// File: contracts/Auction.sol

pragma solidity >=0.6.0 <0.7.0;









contract Auction is Context, Ownable {
    using SafeMath for uint256;

    struct LPStake {
        uint256 amount;
        uint256 lastUnlockTime;
    }

    address public WETHAddress;
    address public CYCLEWETHAddress;

    uint256 private constant DAILY_MINT_CAP = 100_000 * 10 ** 18;
    uint256 private constant FIRST_DAY_HARD_CAP = 1_500 * 10 ** 18;
    uint256 private constant FIRST_DAY_WALLET_CAP = 15 * 10 ** 18;
    uint256 private constant SECONDS_IN_DAY = 86400;

    mapping(address => uint256[]) private _userParticipateTimes;
    mapping(address => uint256[]) private _userStakeTimes;
    mapping(address => uint256[]) private _userLPStakeTimes;

    uint256 private _lastStakeTime;
    uint256 private _lastLPStakeTime;

    uint256[] private _mintTimes;
    // timestamp => address => data
    mapping(uint256 => mapping(address => uint256)) private _dailyParticipatedETH;
    mapping(uint256 => mapping(address => uint256)) private _dailyStakedCYCLE;
    mapping(uint256 => mapping(address => LPStake)) private _LPStakes;
    // timestamp => data
    mapping(uint256 => uint256) private _dailyTotalParticipatedETH;
    mapping(uint256 => uint256) private _accumulativeStakedCYCLE;
    mapping(uint256 => uint256) private _accumulativeStakedLP;

    address payable private _teamAddress;
    uint256 private _teamETHShare;
    bool private _isLiquidityAdded;

    ICycleToken private _CYCLE;

    event Participate(uint256 amount, uint256 participateTime, address account);
    event TakeShare(uint256 reward, uint256 participateTime, address account);
    event Stake(uint256 amount, uint256 stakeTime, address account);
    event Unstake(uint256 reward, uint256 stakeTime, address account);
    event StakeLP(uint256 amount, uint256 stakeTime, address account);
    event UnstakeLP(uint256 reward, uint256 stakeTime, address account);

    constructor(address cycleTokenAddress, address uniswapV2Router02Address, uint256 mintTime, address payable teamAddress) public {
        require(cycleTokenAddress != address(0), "ZERO ADDRESS");
        require(uniswapV2Router02Address != address(0), "ZERO ADDRESS");
        require(teamAddress != address(0), "ZERO ADDRESS");
        _CYCLE = ICycleToken(cycleTokenAddress);
        _teamAddress = teamAddress;
        _setLastMintTime(mintTime);
        _isLiquidityAdded = false;
        _lastStakeTime = mintTime;
        _lastLPStakeTime = mintTime;
        IUniswapV2Router02 uniswapV2Router02 = IUniswapV2Router02(uniswapV2Router02Address);
        WETHAddress = uniswapV2Router02.WETH();
        address uniswapV2FactoryAddress = uniswapV2Router02.factory();
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2FactoryAddress);
        CYCLEWETHAddress = factory.getPair(WETHAddress, address(_CYCLE));
        if (CYCLEWETHAddress == address(0))
            CYCLEWETHAddress = factory.createPair(WETHAddress, address(_CYCLE));
    }

    function getUserParticipatesData(address user) external view returns (uint256[] memory) {
        return _userParticipateTimes[user];
    }

    function getUserStakesData(address user) external view returns (uint256[] memory) {
        return _userStakeTimes[user];
    }

    function getUserLPStakesData(address user) external view returns (uint256[] memory) {
        return _userLPStakeTimes[user];
    }

    function getCycleAddress() external view returns (address) {
        return address(_CYCLE);
    }

    function getTeamInfo() external onlyOwner view returns (uint256, address) {
        return (_teamETHShare, _teamAddress);
    }

    function getLastLpUnlockTime(uint256 stakeTime, address user) external view returns (uint256) {
        return _LPStakes[stakeTime][user].lastUnlockTime;
    }

    function getAccumulativeCycle() external view returns (uint256) {
        return _accumulativeStakedCYCLE[_lastStakeTime];
    }

    function getAccumulativeLP() external view returns (uint256) {
        return _accumulativeStakedLP[_lastLPStakeTime];
    }

    function getMintTimesLength() external view returns (uint256) {
        return _mintTimes.length;
    }

    function getParticipatedETHAmount(uint256 mintTime, address user) external view returns (uint256) {
        return _dailyParticipatedETH[mintTime][user];
    }

    function getStakedCycle(uint256 stakeTime, address user) external view returns (uint256) {
        return _dailyStakedCYCLE[stakeTime][user];
    }

    function getStakedLP(uint256 stakeTime, address user) external view returns (uint256) {
        return _LPStakes[stakeTime][user].amount;
    }

    function getTotalParticipateAmount(address user) external view returns (uint256) {
        uint256 totalEth;
        for (uint256 i = 0; i < _mintTimes.length; i++) {
            totalEth = totalEth.add(_dailyParticipatedETH[_mintTimes[i]][user]);
        }
        return totalEth;
    }

    function canTakeShare(uint256 mintTime, address user) external view returns (uint256) {
        if (_dailyTotalParticipatedETH[mintTime] > 0) {
            return _dailyParticipatedETH[mintTime][user].mul(DAILY_MINT_CAP).div(_dailyTotalParticipatedETH[mintTime]);
        }
        return 0;
    }

    function canUnstake(uint256 stakeTime, address user) external view returns (uint256) {
        if (_dailyStakedCYCLE[stakeTime][user] > 0 && stakeTime.add(SECONDS_IN_DAY) < block.timestamp) {
            return _calculateCycleStakeReward(stakeTime, user);
        }
        return 0;
    }

    function canUnstakeLP(uint256 stakeTime, address user) external view returns (uint256) {
        if (_LPStakes[stakeTime][user].amount > 0) {
            uint256 lpStakeReward;
            (lpStakeReward,) = _calculateLPStakeReward(stakeTime);
            return lpStakeReward;
        }
        return 0;
    }

    function getLastMintTime() public view returns (uint256) {
        return _mintTimes[_mintTimes.length - 1];
    }

    function participate() external payable {
        require(msg.value > 0, "Insufficient participation");
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= block.timestamp) {
            uint256 newLastMintTime = lastMintTime.add(((block.timestamp.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            _startNextRound(newLastMintTime);
            lastMintTime = getLastMintTime();
            _takeTeamETHShare();
        } else if (_mintTimes.length == 1) {
            require(_dailyTotalParticipatedETH[lastMintTime].add(msg.value) <= FIRST_DAY_HARD_CAP, "First day hard cap reached");
            require(_dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value) <= FIRST_DAY_WALLET_CAP, "First day wallet cap reached");
        } 
        _dailyTotalParticipatedETH[lastMintTime] = _dailyTotalParticipatedETH[lastMintTime].add(msg.value);
        _dailyParticipatedETH[lastMintTime][_msgSender()] = _dailyParticipatedETH[lastMintTime][_msgSender()].add(msg.value);
        _teamETHShare = _teamETHShare.add(msg.value.div(20));
        if (_userParticipateTimes[_msgSender()].length > 0) {
            if (_userParticipateTimes[_msgSender()][_userParticipateTimes[_msgSender()].length - 1] != lastMintTime) {
                _userParticipateTimes[_msgSender()].push(lastMintTime);
            }
        } else {
            _userParticipateTimes[_msgSender()].push(lastMintTime);
        }
        emit Participate(msg.value, lastMintTime, _msgSender());
    }

    function takeShare(uint256 mintTime, address user) external {
        require(_dailyParticipatedETH[mintTime][user] > 0, "Nothing to unlock");
        require(mintTime.add(SECONDS_IN_DAY) < block.timestamp, "At least 1 day must pass");
        uint256 participatedAmount = _dailyParticipatedETH[mintTime][user];
        delete _dailyParticipatedETH[mintTime][user];
        uint256 cycleSharePayout = DAILY_MINT_CAP.div(_dailyTotalParticipatedETH[mintTime]);
        for (uint256 i = 0; i < _userParticipateTimes[user].length; i++) {
            if (_userParticipateTimes[user][i] == mintTime) {
                _userParticipateTimes[user][i] = _userParticipateTimes[user][_userParticipateTimes[user].length - 1];
                _userParticipateTimes[user].pop();
            }
        }
        _CYCLE.transfer(user, participatedAmount.mul(cycleSharePayout));
        emit TakeShare(participatedAmount.mul(cycleSharePayout), mintTime, user);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        // uint256 lastStakeTime = getLastStakeTime();
        if (stakeTime > _lastStakeTime) {
            _accumulativeStakedCYCLE[stakeTime] = _accumulativeStakedCYCLE[_lastStakeTime];
        }
        _accumulativeStakedCYCLE[stakeTime] = _accumulativeStakedCYCLE[stakeTime].add(amount);
        _dailyStakedCYCLE[stakeTime][_msgSender()] = _dailyStakedCYCLE[stakeTime][_msgSender()].add(amount);
        _lastStakeTime = stakeTime;
        uint256 fivePercentOfStake = amount.div(20);
        _CYCLE.transferFrom(_msgSender(), address(this), amount);
        _CYCLE.burn(amount.sub(fivePercentOfStake));
        if (_userStakeTimes[_msgSender()].length > 0) {
            if (_userStakeTimes[_msgSender()][_userStakeTimes[_msgSender()].length - 1] != stakeTime) {
                _userStakeTimes[_msgSender()].push(stakeTime);
            }
        } else {
            _userStakeTimes[_msgSender()].push(stakeTime);
        }
        emit Stake(amount, stakeTime, _msgSender());
    }

    function unstake(uint256 stakeTime, address payable user) external {
        require(_dailyStakedCYCLE[stakeTime][user] > 0, "Nothing to unstake");
        require(stakeTime.add(SECONDS_IN_DAY) < block.timestamp, 'At least 1 day must pass');
        uint256 unstakeRewardAmount = _calculateCycleStakeReward(stakeTime, user);
        delete _dailyStakedCYCLE[stakeTime][user];
        user.transfer(unstakeRewardAmount);
        _accumulativeStakedCYCLE[_lastStakeTime] = _accumulativeStakedCYCLE[_lastStakeTime].sub(_dailyStakedCYCLE[stakeTime][user]);
        for (uint256 i = 0; i < _userStakeTimes[user].length; i++) {
            if (_userStakeTimes[user][i] == stakeTime) {
                _userStakeTimes[user][i] = _userStakeTimes[user][_userStakeTimes[user].length - 1];
                _userStakeTimes[user].pop();
            }
        }
        emit Unstake(unstakeRewardAmount, stakeTime, user);
    }

    function stakeLP(address token, uint256 amount) external {
        require(token == CYCLEWETHAddress, 'Token is not supported');
        require(amount > 0, "Invalid stake amount");
        uint256 stakeTime = _getRightStakeTime();
        if (stakeTime > _lastLPStakeTime) {
            _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[_lastLPStakeTime];
        }
        _accumulativeStakedLP[stakeTime] = _accumulativeStakedLP[stakeTime].add(amount);
        LPStake storage staker = _LPStakes[stakeTime][_msgSender()];
        staker.amount = staker.amount.add(amount);
        staker.lastUnlockTime = stakeTime;
        _lastLPStakeTime = stakeTime;
        if (_userLPStakeTimes[_msgSender()].length > 0) {
            if (_userLPStakeTimes[_msgSender()][_userLPStakeTimes[_msgSender()].length - 1] != stakeTime) {
                _userLPStakeTimes[_msgSender()].push(stakeTime);
            }
        } else {
            _userLPStakeTimes[_msgSender()].push(stakeTime);
        }
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
        emit StakeLP(amount, stakeTime, _msgSender());
    }

    function takeLPReward(uint256 stakeTime, address user) public returns (uint256) {
        require(_LPStakes[stakeTime][user].amount > 0, "Nothing to unlock");
        uint256 lpStakeReward;
        uint256 lastStakeTime;
        (lpStakeReward, lastStakeTime) = _calculateLPStakeReward(stakeTime);
        _LPStakes[stakeTime][user].lastUnlockTime = lastStakeTime;
        _CYCLE.transfer(user, lpStakeReward);
        return lastStakeTime;
    }

    function unstakeLP(uint256 stakeTime, address user) external {
        uint256 lastStakeTime = takeLPReward(stakeTime, user);
        if (lastStakeTime.add(SECONDS_IN_DAY * 2) > block.timestamp) {
            _accumulativeStakedLP[_lastLPStakeTime] = _accumulativeStakedLP[_lastLPStakeTime].sub(_LPStakes[stakeTime][user].amount);
            IERC20(CYCLEWETHAddress).transfer(user, _LPStakes[stakeTime][user].amount);
            delete _LPStakes[stakeTime][user];
        }
    }

    function _getRightStakeTime() private view returns(uint256) {
        uint256 lastMintTime = getLastMintTime();
        if (lastMintTime.add(SECONDS_IN_DAY) <= block.timestamp) {
            uint256 newStakeTime = lastMintTime.add(((block.timestamp.sub(lastMintTime)).div(SECONDS_IN_DAY)).mul(SECONDS_IN_DAY));
            return newStakeTime;
        }
        return lastMintTime;
    }

    function _calculateCycleStakeReward(uint256 stakeTime, address user) private view returns (uint256) {
        uint256 cycleStakeReward;
        uint256 accumulativeDailyStakedCycle = _accumulativeStakedCYCLE[stakeTime];
        uint256 amountStaked = _dailyStakedCYCLE[stakeTime][user];
        for (uint256 i = stakeTime; i <= block.timestamp && i < stakeTime.add(SECONDS_IN_DAY * 100); i += SECONDS_IN_DAY) {
            if (_dailyTotalParticipatedETH[i] > 0) {
                accumulativeDailyStakedCycle = _accumulativeStakedCYCLE[i] == 0 ? accumulativeDailyStakedCycle : _accumulativeStakedCYCLE[i];
                cycleStakeReward = cycleStakeReward.add(
                    _dailyTotalParticipatedETH[i]
                        .mul(amountStaked)
                        .div(accumulativeDailyStakedCycle)
                );
            }
        }
        return cycleStakeReward.mul(95).div(100);
    }

    function _calculateLPStakeReward(uint256 stakeTime) private view returns (uint256, uint256) {
        uint256 lpStakeReward;
        uint256 accumulativeDailyStakedLP = _accumulativeStakedLP[stakeTime];
        uint256 amountStaked = _LPStakes[stakeTime][_msgSender()].amount;
        uint256 lastUnlockTime = _LPStakes[stakeTime][_msgSender()].lastUnlockTime;
        for (;lastUnlockTime <= block.timestamp ;) {
            accumulativeDailyStakedLP = _accumulativeStakedLP[lastUnlockTime] == 0 ? accumulativeDailyStakedLP : _accumulativeStakedLP[lastUnlockTime];
            if (_dailyTotalParticipatedETH[lastUnlockTime] > 0) {
                lpStakeReward = lpStakeReward.add(
                    DAILY_MINT_CAP
                        .div(20)
                        .mul(amountStaked)
                        .div(accumulativeDailyStakedLP)
                );
            }
            if (gasleft() < 100000) {
                return(lpStakeReward, lastUnlockTime.sub(SECONDS_IN_DAY));
            }
            lastUnlockTime = lastUnlockTime.add(SECONDS_IN_DAY);
        }
        return (lpStakeReward, lastUnlockTime.sub(SECONDS_IN_DAY));
    }

    function _takeTeamETHShare() private {
        uint256 teamETHShare = _teamETHShare;
        _teamETHShare = 0;
        if (!_isLiquidityAdded && _mintTimes[1].add(SECONDS_IN_DAY) <= block.timestamp) {
            // mint tokens for first day
            _CYCLE.mint(50_000 * 10 ** 18);
            // (5% + 95%) / 2
            teamETHShare = teamETHShare.add(_dailyTotalParticipatedETH[_mintTimes[1]].mul(95).div(100)).div(2);

            IUniswapV2Pair CYCLEWETH = IUniswapV2Pair(CYCLEWETHAddress);
            IWETH WETH = IWETH(WETHAddress);
            WETH.deposit{ value : teamETHShare }();

            uint256 lpMinted = CYCLEWETH.balanceOf(_teamAddress);

            WETH.transfer(CYCLEWETHAddress, teamETHShare);
            _CYCLE.transfer(CYCLEWETHAddress, 50_000 * 10 ** 18);
            CYCLEWETH.mint(_teamAddress);

            lpMinted = CYCLEWETH.balanceOf(_teamAddress).sub(lpMinted);
            require(lpMinted > 0, "liquidity add failed");

            _isLiquidityAdded = true;
        }
        _teamAddress.transfer(teamETHShare);
    }

    function _setLastMintTime(uint256 mintTime) private {
        _mintTimes.push(mintTime);
    }

    function _startNextRound(uint256 startTime) private {
        _setLastMintTime(startTime);
        _CYCLE.mint(DAILY_MINT_CAP);
    }
}
