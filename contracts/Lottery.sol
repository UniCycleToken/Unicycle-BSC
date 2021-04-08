/* solium-disable */
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces.sol";

interface IAuction {
    function getFlipStakers() external view returns (address[] memory);

    function getFlipStake(address user)
        external
        view
        returns (uint256, uint256);

    function totalFlipStaked() external view returns (uint256);
}

contract LuckyCycle is Ownable {
    using SafeMath for uint256;

    struct LotteryBag {
        uint256 count;
        address addr;
    }

    mapping(uint256 => mapping(address => uint256)) public entryLengths;
    LotteryBag[] lotteryBag;

    // Variables for lottery information
    mapping(uint256 => address) public winners;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public bnbBalances;
    mapping(uint256 => uint256) public bnbPerRound;
    mapping(uint256 => uint256) public totalParticipatedCycles;

    address public cycleTokenAddress;
    address public auctionAddress;

    uint256 public amountToBurn;
    uint256 public amountForFlipFarmers;

    uint256 public startTime;
    uint256 public period;

    uint256 public round;

    uint256 private bnbForPreviousWinners;

    constructor(
        address _cycleAddress,
        address _auctionAddress,
        uint256 _startTime,
        uint256 _period
    ) public {
        cycleTokenAddress = _cycleAddress;
        auctionAddress = _auctionAddress;
        startTime = _startTime;
        period = _period;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive() external payable {}

    modifier checkStartTime {
        require(block.timestamp > startTime, "Lottery not started yet");

        _;
    }

    modifier checkLotteryLive {
        require(block.timestamp < startTime + period, "Round already ended");

        _;
    }

    function declareWinner() external checkStartTime {
        require(
            block.timestamp >= startTime + period,
            "Current Round not ended yet"
        );

        if (lotteryBag.length > 0) {
            uint256 index =
                generateRandomNumber() %
                    totalParticipatedCycles[round].div(10**18);

            address winnerAddress;
            for (uint256 i = 0; i < lotteryBag.length; i++) {
                if (lotteryBag[i].count >= index) {
                    winnerAddress = lotteryBag[i].addr;
                    break;
                }
                index -= lotteryBag[i].count;
            }

            // Set winner for the previous epoch
            winners[round] = winnerAddress;
            balances[winnerAddress] = balances[winnerAddress].add(
                totalParticipatedCycles[round].div(2)
            );
            bnbBalances[winnerAddress] =
                address(this).balance -
                bnbForPreviousWinners;
            bnbPerRound[round] = address(this).balance - bnbForPreviousWinners;
            bnbForPreviousWinners = address(this).balance;

            amountToBurn = amountToBurn.add(
                totalParticipatedCycles[round].mul(45).div(100)
            );
            amountForFlipFarmers = amountForFlipFarmers.add(
                totalParticipatedCycles[round].mul(5).div(100)
            );

            delete lotteryBag;

            burnAndRewardFlipFarmers();

            // event
            WinnerDeclared(
                winnerAddress,
                entryLengths[round][winnerAddress],
                round
            );
        }

        startTime = block.timestamp;
        round += 1;
    }

    function participate(uint256 ticketLength)
        external
        checkStartTime
        checkLotteryLive
    {
        require(ticketLength > 0, "You cannot buy zero tickets");

        ICycleToken(cycleTokenAddress).transferFrom(
            _msgSender(),
            address(this),
            ticketLength * 10**18
        );

        entryLengths[round][_msgSender()] = entryLengths[round][_msgSender()]
            .add(ticketLength);
        totalParticipatedCycles[round] = totalParticipatedCycles[round].add(
            ticketLength * 10**18
        );

        LotteryBag memory lottery = LotteryBag(ticketLength, _msgSender());

        lotteryBag.push(lottery);

        // event
        PlayerParticipated(_msgSender(), ticketLength, round);
    }

    // NOTE: This should not be used for generating random number in real world
    function generateRandomNumber() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        now,
                        totalParticipatedCycles[round].div(10**18)
                    )
                )
            );
    }

    function burnAndRewardFlipFarmers() private {
        ICycleToken(cycleTokenAddress).transfer(
            0x000000000000000000000000000000000000dEaD,
            amountToBurn
        );
        amountToBurn = 0;

        address[] memory flipFarmers =
            IAuction(auctionAddress).getFlipStakers();
        uint256 totalFlipStaked = IAuction(auctionAddress).totalFlipStaked();

        for (uint256 i = 0; i < flipFarmers.length; i++) {
            (uint256 flipStaked, ) =
                IAuction(auctionAddress).getFlipStake(flipFarmers[i]);
            uint256 amount =
                amountForFlipFarmers.mul(flipStaked).div(totalFlipStaked);
            ICycleToken(cycleTokenAddress).transfer(flipFarmers[i], amount);
        }

        amountForFlipFarmers = 0;
    }

    function claimWinnerReward() external {
        require(balances[_msgSender()] > 0, "Balance is zero");

        ICycleToken(cycleTokenAddress).transfer(
            _msgSender(),
            balances[_msgSender()]
        );
        balances[_msgSender()] = 0;

        _msgSender().transfer(bnbBalances[_msgSender()]);
        bnbForPreviousWinners = bnbForPreviousWinners.sub(
            bnbBalances[_msgSender()]
        );
        bnbBalances[_msgSender()] = 0;
    }

    // Events
    event WinnerDeclared(
        address beneficiary,
        uint256 entryCount,
        uint256 epoch
    );

    event PlayerParticipated(
        address beneficiary,
        uint256 entryCount,
        uint256 epoch
    );
}
