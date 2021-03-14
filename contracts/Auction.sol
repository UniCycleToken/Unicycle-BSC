pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";
import "./Epoch.sol";

contract Auction is Context, Epoch, ReentrancyGuard {
    using SafeMath for uint256;

    struct AuctionLobbyParticipate {
        uint256[] epoches;
        mapping(uint256 => uint256) BNBParticipated;
        mapping(uint256 => uint256) cycleEarned;
        uint256 availableCycle;
    }

    struct CycleStake {
        uint256 epoch;
        uint256 cycleStaked;
        uint256 BNBEarned;
        bool active;
    }

    struct FlipStake {
        uint256 flipStaked;
        uint256 cycleEarned;
    }

    uint256 teamSharePercent = 50;
    uint256 rewardForFlipStakersPercent = 50;
    uint256 percentMax = 1000;

    address public BNBAddress;
    address public CYCLEBNBAddress;

    uint256 private constant DAILY_MINT_CAP = 100_000 * 10**18;

    // Can only get via view functions since need to update rewards if required
    mapping(address => AuctionLobbyParticipate)
        private auctionLobbyParticipates;
    mapping(address => CycleStake[]) private cycleStakes;

    mapping(address => FlipStake) private flipStakes;

    address[] auctionLobbyParticipaters;
    address[] cycleStakers;
    address[] flipStakers;

    // epoch => data
    mapping(uint256 => uint256) private dailyTotalBNB;

    uint256 public totalCycleStaked;
    uint256 public totalFlipStaked;

    address payable public teamAddress;
    uint256 private teamShare;

    ICycleToken private cycleToken;

    event Participate(uint256 amount, uint256 participateTime, address account);
    event TakeShare(uint256 reward, uint256 participateTime, address account);
    event Stake(uint256 amount, uint256 stakeTime, address account);
    event Unstake(uint256 reward, uint256 stakeTime, address account);
    event StakeFlip(uint256 amount, uint256 stakeTime, address account);
    event UnstakeFlip(uint256 reward, uint256 stakeTime, address account);

    constructor(
        address cycleTokenAddress,
        address uniswapV2Router02Address,
        uint256 auctionStartTime,
        address payable _teamAddress
    ) public Epoch(900, auctionStartTime, 0) {
        // 15 mins period for test
        require(cycleTokenAddress != address(0), "ZERO ADDRESS");
        require(uniswapV2Router02Address != address(0), "ZERO ADDRESS");
        require(_teamAddress != address(0), "ZERO ADDRESS");

        cycleToken = ICycleToken(cycleTokenAddress);
        teamAddress = _teamAddress;

        IUniswapV2Router02 uniswapV2Router02 =
            IUniswapV2Router02(uniswapV2Router02Address);

        BNBAddress = uniswapV2Router02.WETH();

        address uniswapV2FactoryAddress = uniswapV2Router02.factory();
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2FactoryAddress);
        CYCLEBNBAddress = factory.getPair(BNBAddress, cycleTokenAddress);

        if (CYCLEBNBAddress == address(0))
            CYCLEBNBAddress = factory.createPair(BNBAddress, cycleTokenAddress);
    }

    modifier checkValue(uint256 amount) {
        require(amount > 0, "Amount cannot be zero");

        _;
    }

    modifier distributeRewards {
        if (getLastEpoch() < getCurrentEpoch()) {
            uint256 prevEpoch = getLastEpoch();

            updateEpoch();

            if (dailyTotalBNB[prevEpoch] > 0) {
                // Distribute the minted tokens to auction participaters
                for (uint256 i = 0; i < auctionLobbyParticipaters.length; i++) {
                    address participater = auctionLobbyParticipaters[i];

                    AuctionLobbyParticipate storage ap =
                        auctionLobbyParticipates[participater];

                    uint256 newReward =
                        DAILY_MINT_CAP.mul(ap.BNBParticipated[prevEpoch]).div(
                            dailyTotalBNB[prevEpoch]
                        );

                    ap.cycleEarned[prevEpoch] = newReward;
                    ap.availableCycle = ap.availableCycle.add(newReward);
                }

                // Distribute BNB to cycle stakers
                if (cycleStakers.length > 0) {
                    for (uint256 i = 0; i < cycleStakers.length; i++) {
                        address cycleStaker = cycleStakers[i];

                        CycleStake[] storage stakes = cycleStakes[cycleStaker];

                        for (uint256 j = 0; j < stakes.length; j++) {
                            if (
                                stakes[j].active &&
                                getCurrentEpoch().sub(stakes[j].epoch) < 100
                            ) {
                                stakes[j].BNBEarned = stakes[j].BNBEarned.add(
                                    dailyTotalBNB[prevEpoch]
                                        .mul(percentMax - teamSharePercent)
                                        .div(percentMax)
                                        .mul(stakes[j].cycleStaked)
                                        .div(totalCycleStaked)
                                );
                            }
                        }
                    }
                } else {
                    // If no stakers, then send to the team fund
                    teamShare = teamShare.add(
                        dailyTotalBNB[prevEpoch]
                            .mul(percentMax - teamSharePercent)
                            .div(percentMax)
                    );
                }
            }
        }

        _;
    }

    // Participate in auction lobby
    function participate()
        external
        payable
        nonReentrant
        checkValue(msg.value)
        checkStartTime
        distributeRewards
    {
        uint256 currentEpoch = getCurrentEpoch();

        // mint tokens only when the first auction participate happens in each epoch
        if (dailyTotalBNB[currentEpoch] == 0) {
            cycleToken.mint(DAILY_MINT_CAP);
            takeTeamShare();
        }

        AuctionLobbyParticipate storage auctionParticipate =
            auctionLobbyParticipates[_msgSender()];

        if (auctionParticipate.epoches.length == 0) {
            auctionLobbyParticipaters.push(_msgSender());
        }

        auctionParticipate.BNBParticipated[currentEpoch] = auctionParticipate
            .BNBParticipated[currentEpoch]
            .add(msg.value);

        if (
            auctionParticipate.epoches[auctionParticipate.epoches.length - 1] <
            currentEpoch
        ) {
            auctionParticipate.epoches.push(currentEpoch);
        }

        dailyTotalBNB[currentEpoch] = dailyTotalBNB[currentEpoch].add(
            msg.value
        );

        // 5% of the deposited BNB goes to team
        teamShare = teamShare.add(
            msg.value.mul(teamSharePercent).div(percentMax)
        );

        emit Participate(msg.value, currentEpoch, _msgSender());
    }

    function takeAuctionLobbyShare() external nonReentrant distributeRewards {
        require(
            auctionLobbyParticipates[_msgSender()].availableCycle > 0,
            "Nothing to withdraw"
        );

        AuctionLobbyParticipate storage ap =
            auctionLobbyParticipates[_msgSender()];

        cycleToken.transfer(_msgSender(), ap.availableCycle);

        emit TakeShare(ap.availableCycle, getCurrentEpoch(), _msgSender());

        ap.availableCycle = 0;
    }

    function stake(uint256 amount)
        external
        nonReentrant
        checkValue(amount)
        checkStartTime
        distributeRewards
    {
        CycleStake[] storage stakes = cycleStakes[_msgSender()];

        uint256 activeLen = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (stakes[i].active) {
                activeLen++;
            }
        }

        if (activeLen == 0) {
            cycleStakers.push(_msgSender());
        }

        stakes.push(CycleStake(getCurrentEpoch(), amount, 0, true));
        totalCycleStaked = totalCycleStaked.add(amount);

        cycleToken.transferFrom(_msgSender(), address(this), amount);

        distributeToFlipStakersAndBurn(amount);

        emit Stake(amount, getCurrentEpoch(), _msgSender());
    }

    function unstake(uint256 index) external nonReentrant distributeRewards {
        require(
            cycleStakes[_msgSender()][index].BNBEarned > 0,
            "Nothing to unstake"
        );
        require(
            cycleStakes[_msgSender()][index].active,
            "You already unstaked for this stake"
        );

        uint256 reward = cycleStakes[_msgSender()][index].BNBEarned;
        _msgSender().transfer(reward);

        totalCycleStaked = totalCycleStaked.sub(
            cycleStakes[_msgSender()][index].cycleStaked
        );

        // Deactivate this stake
        cycleStakes[_msgSender()][index].active = false;

        uint256 activeLen = 0;

        for (uint256 i = 0; i < cycleStakes[_msgSender()].length; i++) {
            if (cycleStakes[_msgSender()][i].active) {
                activeLen++;
            }
        }

        if (activeLen == 0) {
            deleteFromArrayByValue(_msgSender(), cycleStakers);
        }

        emit Unstake(reward, getCurrentEpoch(), _msgSender());
    }

    function stakeFlip(uint256 amount)
        external
        nonReentrant
        checkValue(amount)
        checkStartTime
    {
        FlipStake storage flipStake = flipStakes[_msgSender()];

        if (flipStake.flipStaked == 0) {
            flipStakers.push(_msgSender());
        }

        flipStake.flipStaked = flipStake.flipStaked.add(amount);
        totalFlipStaked = totalFlipStaked.add(amount);

        IERC20(CYCLEBNBAddress).transferFrom(
            _msgSender(),
            address(this),
            amount
        );

        emit StakeFlip(amount, getCurrentEpoch(), _msgSender());
    }

    function takeFlipReward(address user) public {
        require(flipStakes[user].cycleEarned > 0, "Nothing to withdraw");

        FlipStake storage flipStake = flipStakes[user];

        cycleToken.transfer(user, flipStake.cycleEarned);
        flipStake.cycleEarned = 0;
    }

    function unstakeFlip() external nonReentrant {
        require(flipStakes[_msgSender()].flipStaked > 0, "Nothing to unstake");

        takeFlipReward(_msgSender());
        IERC20(CYCLEBNBAddress).transfer(
            _msgSender(),
            flipStakes[_msgSender()].flipStaked
        );

        totalFlipStaked = totalFlipStaked.sub(
            flipStakes[_msgSender()].flipStaked
        );

        emit UnstakeFlip(
            flipStakes[_msgSender()].flipStaked,
            getCurrentEpoch(),
            _msgSender()
        );

        flipStakes[_msgSender()].flipStaked = 0;

        deleteFromArrayByValue(_msgSender(), flipStakers);
    }

    // Team can withdraw its share if wants
    function takeTeamShare() public distributeRewards {
        if (teamShare > 0) {
            teamAddress.transfer(teamShare);
            teamShare = 0;
        }
    }

    // =========== Distribute function ==============

    function distributeToFlipStakersAndBurn(uint256 cycleAmount) private {
        uint256 cycleRewardsForFlipStakers =
            cycleAmount.mul(rewardForFlipStakersPercent).div(percentMax);

        for (uint256 i = 0; i < flipStakers.length; i++) {
            FlipStake storage flipStake = flipStakes[flipStakers[i]];
            flipStake.cycleEarned = flipStake.cycleEarned.add(
                cycleRewardsForFlipStakers.mul(flipStake.flipStaked).div(
                    totalFlipStaked
                )
            );
        }

        uint256 burnCycleAmount = cycleAmount;
        if (flipStakers.length > 0) {
            burnCycleAmount = burnCycleAmount.sub(cycleRewardsForFlipStakers);
        }

        cycleToken.burn(burnCycleAmount);
    }

    // =========== View functions =============

    function getCycleAddress() external view returns (address) {
        return address(cycleToken);
    }

    function getAuctionLobbyParticipateEpoches(address user)
        external
        view
        returns (uint256[] memory)
    {
        return auctionLobbyParticipates[user].epoches;
    }

    function getAuctionLobbyParticipateBNBParticipated(
        address user,
        uint256 epoch
    ) external view returns (uint256) {
        return auctionLobbyParticipates[user].BNBParticipated[epoch];
    }

    function getAuctionLobbyParticipateCycleEarned(address user, uint256 epoch)
        external
        view
        returns (uint256)
    {
        if (epoch < getLastEpoch() || getLastEpoch() == getCurrentEpoch()) {
            return auctionLobbyParticipates[user].cycleEarned[epoch];
        } else {
            return calculateNewBNBEarned(user);
        }
    }

    function getAuctionLobbyParticipateAvailableCycle(address user)
        external
        view
        returns (uint256)
    {
        return
            auctionLobbyParticipates[user].availableCycle +
            calculateNewBNBEarned(user);
    }

    function getCycleStakeLength(address user) external view returns (uint256) {
        return cycleStakes[user].length;
    }

    function getCycleStake(address user, uint256 index)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        return (
            cycleStakes[user][index].epoch,
            cycleStakes[user][index].cycleStaked,
            cycleStakes[user][index].BNBEarned +
                calculateNewCycleEarned(user, index),
            cycleStakes[user][index].active
        );
    }

    function getFlipStake(address user)
        external
        view
        returns (uint256, uint256)
    {
        return (flipStakes[user].flipStaked, flipStakes[user].cycleEarned);
    }

    function getDailyTotalBNB(uint256 epoch) external view returns (uint256) {
        return dailyTotalBNB[epoch];
    }

    function getTeamShare() external view returns (uint256) {
        if (getLastEpoch() < getCurrentEpoch()) {
            if (dailyTotalBNB[getLastEpoch()] > 0) {
                if (cycleStakers.length == 0) {
                    // If no stakers, then send to the team fund
                    return
                        teamShare.add(
                            dailyTotalBNB[getLastEpoch()]
                                .mul(percentMax - teamSharePercent)
                                .div(percentMax)
                        );
                }
            }
        }

        return teamShare;
    }

    // =========== Calculate new rewards =============

    function calculateNewBNBEarned(address user)
        private
        view
        returns (uint256)
    {
        uint256 lastEpoch = getLastEpoch();

        if (lastEpoch < getCurrentEpoch()) {
            if (dailyTotalBNB[lastEpoch] > 0) {
                return
                    DAILY_MINT_CAP
                        .mul(
                        auctionLobbyParticipates[user].BNBParticipated[
                            lastEpoch
                        ]
                    )
                        .div(dailyTotalBNB[lastEpoch]);
            }
        }

        return 0;
    }

    function calculateNewCycleEarned(address user, uint256 j)
        private
        view
        returns (uint256)
    {
        uint256 lastEpoch = getLastEpoch();

        if (lastEpoch < getCurrentEpoch()) {
            if (dailyTotalBNB[lastEpoch] > 0) {
                return
                    dailyTotalBNB[lastEpoch]
                        .mul(percentMax - teamSharePercent)
                        .div(percentMax)
                        .mul(cycleStakes[user][j].cycleStaked)
                        .div(totalCycleStaked);
            }
        }

        return 0;
    }

    // =========== Array Utilites ============

    function findIndexFromArray(address value, address[] memory array)
        private
        pure
        returns (uint256)
    {
        uint256 i = 0;
        for (; i < array.length; i++) {
            if (array[i] == value) {
                return i;
            }
        }

        return i;
    }

    function deleteFromArrayByValue(address value, address[] storage array)
        private
    {
        uint256 i = findIndexFromArray(value, array);

        while (i < array.length - 1) {
            array[i] = array[i + 1];
            i++;
        }

        array.pop();
    }
}
